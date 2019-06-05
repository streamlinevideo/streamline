#!/bin/bash

# Update and upgrade the OS
sudo apt-get -y update
sudo apt-get -y upgrade

# Install dependencies
sudo apt-get install -y \
automake autoconf yasm build-essential pkg-config dkms \
unzip htop curl golang-go \
nvidia-cuda-toolkit libsdl2-dev libssl-dev openssh-server \
libx264-dev libvpx-dev libopus-dev libssh-dev

# Download and install the Black Magic capture card drivers and SDK
curl -o "bmddv.tar" "https://hellavision.s3-us-west-2.amazonaws.com/Blackmagic_Desktop_Video_Linux_11.1.tar"
tar -xvf bmddv.tar
mv "Blackmagic_Desktop_Video_Linux_11.1" bmddv
sudo dpkg -i bmddv/deb/x86_64/*
rm bmddv.tar
curl -o "bmdsdk.zip" "https://hellavision.s3-us-west-2.amazonaws.com/Blackmagic_DeckLink_SDK_11.1.zip"
unzip -n bmdsdk.zip
mv *DeckLink* bmdsdk
sudo cp -r bmdsdk/Examples/Linux/bin/x86_64/* /bin/

# Install FFmpeg NVIDIA headers
git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
cd nv-codec-headers
make
sudo make install
cd ..

# Patch NVIDIA driver for greater than two NVENC encodes
sudo utils/patch.sh

# Download and compile FFmpeg
git clone https://github.com/FFmpeg/FFmpeg.git -b master
cd FFmpeg
./configure \
  --extra-cflags=-I../bmdsdk/Linux/include \
  --extra-ldflags=-L-I../bmdsdk/Linux/include \
  --enable-gpl \
  --enable-libx264 \
  --enable-nonfree \
  --enable-libvpx \
  --enable-libopus \
  --enable-openssl \
  --enable-decklink \
  --enable-libnpp \
  --enable-cuda-nvcc
make -j$(nproc)
sudo make install
make distclean
cd ..

# Build server for local testing
./buildServer.sh

# Remove downloads
rm -r -f *.zip *.deb *.tar ffmpeg* FFmpeg* bmd*
echo "You are ready to reboot."
