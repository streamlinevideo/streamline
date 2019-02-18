#!/bin/bash

# Create a video ID form the time thes scipt is executed

vid=$(date '+%M%S')

# Print help if requested

if [ "$1" == "-h" ]; then
  echo "Usage: `basename $0` ./launch.sh originserverurl urltocdn"
  exit 0
fi

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required for launching the encoder. Aborting." >&2; exit 1; }

# Get the name of the capture card

ffmpeg -hide_banner -f decklink -list_devices 1  \
-i dummy &> .tmp.txt
sed -i '1d' .tmp.txt
output=$(<.tmp.txt)

IFS="'" read _ device _ <<< "$output"

# Get the input format from the capture card

echo -ne '\n' | StatusMonitor > .format.txt
output=$(<.format.txt)
while read -r line
do
    IFS=':' read -r -a array <<< "$line"
    key=$(echo ${array[0]} | tr -d ' ')
    value=$(echo ${array[1]} | tr -d ' ')

    if [ "$key" == "DetectedVideoInputMode" ]
    then
       video_format=$value
       #echo $video_format
       break
    fi
done <<< "$output"

IFS='p' read -r -a array <<< "$video_format"
res=${array[0]}
fps=${array[1]}

# Get video format list from the input card

ffmpeg -f decklink  -list_formats 1 -i "$device" &> .tmp.txt

output=$(<.tmp.txt)
min_fps=1000
while read -r line
do
    IFS=' ' read -ra array <<< "$line"
    identify=$(echo ${array[3]} | tr -d ' ')
    if [ "$identify" != "fps" ]
    then
       continue
    fi

    IFS='x' read -r -a array2 <<< "${array[0]}"
    if [ "${array2[1]}" != "$res" ]
    then
       continue
    fi

    # Calculate fps

    IFS='/' read -r -a array3 <<< "${array[2]}"
    DIV=$(echo "scale=2; ${array3[0]}/${array3[1]}" | bc)

    rownum=$(echo $DIV-$fps | bc)
    less_than=$(echo $rownum'<'0 | bc)
    if (( $less_than >  0 ))
    then
       #echo "hello"
       rownum=$(echo $rownum*-1 | bc)

    fi
    less_than=$(echo $rownum'<'$min_fps | bc)

    if (( $less_than > 0  ))
    then
       format_code=${array[0]}
       min_fps=$rownum
    fi

done <<< "$output"

IFS='\t' read -r -a array4 <<< "$format_code"

f_code=$(echo ${array4[0]}| cut -d' ' -f 1)

# Round off drop frame inputs to whole numbers

roundedfps=$(echo ${fps} | awk '{printf("%d\n",$1 + 0.99)}')

# HLS parameters that create 2 second segments, delete old segment, transmit over a persistent connetion using HTTP PUT, re-send a variant playlist every 15 seconds.

hlsargs="-f hls -hls_time 2 -hls_flags delete_segments -method PUT -http_persistent 1 -master_pl_publish_rate 15 -master_pl_name ${vid}.m3u8  -master_pl_publish_rate 30"

# Encoding settings for x264 (CPU based encoder)

x264enc='libx264 -profile:v high -bf 3 -refs 3 -sc_threshold 0'

# Encoding settings for nvenc (GPU based encoder)

nvenc='h264_nvenc -profile:v high -bf 3 -refs 3 -preset medium -spatial-aq 1 -temporal-aq 1 -rc-lookahead 25'

# If the input is 4k then encode with 4k encoding settings

if [ "${res}" == "2160" ] || [ "${roundedfps}" == "30" ]
then
    ffmpeg \
    -hide_banner \
    -queue_size 4294967296 \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]format=yuv420p,fps=30,split=7[1][2][3][4][5][6][7]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]hwupload_cuda,scale_npp=-1:720:interp_algo=lanczos[5out]; \
    [6]hwupload_cuda,scale_npp=-1:1080:interp_algo=lanczos[6out]; \
    [7]null[7out]" \
    -map '[1out]' -c:v:0 ${x264enc} -g 60 -b:v:0 400k \
    -map '[2out]' -c:v:1 ${x264enc} -g 60 -b:v:1 800k \
    -map '[3out]' -c:v:2 ${x264enc} -g 60 -b:v:2 1100k \
    -map '[4out]' -c:v:3 ${x264enc} -g 60 -b:v:3 2200k \
    -map '[5out]' -c:v:4 ${x264enc} -g 60 -b:v:4 3300k \
    -map '[6out]' -c:v:5 ${nvenc} -g 60 -b:v:5 6000k \
    -map '[7out]' -c:v:6 ${nvenc} -g 60 -b:v:6 12000k \
    -c:a:0 aac -b:a 128k -map 0:a \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &

    http://${1}/${vid}_%v.m3u8 >/dev/null 2>~/streamline/logs/encode.log &

