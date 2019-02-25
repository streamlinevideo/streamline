#!/bin/bash

# install go repo

sudo add-apt-repository -y ppa:longsleep/golang-backports

# update the OS

sudo apt-get -y update

sudo apt-get -y upgrade

sudo apt-get install golang-go

go get -d -v .

go build

go get -d -v .

go build

sudo apt-get install nginx
