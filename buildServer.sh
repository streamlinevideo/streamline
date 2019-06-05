#!/bin/bash

# Upgrade the OS
sudo apt-get -y update
sudo apt-get -y upgrade

# Build the Server
go get -d -v .
go build


# Make a working directory
rm -r -f www logs
mkdir www logs
sudo chmod 775 www
