#!/bin/bash

# Update the OS
sudo apt-get -y update
sudo apt-get -y upgrade

# Install dependencies
sudo apt-get install -y htop openssh-server nasm yasm libnuma1 libnuma-dev libc6 libc6-dev \
pkg-config dkms automake build-essential curl zlib1g-dev autoconf texinfo texi2html zlibc libtool \
libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev libass-dev libfreetype6-dev libx264-dev libvpx-dev \
libopus-dev libssl-dev libssh-dev libsdl2-dev nvidia-cuda-toolkit

# Download and Install BlackMagic DesktopVideo apps and Driver
curl -o bmddv.tar "https://s3-us-west-2.amazonaws.com/hellavision/Blackmagic_Desktop_Video_Linux_11.1.tar"
tar -xvf bmddv.tar
mv Blackmagic_Desktop_Video_Linux_11.1 bmddv
sudo dpkg -i bmddv/deb/x86_64/*

# Download and Install Black Magic SDK
curl -o bmdsdk.zip "https://s3-us-west-2.amazonaws.com/hellavision/Blackmagic_DeckLink_SDK_11.1.zip"
unzip -n bmdsdk.zip
mv *DeckLink* bmdsdk
sudo cp -r bmdsdk/Examples/Linux/bin/x86_64/* /bin/

# Patch NVIDIA drivers to allow for GeFoce card to enable more than two simultaneous encodes
# Thanks to https://github.com/keylase/nvidia-patch
sudo ./patch.sh

# Install FFmpeg NVIDIA headers
git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
cd nv-codec-headers
make
sudo make install
cd ..

# Download, configure, and build ffmpeg
git clone https://github.com/FFmpeg/FFmpeg.git -b master
cd FFmpeg
./configure \
  --extra-cflags=-I$HOME/streamline/bmdsdk/Linux/include \
  --extra-ldflags=-L-I$HOME/streamline/bmdsdk/Linux/include \
  --enable-gpl \
  --enable-libass \
  --enable-libx264 \
  --enable-libvpx \
  --enable-libopus \
  --enable-nonfree \
  --enable-openssl \
  --enable-decklink \
  --enable-libnpp \
  --enable-cuda-nvcc \
  --enable-libfreetype

# Compile and Install ffmpeg
make -j 16
sudo make -j 16 install

# Remove downloads
cd ~/streamline
rm -r -f *.zip *.deb *.tar ffmpeg* bmd*
rm -r -f nv-codec-headers

# Tell user they may reboot now
echo "You are ready to reboot."
