This is an experimental branch of Streamline.

There will be a new parts list and new walkthrough as well. 

It reduces the parts cost and increases quality by switching to RTX generation GeForce cards rather than older Quadros. 

We will drop one bitrate lane to be able to use a Geforce instead of a quadro, 1440p. It's unclear if that is even really worth the extra uplink bandwidth.

We also add simultaneous creation of MPEG-DASH streaming alongside HLS. You can now use either protocol, with Shaka Player being added as the DASH player. 

TODOs

Before moving this to the main line branch we will also likely switch away from Caddy server to NGINX or Apache to simplify setup and remove the need for a "personal" license. We will alow experiment with using our low latency server demo software with chunked transfer ingest but normal style egress for higher latency streams. 

We may add another URL to a non-abr low-latency stream as an option. Low Latency ABR in DASH.js isn't working perfectly at the moment, but, for some applications you might be willign to give up ABR for latency.
