#!/bin/bash

# install go repo

sudo add-apt-repository -y ppa:longsleep/golang-backports

# update the OS

sudo apt-get -y update

sudo apt-get -y upgrade

sudo apt-get install golang-go

go/bin/go get -d -v .

go/bin/go build

go/bin/go get -d -v .

go/bin/go build

sudo apt-get install nginx
