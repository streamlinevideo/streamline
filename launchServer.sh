#!/bin/bash

go run main.go "/var/www/html"  2>logs/server.log &
