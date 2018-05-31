#!/bin/bash

# update the OS

sudo add-apt-repository -y ppa:graphics-drivers/ppa

sudo apt-get -y update

sudo apt-get -y upgrade

# Download capture card drivers and SDK

wget https://hellavision.s3-us-west-2.amazonaws.com/Blackmagic_DeckLink_SDK_10.10.zip

wget https://hellavision.s3-us-west-2.amazonaws.com/Blackmagic_Desktop_Video_Linux_10.10.tar

# Install dependencies

sudo apt-get install -y --allow-unauthenticated nasm autoconf htop \
automake build-essential libass-dev curl zlib1g-dev openssh-server \
autoconf libfreetype6-dev texinfo zlibc nvidia-390 \
libsdl2-dev libtool libvdpau-dev libxcb1-dev libxcb-shm0-dev \
libpango1.0-0 libfdk-aac-dev yasm unzip libxcb-xfixes0-dev texi2html \
libssl-dev libx264-dev dkms libssh-dev pkg-config \
nvidia-cuda-toolkit g++-5 libnuma1 libnuma-dev libc6 libc6-dev

# Install NVIDIA GPU SDK

unzip -n *.zip

sudo cp -vr Video_Codec_SDK_8.0.14/Samples/common/inc/GL/* /usr/include/GL/

sudo cp -vr Video_Codec_SDK_8.0.14/Samples/common/inc/*.h /usr/include/

# Install FFmpeg NVIDIA headers

git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git

cd ~/streamline/nv-codec-headers

make

sudo make install

cd ~/streamline

# Install Black Magic capture card driver and SDK

unzip -n Blackmagic_DeckLink_SDK_10.10.zip

mv -n 'Blackmagic DeckLink SDK 10.10' Blackmagic_DeckLink_SDK_10.10

tar -xvf Blackmagic_Desktop_Video_Linux_10.10.tar

sudo dpkg -i Blackmagic_Desktop_Video_Linux_10.10/deb/x86_64/*

sudo cp -r Blackmagic_DeckLink_SDK_10.10/Examples/Linux/bin/x86_64/* /bin/

# Download and compile FFmpeg

rm -r -f ~/streamline/FFmpeg/

wget https://ffmpeg.org/releases/ffmpeg-4.0.tar.bz2

tar xvjf ffmpeg-4.0.tar.bz2

cd ffmpeg-4.0

# Configure FFmpeg build

./configure \
  --extra-cflags=-I$HOME/streamline/Blackmagic_DeckLink_SDK_10.10/Linux/include \
  --extra-ldflags=-L-I$HOME/streamline/Blackmagic_DeckLink_SDK_10.10/Linux/include \
  --extra-cflags=-I/usr/local/cuda/include/ \
  --extra-ldflags=-L/usr/local/cuda/lib64/ \
  --extra-cflags=-I/usr/local/include/ \
  --extra-ldflags=-L/usr/local/include/ \
  --enable-gpl \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libx264 \
  --enable-nonfree \
  --enable-openssl \
  --enable-decklink \
  --enable-libnpp \
  --enable-cuda-sdk \
  --enable-libfreetype

# Build ffmpeg

make

# Install FFmpeg

sudo make -j$(nproc) install

make -j$(nproc) distclean

hash -r

# Remove downloads

cd ~/streamline

rm -r -f *.zip *.deb *.tar ffmpeg*

rm -r -f nv-codec-headers *Blackmagic*

echo "You are ready to reboot."
