/**
 * Get the URI for the content that we want to play.
 *
 * This assumes that there is a url parameter with the key "video" that
 * points to the name of the video we want to play. Will return |null| if
 * it does not find the uri.
 *
 * Examples:
 *  URL                                   | OUTPUT
 *  --------------------------------------+--
 *  index.html/?video=my-video.m3u8       | "my-video.m3u8
 *  index.html/?video=my-other-video.m3u8 | "my-other-video.m3u8"
 *  index.html/                           | null
 *
 * @param {string} url
 * @return {?string}
 */
function getContentUri(url) {
  // Get the params, if there are none, continu with an empty string.
  var paramsToken = url.split('?')[1] || '';

  // Get an array of x=y for each param.
  var keyValueTokens = paramsToken.split('&');

  // Break each token into a key and value string.
  var keyValues = keyValueTokens.map(function(token) {
    return token.split('=');
  });

  var videos = keyValues.filter(function(pair) {
    return pair[0] == 'video';
  });

  // If |videos.length == 0|, then |videos[0]| will be |undefined|.
  var foundPair = videos[0] || [];
  return foundPair[1] || null;
}

/**
 * Find the main video element on the page that we want to play
 * video on. Will return |null| if the video element is not found.
 *
 * @return {HTMLMediaElement}
 */
function getVideoElement() {
  var videoId = 'video';
  var video = document.getElementById(videoId);

  return /** @type {HTMLMediaElement} */ (video);
}

/**
 * Play the content at |contentUri| on |videoElement| using the
 * platform-provided method (src=).
 *
 * @param {!HTMLMediaElement} videoElement
 * @param {string} contentUri
 */
function playUsingNativeSupport(videoElement, contentUri) {
  videoElement.src = contentUri;
  videoElemment.autoplay = true;
}

/**
 * Play the content at |contentUri| on |videoElement| using the HLS JS library.
 *
 * @param {!HTMLMediaElement} videoElement
 * @param {string} contentUri
 */
function playUsingHlsJS(videoElement, contentUri) {
  var hls = new Hls();
  hls.loadSource(contentUri);
  hls.attachMedia(videoElement);
  hls.on(Hls.Events.MANIFEST_PARSED, function() {
    videoElement.play();
  });
}

function main() {
  // On iOS devices 'video.src=' supports playing HLS manifests, so we
  // can use that directly.
  var useNative = navigator.userAgent.match(/(iPhone|iPod|iPad)/i);

  var contentUri = getContentUri(window.location.href);
  var video = getVideoElement();

  if (!video) {
    console.log('Could not find video element.',
                'Playback was aborted.');
    return;
  }

  if (useNative) {
    playUsingNativeSupport(video, contentUri);
  } else if (Hls.isSupported()) {
    playUsingHlsJS(video, contentUri);
  } else {
    console.log(
        'Failed to start playback.',
        'HLS playback is not supported on this platform.');
  }
}

document.addEventListener('DOMContentLoaded', main);
