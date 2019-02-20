#!/bin/bash

sudo go run main.go "/var/www/html"  2>logs/server.log &
sudo nginx
