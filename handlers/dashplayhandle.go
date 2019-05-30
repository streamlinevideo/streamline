package handlers

import (
	"net/http"
	"net/url"
	"path"

	"../utils"
)

type DashPlayHandler struct {
	BaseDir string
}

func (l *DashPlayHandler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	utils.GetDownloadLogger().Infof("Received play request\n")
	l.servePlayer(w, req)
}

func (l *DashPlayHandler) servePlayer(w http.ResponseWriter, req *http.Request) {
	curFileURL := req.URL.EscapedPath()[len("/ldashplay"):]
	curFilePath := path.Join("ldash", curFileURL)
	base, _ := url.Parse("http://" + req.Host)
	relativeUrl, _ := url.Parse(curFilePath)
	manifestUrl := base.ResolveReference(relativeUrl).String()
	utils.GetPlayerLogger().Infof("Set player path to %s", manifestUrl)
	html := `
	<!DOCTYPE html>
	<html ng-app="DashPlayer" lang="en">
	<head>
		<meta charset="utf-8"/>
		<title>Test Player for low latency DASH streams</title>
		<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
	<script>
			var mpd,availabilityStartTime,isLive,segmentDuration,representationID,baseURL,initURL,segmentURL,player,mse,sb,bufferInitString,segmentIndex,isFirstSegment,forceStartNumber,statsID,waitingToStart,nextSegment,nextSegmentAvailabilityTime,segBehindLive,waitingForNextSegment,timeShiftBufferDepth,xhr,seekTarget,loadStartTime,startNumber,minimumUpdatePeriod,availabilityTimeOffset,sourceBufferQueue,latency,ticker,speedTestStartTime,segmentKbps,speedTestInterval,buffer,xhrm,testBytesToLoad,data,chart,options,formatter,targetBuffer;
			var maxBuffer = 30;
			var seeking = false;
			var hdntl = "";
			var firstManifestLoad = true;
			var minBuffer = 10;
			var maxBuffer = 0;
			var rebufferCount = 0;
			var paused = false;
			var maxLoadTime = 0;
			var totalLoadTime = 0;
			var totalLoadCount = 0;
			var totalGoodCount = 0;
			var totalGood500Count = 0;
			var accumulatedDelay = 0;
			var autoStartAfterVisibilityChange = false;


			function setSource()
			{
				document.querySelector("#mpd").value = "` + manifestUrl + `"
				forceStartNumber = queryArgs("segmentStartNumber") == "" ? NaN:queryArgs("segmentStartNumber");
				document.querySelector("#segBehind").value = queryArgs("segmentsBehind") == "" ? 0:queryArgs("segmentsBehind");
				if (window.MediaSource == undefined)
				{
						alert("Warning: MediaSource APIs are not supported in this browser!")
				}
				if (!self.fetch)
				{
						alert("Warning: this browser does not support the fetch API. This player will fail!")
				}
				//ticker = new Worker("tick.js");
				document.addEventListener("visibilitychange", handleVisibilityChange, false);

			}


			function loadManifest()
			{

				var xhrm = new XMLHttpRequest();
				xhrm.open('GET', document.querySelector("#mpd").value, true);
				xhrm.responseType = 'document';
				xhrm.overrideMimeType('text/xml');
				xhrm.onload = function(e) {
				mpd = this.responseXML; 
				log(mpd);
				isLive = String(mpd.documentElement.getAttribute("type")) === "dynamic";
				log("isLive = " + isLive)
				availabilityStartTime = mpd.documentElement.getAttribute("availabilityStartTime");
				availabilityStartTime = availabilityStartTime.includes("Z") ? availabilityStartTime: availabilityStartTime + "Z";
				availabilityStartTime = new Date(availabilityStartTime).getTime();
				log("availabilityStartTime =" + availabilityStartTime);
				minimumUpdatePeriod = Number(mpd.documentElement.getAttribute("minimumUpdatePeriod").replace(/\D/g,''));
				log("minimumUpdatePeriod = " + minimumUpdatePeriod);
				var duration = Number(mpd.getElementsByTagName("SegmentTemplate")[0].getAttribute("duration"));
				var timescale = Number(mpd.getElementsByTagName("SegmentTemplate")[0].getAttribute("timescale"));
				log("duration=" + duration);
				log("timescale=" + timescale);
				segmentDuration = duration/timescale; 
				log("segmentDuration=" + segmentDuration);
				document.querySelector("#segDurationDisplay").innerHTML  = segmentDuration*1000;
				timeShiftBufferDepth = mpd.documentElement.getAttribute("timeShiftBufferDepth");
				timeShiftBufferDepth = timeShiftBufferDepth == null ? 0: Number(timeShiftBufferDepth.replace(/\D/g,''));
				document.querySelector("#dvrLength").innerHTML = timeShiftBufferDepth + "s";
				log("segmentDuration =" + segmentDuration + "s");
				representationID = mpd.getElementsByTagName("Representation")[0].getAttribute("id");
				log("representaitonID = " + representationID);
				baseURL = document.querySelector("#mpd").value.split(".mpd")[0];
				baseURL = baseURL.substring(0,baseURL.lastIndexOf("/")+1);
				log("baseURL=" + baseURL);
				var segTemp = mpd.getElementsByTagName("SegmentTemplate").length > 1 ? mpd.getElementsByTagName("SegmentTemplate")[1]: mpd.getElementsByTagName("SegmentTemplate")[0];
				var initName = segTemp.getAttribute("initialization");
				log("initname=" + initName);
				availabilityTimeOffset = Number(segTemp.getAttribute("availabilityTimeOffset"))*1000;
				log("availabilityTimeOffset=" + availabilityTimeOffset);
				initURL = baseURL + initName.replace("$RepresentationID$", representationID);
				log("initURL=" + initURL);
				var segmentName = segTemp.getAttribute("media");
				segmentURL = baseURL + segmentName.replace("$RepresentationID$", representationID);
				log("segmentURL=" + segmentURL);
				startNumber = parseInt(segTemp.getAttribute("startNumber"));
				log("startNumber=" + startNumber);
				if (firstManifestLoad)
				{
					
					google.charts.load('current', {'packages':['corechart']});
					google.charts.setOnLoadCallback(initializeChart);
					// set a timer to reload the manifest every minimumUpdatePeriod.
					setInterval(loadManifest,1000*minimumUpdatePeriod);
					firstManifestLoad = false;

					var mimeType = mpd.getElementsByTagName("Representation")[0].getAttribute("mimeType");
					if (mimeType == null)
					{
					mimeType = mpd.getElementsByTagName("AdaptationSet")[0].getAttribute("mimeType");
					}
					var codecs = mpd.getElementsByTagName("Representation")[0].getAttribute("codecs");
					if (codecs == null)
					{
					codecs = mpd.getElementsByTagName("AdaptationSet")[0].getAttribute("codecs");
					}
					bufferInitString = mimeType + '; codecs="' + codecs + '"';
					log("bufferInitString = " + bufferInitString);
					player = document.querySelector("#player");
					player.addEventListener("pause",onPlayerPause,false);
					player.addEventListener("playing",onPlayerPlaying,false);
					mse = new MediaSource();
					mse.addEventListener('sourceopen', onSourceOpen.bind(null, player, mse));
					player.src = URL.createObjectURL(mse);
					segBehindLive = Number(document.querySelector("#segBehind").value) ;
					targetBuffer = Number(document.querySelector("#targetBufferInput").value) ;
					log("Segments behind live = " + segBehindLive);
				}
				
				};

				xhrm.send();
			}

			function onSourceOpen(video, mse, evt) {
				log("onSourceOpen()");
				sb = mse.addSourceBuffer(bufferInitString);
				sb.addEventListener('updateend', onUpdateEnd);
				log('source buffer added');
				loadPresentation();
			};
			function onUpdateEnd()
			{
			checkForDataToAppend();
			}

			function onPlayerPause()
			{
			log("player paused");
			paused = true;
			}

			function onPlayerPlaying()
			{
			paused = false;
			if (!isFirstSegment)
			{  
				checkExcessiveLatency();
			}
			}

			function handleVisibilityChange()
			{
			log("page is " + document.visibilityState);
			if (document.visibilityState == "hidden")
			{
				autoStartAfterVisibilityChange = !paused;
				if (player)
				{
				player.pause();
				}
			}
			else
			{
				if (autoStartAfterVisibilityChange)
				{
					player.play();
				}
			
			}


			}

			function checkForDataToAppend()
			{
			if (!sb.updating && sourceBufferQueue.byteLength > 0)
			{
				// we feed the sourceBuffer 50kB chunks at a time
				var dataToAppend = sourceBufferQueue.slice(0,50000);
				sourceBufferQueue = sourceBufferQueue.slice(50000);
				sb.appendBuffer(dataToAppend);
			}
			}

			function checkExcessiveLatency()
			{
			// if (latency > 6000)
			// {
			//   log("latency is excessive. Seeking back to live");
			//   clearInterval(statsID);
			//   sb.abort();
			//   sb.remove(0,sb.buffered.end(0));
			//   if (xhrm)
			//   {
			//     xhrm.abort();
			//   }
			//   clearTimeout(speedTestInterval);
			//   loadPresentation();
			// }
			}

			function downloadUsingFetch(url,context,callback)
			{
			var totalBytes = 0;
			fetch(url).then(function(response) {

						if(!response.ok) {
							log(response.status + " received on segment load, so waiting 100 ms and then retrying seg " + context);
							document.querySelector("#latency").innerHTML = "(Searching for the live edge " + new Date().getTime() + ")";
							setTimeout(loadNextSegment,100);
							return -1;
						} 

						var pump = function(reader) {
							return reader.read().then(function(result) {
								// if we're done reading the stream, return
								if (result.done) {
									return totalBytes;
								}
								// retrieve the multi-byte chunk of data
								var chunk = result.value;
								totalBytes += chunk.byteLength;
								// Is there a more efficient way to concatenate Uint8 arrays??
								if (sourceBufferQueue)
								{
								var tmp = new Uint8Array(sourceBufferQueue.byteLength + chunk.byteLength);
								tmp.set(new Uint8Array(sourceBufferQueue), 0);
								tmp.set(new Uint8Array(chunk), sourceBufferQueue.byteLength);
								sourceBufferQueue = new Uint8Array(tmp.buffer);
								} else
								{
								sourceBufferQueue = new Uint8Array(chunk);
								}
								checkForDataToAppend();
								return pump(reader);
							});
						
						}

						// start reading the response stream
						return pump(response.body.getReader());
					})
					.then(function(bytelength) 
					{
					if (bytelength > 0)
					{
						callback(bytelength,context);
					}
					
					})
					.catch(function(error) {
						log("Error [" + error + "] received on segment load, so waiting 1000 ms and then retrying seg " + context);
						setTimeout(loadNextSegment,1000);
						return -1;
					});
			}
				


			function loadPresentation()
			{ 
				waitingForNextSegment = false;
				waitingToStart = true;
				downloadUsingFetch(initURL, 0, function( bytelength, context) {
				log('init segment downloaded' + bytelength);

					if (isNaN(forceStartNumber))
					{
						if (isLive)
						{
							
							segmentIndex = latestAvailableSegement();
							log("Now is " + new Date().getTime() + " " + availabilityStartTime + " " + startNumber + " " + segBehindLive);
							log("starting time offset for live = " + (new Date().getTime() - availabilityStartTime)/1000);
							log("First segment to be loaded: " + segmentIndex);
						}
						else
						{
							segmentIndex = 0;
						}
					}
					else
					{
						segmentIndex = forceStartNumber;
						log("Forcing the starting segment number to " + segmentIndex);
					}
					isFirstSegment = true;
					log("starting segment index is " + segmentIndex);
					statsID = window.setInterval(updateStats, 100);
					//ticker.postMessage(100);
					//ticker.addEventListener("message",updateStats);
					//ticker.postMessage("start");
					loadNextSegment();
				
				});
			}

			function pad(num)
			{
			if (num < 10)
			{
				return String("0000" + num);
			}
			else if(num < 100)
			{
				return String("000" + num);
			}
			else if(num < 1000)
			{
				return String("00" + num);
			}
			else if(num < 10000)
			{
				return String("0" + num);
			}
			else
			{
				return String(num);
			}


			}

			function loadNextSegment()
			{
			
				loadStartTime = new Date().getTime();
				var url = segmentURL.replace("$Number%05d$",pad(segmentIndex));
				downloadUsingFetch(url, segmentIndex, function( bytelength, context) {
						var delta = (new Date().getTime()) - loadStartTime;
						segmentKbps = Math.round(bytelength*8/delta);
						var msg = "seg#" + context + " with " + Math.round(bytelength/1000) + " kbytes downloaded in " + delta + "ms at " + segmentKbps + "kbps";
						log(msg);
						var color = delta > segmentDuration*1000 ? "#CC0000":"#0000ff";
						data.addRow([new Date(loadStartTime), delta, 'Seg #' + context,'point {fill-color: ' + color + '}']);

						if (data.getNumberOfRows() > Number(document.querySelector("#maxPoints").value))
						{
						data.removeRow(0);
						}

						

						chart.draw(data, options);
						totalLoadTime = totalLoadTime + delta;
						totalLoadCount = totalLoadCount + 1;
						if (delta < 1050*segmentDuration)
						{
						totalGoodCount = totalGoodCount + 1;
						} else
						{
						accumulatedDelay = accumulatedDelay + ((delta/1000)  - segmentDuration);
						}
						if (delta < (1000*segmentDuration + 500))
						{
						totalGood500Count = totalGood500Count + 1;
						} 

					
						
						if (delta > maxLoadTime)
						{
						maxLoadTime = delta;
						}
						document.querySelector("#segmentStatus").innerHTML = msg;
						msg = "Playhead at " + player.currentTime;
						for  (var i=0; i < sb.buffered.length;i++)
						{
						msg += ". Buffered range from " + sb.buffered.start(i) + "-" + sb.buffered.end(i)
						}
						log(msg);
						if (isFirstSegment)
						{
							isFirstSegment = false;
						}
						segmentIndex ++;
						waitingForNextSegment = true;

				});
			}

			function startDelayedPlay()
			{
			buffer = Math.round((sb.buffered.end(0) - player.currentTime)*100)/100;
			log("Buffer prestart is " + buffer)
			var delay = targetBuffer - buffer;
			if (delay > 0)
			{
				log("Setting delay of " + delay + " for start");
				setTimeout(function()
					{ 
						player.play();
						log("Starting playback at playhead position " + player.currentTime);
					}, delay*1000);
			} else
			{
				log("Buffer is large enough so starting");
				player.play();
				log("Starting playback at playhead position " + player.currentTime);
			}  
			}

			function updateStats()
			{

				if (sb && sb.buffered.length > 0)
				{
					var now = new Date();
					buffer = Math.round((sb.buffered.end(0) - player.currentTime)*100)/100;
					minBuffer  = buffer < minBuffer && !waitingToStart ? buffer:minBuffer;
					maxBuffer  = buffer > maxBuffer  && !waitingToStart ? buffer:maxBuffer;
					latency = Math.round(now.getTime() - (player.currentTime*1000 + availabilityStartTime));
					document.querySelector("#bufferStatus").innerHTML =  seeking ? "seeking ..." : waitingToStart ? " (buffering ...)":buffer +"s (min:" + minBuffer + " max:" + maxBuffer + ")";
					document.querySelector("#latency").innerHTML = "<strong>" + latency + "ms</strong>";
					document.querySelector("#wallclock").innerHTML = "<strong>Wall clock time <br>" + (now.getMinutes() < 10 ? "0"+now.getMinutes():now.getMinutes()) + ":" + (now.getSeconds() < 10 ? "0"+now.getSeconds():now.getSeconds()) + ":" + precision(now.getMilliseconds(),true) + "</strong>";
					document.querySelector("#percentReceived").innerHTML  = Math.round(totalGoodCount*100/totalLoadCount) + "%";
					document.querySelector("#percentReceived500").innerHTML  = Math.round(totalGood500Count*100/totalLoadCount) + "%";
					document.querySelector("#maxDownload").innerHTML = maxLoadTime;
					document.querySelector("#accumulatedDisplay").innerHTML  = Math.round(accumulatedDelay*100)/100;
				
					if (waitingToStart && buffer > 0)
					{
					
						waitingToStart = false;
						player.currentTime = sb.buffered.start(0);
						speedTestInterval = setTimeout(startSpeedTest,5000);
						testBytesToLoad = 100000;
						startDelayedPlay();
					}
				
					player.playbackRate = buffer > targetBuffer ? 1.05:1;

					if (waitingForNextSegment && !paused)
					{
					var latestAvailable = latestAvailableSegement();

					if (segmentIndex <= latestAvailable)
					{
						waitingForNextSegment = false;
						loadNextSegment();
					}
					}
				}
				else if (isFirstSegment == true)
				{
				document.querySelector("#bufferStatus").innerHTML = "(buffering ...)";
				}
				
			}

			function latestAvailableSegement()
			{
				return Math.floor((new Date().getTime() - 500 - availabilityStartTime + availabilityTimeOffset - (1000*segmentDuration))/(1000*segmentDuration)) + Number(startNumber) - segBehindLive;
			}

			function queryArgs(name) {
				name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
				var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"),
					results = regex.exec(location.search);
				return results == null ? "" : decodeURIComponent(results[1].replace(/\+/g, " "));
			}

			function precision(n,leftAlign,length)
			{
			var output = n;
			if (n < 10)
			{
				output = leftAlign ? n + "00": "00" + n;
			}
			else if (n < 100)
			{
				output = leftAlign ? n + "0": "0" + n;
			}

			return output
			}


			function log(msg)
			{
				console.log(msg);
			}

			function startSpeedTest()
			{
			if (document.querySelector("#estimateThroughput").checked)
			{
				var url = document.querySelector("#mpd").value.split(".mpd")[0];
				url = url.substring(0,url.lastIndexOf("/")+1) + "Buffertest.bin";
				log("speed test of " + testBytesToLoad + "bytes against " + url);
				speedTestStartTime = new Date().getTime();
				document.querySelector("#throughput").innerHTML = "Estimating ...";
				latencyAtTestStart = latency;
				var xhrm = new XMLHttpRequest();
				xhrm.open('GET', url, true);
				xhrm.timeout = 8000;
				xhrm.addEventListener("progress", onSpeedTestProgress.bind(null, xhrm));
				xhrm.responseType = 'blob';
				xhrm.setRequestHeader('Range', 'bytes=0-' + testBytesToLoad);
				xhrm.onload = function(e) {
					var timeDelta = new Date().getTime() - speedTestStartTime;
					var kbps = Math.round(xhrm.response.size*8/timeDelta) + segmentKbps;
					log("speed test estimate" + kbps + "in " + timeDelta + 'ms');
					document.querySelector("#throughput").innerHTML = kbps + "kbps using a " + (testBytesToLoad/1000) + "kB target";
					clearTimeout(speedTestInterval);
					if (timeDelta < 300)
					{
					testBytesToLoad = testBytesToLoad*2 > 1000000 ? 1000000: testBytesToLoad*2;

					}
					else
					{
					testBytesToLoad = testBytesToLoad/2 < 100000 ? 100000: testBytesToLoad/2;
					}
					speedTestInterval = setTimeout(startSpeedTest,10000);
				};

				xhrm.send();
			}
			}

			function onSpeedTestProgress(xhrm)
			{
			var latencyRatio = latency/latencyAtTestStart;
			if (latencyRatio > 1.05)
			{
				log('aborting speed test due to latency rise of ' + latencyRatio);
				testBytesToLoad = 100000;
				document.querySelector("#throughput").innerHTML = 'Aborting due to latency rise. Try again in 20s';
				clearTimeout(speedTestInterval);
				speedTestInterval = setTimeout(startSpeedTest,20000);
				xhrm.abort();
			}
			}

			function initializeChart()
			{
			options = {
				title: 'Segment download time for an advertized segment duration of ' + segmentDuration*1000 + 'ms ',
				hAxis: {title: 'Local time at which segment download was initiated'},
				vAxis: {title: 'Request time (ms)'},
				legend: 'none',
				explorer: { actions: ['dragToZoom', 'rightClickToReset'],
					maxZoomIn: 0 } 
			};
			data = new google.visualization.DataTable();
			data.addColumn('date', 'Time');
			data.addColumn('number', 'Download time (total)');
			data.addColumn({type:'string', role:'tooltip'}); 
			data.addColumn({'type': 'string', 'role': 'style'});
			formatter = new google.visualization.ColorFormat();
			//formatter.addRange(null, segmentDuration*1000, 'blue', 'blue');
			//formatter.addRange((segmentDuration*1000) + 1, null, 'red', 'red');
			formatter.addRange(0, 1000, 'red', 'red');
			chart = new google.visualization.ScatterChart(document.getElementById('chart_div'));

			}

	</script>
	</head>
	<body onload="setSource()">
		<div>
	Dash Test Player for low latency. Make sure your system clock has been recently synched to a NTP server. <br/>
	Segments behind <now> for live: <input id="segBehind" type="text"  value="0" style="width:20px">&nbsp;
	Target buffer in seconds: <input id="targetBufferInput" type="text"  value="2.2" style="width:25px">&nbsp;
	Enable throughput estimation: <input id="estimateThroughput" type="checkbox" >&nbsp;
	Max number of chart data points: <input id="maxPoints" type="text"  value="500" style="width:30px"><br/>
	Enter the mpd to test: <input id="mpd" type="text"  style="width:500px">
	<input type="button" value="LOAD" onclick="loadManifest()">
	</div>
	<table width="100%">
	<tr><td width="640px">
				<div>
					<video id="player" controls style="width=640px;height:360px"></video>
					<div>
					<span id="wallclock" style="font-family: Arial, Helvetica, sans-serif; color:white;background:black;width:270px;font-size:xx-large;z-index: 10;position: absolute;top:125px;left:25px"></span>  

					</div>
				</div>
	</td><td valign="top" align="left">
	<div id="chart_div" style="width: 100%; height: 360px;"><br>
	</td></tr>
	<tr><td colspan=2>


				<div>
					Live latency estimate (not including encoder delay): <span id="latency"></span><br/>
					Buffer: <span id="bufferStatus"></span><br/>
					Download: <span id="segmentStatus"></span><br/>
					Length of DVR window: <span id="dvrLength"></span><br/>
					Throughput available estimate: <span id="throughput">Not selected</span><br/>
					Manifest declared SegmentDuration (ms): <span id="segDurationDisplay"></span><br/>
					Maximum segment download time (ms): <span id="maxDownload"></span><br/>
					% Segments received in less than 1.05xSD: <span id="percentReceived"></span><br/>
					% Segments received in less than SD + 500ms: <span id="percentReceived500"></span><br/>
					Accumulated delay (s): <span id="accumulatedDisplay"></span><br/>
					
			
				</div>
	</td></tr>
	</table>
			

	</body>
	</html>
	`
	w.Write([]byte(html))
}