# If the input is 4k then encode with 4k encoding settings

elif [ "${res}" == "2160" ] || [ "${roundedfps}" == "25" ]
then
    ffmpeg \
    -hide_banner \
    -queue_size 4294967296 \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]format=yuv420p,split=7[1][2][3][4][5][6][7]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]hwupload_cuda,scale_npp=-1:720:interp_algo=lanczos[5out]; \
    [6]hwupload_cuda,scale_npp=-1:1080:interp_algo=lanczos[6out]; \
    [7]null[7out]" \
    -map '[1out]' -c:v:0 ${x264enc} -g 50 -b:v:0 400k \
    -map '[2out]' -c:v:1 ${x264enc} -g 50 -b:v:1 800k \
    -map '[3out]' -c:v:2 ${x264enc} -g 50 -b:v:2 1100k \
    -map '[4out]' -c:v:3 ${x264enc} -g 50 -b:v:3 2200k \
    -map '[5out]' -c:v:4 ${x264enc} -g 50 -b:v:4 3300k \
    -map '[6out]' -c:v:5 ${nvenc} -g 50 -b:v:5 6000k \
    -map '[7out]' -c:v:6 ${nvenc} -g 50 -b:v:6 12000k \
    -c:a:0 aac -b:a 128k -map 0:a \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &

# If the input is 1080p59.94 or 1080p60, then encode with 1080p60 ABR encoding settings.

elif [ "${res}" == "1080" ] || [ "${roundedfps}" == "60" ]
then
ffmpeg \
    -hide_banner \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]format=yuv420p,fps=60,split=6[1][2][3][4][5][6]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]hwupload_cuda,scale_npp=-1:720:interp_algo=lanczos[5out]; \
    [6]null[6out]" \
    -map '[1out]' -c:v:0 ${x264enc} -g 120 -b:v:0 800k \
    -map '[2out]' -c:v:1 ${x264enc} -g 120 -b:v:1 1600k \
    -map '[3out]' -c:v:2 ${x264enc} -g 120 -b:v:2 2200k \
    -map '[4out]' -c:v:3 ${x264enc} -g 120 -b:v:3 4400k \
    -map '[5out]' -c:v:4 ${nvenc} -g 120 -b:v:4 6600k \
    -map '[6out]' -c:v:5 ${nvenc} -g 120 -b:v:5 12000k \
    -c:a:0 aac -b:a 128k -map 0:a \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &

# If the input is 1080p50, then encode with 1080p50 ABR encoding settings.

elif [ "${res}" == "1080" ] || [ "${fps}" == "50" ]
then
ffmpeg \
    -hide_banner \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]format=yuv420p,split=6[1][2][3][4][5][6]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]hwupload_cuda,scale_npp=-1:720:interp_algo=lanczos[5out]; \
    [6]null[6out]" \
    -map '[1out]' -c:v:0 ${x264enc} -g 100 -b:v:0 800k \
    -map '[2out]' -c:v:1 ${x264enc} -g 100 -b:v:1 1600k \
    -map '[3out]' -c:v:2 ${x264enc} -g 100 -b:v:2 2200k \
    -map '[4out]' -c:v:3 ${x264enc} -g 100 -b:v:3 4400k \
    -map '[5out]' -c:v:4 ${nvenc} -g 100 -b:v:4 6600k \
    -map '[6out]' -c:v:5 ${nvenc} -g 100 -b:v:5 12000k \
    -c:a:0 aac -b:a 128k -map 0:a \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &

# If the input is 1080i59.94, deinterlace it, then encode with 1080p30 ABR encoding settings.

elif [[ "${res}" == "1080i59.94" ]]
then
ffmpeg \
    -hide_banner \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]yadif=0:-1:1,fps=30,format=yuv420p,split=6[1][2][3][4][5][6]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]hwupload_cuda,scale_npp=-1:720:interp_algo=lanczos[5out]; \
    [6]null[6out]" \
    -map '[1out]' -c:v:0 ${x264enc} -g 60 -b:v:0 800k \
    -map '[2out]' -c:v:1 ${x264enc} -g 60 -b:v:1 1600k \
    -map '[3out]' -c:v:2 ${x264enc} -g 60 -b:v:2 2200k \
    -map '[4out]' -c:v:3 ${x264enc} -g 60 -b:v:3 4400k \
    -map '[5out]' -c:v:4 ${nvenc} -g 60 -b:v:4 6600k \
    -map '[6out]' -c:v:5 ${nvenc} -g 60 -b:v:5 12000k \
    -c:a:0 aac -b:a 128k -map a:0 \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &

