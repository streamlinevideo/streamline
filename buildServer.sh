#!/bin/bash

# Upgrade the OS

sudo apt-get -y update && sudo apt-get -y upgrade

# Make a directory to write from and read from for the caddy server

mkdir /home/ubuntu/streamline/www

# Make it writable

sudo chmod 775 /home/ubuntu/streamline/www

# Create cron jobs that remove old video manifests or segments after one minute after creation.
# Playlists will be pushed in constantly including the variant playlist, so, they should be unaffected unless stale.

(crontab -l 2>/dev/null; echo "*  *  *   *  * find /home/ubuntu/streamline/www/*.ts -mmin +1 -print0 | xargs -0 rm -r") | crontab -
(crontab -l 2>/dev/null; echo "*  *  *   *  * find /home/ubuntu/streamline/www/*.m4s -mmin +1 -print0 | xargs -0 rm -r") | crontab -

# Provide the command needed to set up the caddy server. (personal license)

echo "Please run: curl https://getcaddy.com | bash -s personal hook.service,http.cors,http.upload"
