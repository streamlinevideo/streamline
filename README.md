This is an experimental branch of Streamline.

There will be a new parts list and new walkthrough as well. 

This update will reduce the parts cost and increases quality by switching to RTX generation GeForce cards rather than older Quadros. 

We will drop one bitrate lane to be able to use a Geforce instead of a quadro, 1440p. It's unclear if that is even really worth the extra uplink bandwidth.

We also add simultaneous creation of MPEG-DASH streaming alongside HLS. 

You can now use either protocol, with Shaka Player being added as the DASH player. 

We also have added CMAF low latency dash and LHLS.

TODOs

Move all encoding / transcoding server side. 

Add VP9 transcoding with ngcodec FPGAs on F1 instances 

Make the low latency server auto run at boot. 

Clean up the low latency player page. 

Figure out how to do low latency with ABR. 