# If the input is 1080i50, then deinterlace and encode with 1080p25 ABR encoding settings.

elif [[ "${res}" == "1080i50" ]]
then
ffmpeg \
    -hide_banner \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]yadif=0:-1:1,format=yuv420p,split=6[1][2][3][4][5][6]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]hwupload_cuda,scale_npp=-1:720:interp_algo=lanczos[5out]; \
    [6]null[6out]" \
    -map '[1out]' -c:v:0 ${x264enc} -g 50 -b:v:0 800k \
    -map '[2out]' -c:v:1 ${x264enc} -g 50 -b:v:1 1600k \
    -map '[3out]' -c:v:2 ${x264enc} -g 50 -b:v:2 2200k \
    -map '[4out]' -c:v:3 ${x264enc} -g 50 -b:v:3 4400k \
    -map '[5out]' -c:v:4 ${nvenc} -g 50 -b:v:4 6600k \
    -map '[6out]' -c:v:5 ${nvenc} -g 50 -b:v:5 12000k \
    -c:a:0 aac -b:a 128k -map 0:a \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &

# If the input is 720p60, then encode with 720p60 ABR encoding settings.

elif [[ "${res}" == "720p" ]]  || [ "${roundedfps}" == "60" ]
then
ffmpeg \
    -hide_banner \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]format=yuv420p,fps=60,split=5[1][2][3][4][5]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]null[5out]; \
    -map '[1out]' -c:v:0 ${x264enc} -g 120 -b:v:0 800k \
    -map '[2out]' -c:v:1 ${x264enc} -g 120 -b:v:1 1600k \
    -map '[3out]' -c:v:2 ${x264enc} -g 120 -b:v:2 2200k \
    -map '[4out]' -c:v:3 ${x264enc} -g 120 -b:v:3 4400k \
    -map '[5out]' -c:v:4 ${nvenc} -g 120 -b:v:4 6600k \
    -c:a:0 aac -b:a 128k -map 0:a \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &

# If the input is 720p50, then encode with 720p50 ABR encoding settings.

elif [[ "${res}" == "720p" ]]  || [ "${roundedfps}" == "50" ]
then
ffmpeg \
    -hide_banner \
    -f decklink \
    -i "$device" \
    -filter_complex \
    "[0:v]format=yuv420p,split=5[1][2][3][4][5]; \
    [1]hwupload_cuda,scale_npp=-1:288:interp_algo=lanczos,hwdownload[1out]; \
    [2]hwupload_cuda,scale_npp=-1:360:interp_algo=lanczos,hwdownload[2out]; \
    [3]hwupload_cuda,scale_npp=-1:432:interp_algo=lanczos,hwdownload[3out]; \
    [4]hwupload_cuda,scale_npp=-1:540:interp_algo=lanczos,hwdownload[4out]; \
    [5]null[5out]; \
    -map '[1out]' -c:v:0 ${x264enc} -g 100 -b:v:0 800k \
    -map '[2out]' -c:v:1 ${x264enc} -g 100 -b:v:1 1600k \
    -map '[3out]' -c:v:2 ${x264enc} -g 100 -b:v:2 2200k \
    -map '[4out]' -c:v:3 ${x264enc} -g 100 -b:v:3 4400k \
    -map '[5out]' -c:v:4 ${nvenc} -g 100 -b:v:4 6600k \
    -c:a:0 aac -b:a 128k -map 0:a \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -window_size 5 \
    -index_correction 1 \
    -remove_at_exit 1 \
    -adaptation_sets "id=0,streams=v id=1,streams=a" \
    -method PUT \
    -http_persistent 1 \
    -hls_playlist 1 \
     http://${1}/${vid}/manifest.mpd >/dev/null 2>~/streamline/logs/encode.log &
fi

# Create a web page with embedded hls.js player.

cat > /tmp/${vid}.html <<_PAGE_
<!doctype html>
<html>
   <head></head>
   <body>
      <style>
         body {
         background-color : black;
         margin : 0;
         }
         video {
         left: 50%;
         position: absolute;
         top: 50%;
         transform: translate(-50%, -50%);
         width: 100%;
         max-height: 100%;
         }
      </style>
      <script src="//cdn.jsdelivr.net/npm/hls.js@latest"></script>
      <video id="video" controls autoplay></video>
      <script>
         var video = document.getElementById('video');
         if(navigator.userAgent.match(/(iPhone|iPod|iPad)/i)) {
         video.src = 'master.m3u8';
         video.autoplay = true;
          }
          else if(Hls.isSupported()) {
            var hls = new Hls();
            hls.loadSource('master.m3u8');
            hls.attachMedia(video);
            hls.on(Hls.Events.MANIFEST_PARSED,function() {
              video.play();
          });
         }
      </script>
   </body>
</html>
_PAGE_

cat > /tmp/${vid}.dash.html <<_DASHPAGE_
<!DOCTYPE html>
<html>
  <head>
    <!-- Shaka Player compiled library: -->
    <script src="https://ajax.googleapis.com/ajax/libs/shaka-player/2.4.6/shaka-player.compiled.js"></script>
    <!-- Your application source: -->
    <script src="myapp.js"></script>
  </head>
  <body>
      <style>
         body {
         background-color : black;
         margin : 0;
         }
         video {
         left: 50%;
         position: absolute;
         top: 50%;
         transform: translate(-50%, -50%);
         width: 100%;
         max-height: 100%;
         }
      </style>
    <video id="video"
           width="640"
           poster="//shaka-player-demo.appspot.com/assets/poster.jpg"
           controls autoplay></video>
  </body>
</html>
_DASHPAGE_

cat > /tmp/${vid}.myapp.js <<_SHAKAJS_
// myapp.js

var manifestUri =
    'manifest.mpd';

function initApp() {
  // Install built-in polyfills to patch browser incompatibilities.
  shaka.polyfill.installAll();

  // Check to see if the browser supports the basic APIs Shaka needs.
  if (shaka.Player.isBrowserSupported()) {
    // Everything looks good!
    initPlayer();
  } else {
    // This browser does not have the minimum set of APIs we need.
    console.error('Browser not supported!');
  }
}

function initPlayer() {
  // Create a Player instance.
  var video = document.getElementById('video');
  var player = new shaka.Player(video);

  // Attach player to the window to make it easy to access in the JS console.
  window.player = player;

  // Listen for error events.
  player.addEventListener('error', onErrorEvent);

  // Try to load a manifest.
  // This is an asynchronous process.
  player.load(manifestUri).then(function() {
    // This runs if the asynchronous load is successful.
    console.log('The video has now been loaded!');
  }).catch(onError);  // onError is executed if the asynchronous load fails.
}

function onErrorEvent(event) {
  // Extract the shaka.util.Error object from the event.
  onError(event.detail);
}

function onError(error) {
  // Log the error.
  console.error('Error code', error.code, 'object', error);
}

document.addEventListener('DOMContentLoaded', initApp);
_SHAKAJS_

# Upload the player over HTTP PUT to the origin server


curl -X PUT --upload-file /tmp/${vid}.html http://${1}/${vid}/index.html -H "Content-Type: text/html; charset=utf-8" >/dev/null 2>~/streamline/logs/curlIndex.log &
curl -X PUT --upload-file /tmp/${vid}.html http://${1}/${vid}/hls.html -H "Content-Type: text/html; charset=utf-8" >/dev/null 2>~/streamline/logs/curlHLS.log &
curl -X PUT --upload-file /tmp/${vid}.dash.html http://${1}/${vid}/dash.html -H "Content-Type: text/html; charset=utf-8" >/dev/null 2>~/streamline/logs/curlDASH.log &
curl -X PUT --upload-file /tmp/${vid}.myapp.js http://${1}/${vid}/myapp.js -H "Content-Type: text/html; charset=utf-8" >/dev/null 2>~/streamline/logs/curlJS.log &

echo ...and awaaaaayyyyy we go! 🚀🚀🚀🚀

echo Input detected on ${device} as ${res} ${fps}

echo "Currently streaming HLS to HLS.js with HLS <video> fallback to : http://${2}/${vid}/index.html"
echo "Currently streaming HLS to HLS.js with HLS <video> fallback to: http://${2}/${vid}/hls.html"
echo "Currently streaming DASH to Shaka Player with HLS <video> fallback to: http://${2}/${vid}/dash.html"
