#!/bin/bash

# Update the OS Install dependencies

sudo service gdm stop

sudo apt-get remove -y nvidia*

sudo add-apt-repository -y ppa:longsleep/golang-backports

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-repo-ubuntu1804_10.0.130-1_amd64.deb

sudo dpkg -i cuda-repo-ubuntu1804_10.0.130-1_amd64.deb

sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

sudo apt-get -y update

sudo apt-get install -y cuda-libraries-10-0 gcc nasm autoconf htop net-tools libpango1.0-0 libpangox-1.0-0 \
automake build-essential openssh-server texinfo zlibc net-tools curl golang-go \
yasm unzip libssl-dev libx264-dev dkms pkg-config nvidia-cuda-toolkit nginx

wget https://download.nvidia.com/XFree86/Linux-x86_64/418.30/NVIDIA-Linux-x86_64-418.30.run

sudo chmod +x NVIDIA-Linux-x86_64-418.30.run

sudo ./NVIDIA-Linux-x86_64-418.30.run -s

wget https://s3-us-west-1.amazonaws.com/streamlinevideo/Blackmagic_DeckLink_SDK_10.11.4.zip

unzip Blackmagic_DeckLink_SDK_10.11.4.zip

rm *.zip

mv *SDK* Blackmagic_DeckLink_SDK_10.11.4

sudo cp -r Blackmagic_DeckLink_SDK_*/Examples/Linux/bin/x86_64/* /bin/

wget https://s3-us-west-1.amazonaws.com/streamlinevideo/Blackmagic_Desktop_Video_Linux_10.11.4.tar.gz

tar -xvzf Blackmagic_Desktop_Video_Linux_*.tar.gz

sudo dpkg -i Blackmagic_Desktop_Video_Linux_*/deb/x86_64/*

sudo cp -r Blackmagic_DeckLink_SDK_*/Examples/Linux/bin/x86_64/* /bin/

rm -r -f FFmpeg

git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git

cd nv-codec-headers

make

sudo make install

cd ..

# Download and compile FFmpeg

git clone https://github.com/FFmpeg/FFmpeg.git -b master

cd FFmpeg

sed -i '38,39d' libavutil/cuda_check.h

#  Configure FFmpeg build

./configure \
  --extra-cflags=-I$HOME/streamline/Blackmagic_DeckLink_SDK_10.11.4/Linux/include \
  --extra-ldflags=-L-I$HOME/streamline/Blackmagic_DeckLink_SDK_10.11.4/Linux/include \
  --extra-cflags=-I/usr/local/cuda/include/ \
  --extra-ldflags=-L/usr/local/cuda/lib64/ \
  --enable-decklink \
  --enable-gpl \
  --enable-libx264 \
  --enable-nonfree \
  --enable-openssl \
  --enable-libnpp \
  --enable-cuda-sdk \
  --enable-nvenc \
  --disable-doc \
  --diable-htmlpages

# Build ffmpeg

make

sudo make install

cd ..

rm -r -f Blackmagic* nv* NVIDIA* *bz2 *.run *.deb* *.xz*

mkdir logs www

# Build the low latency web server

go/bin/go get -d -v .

go/bin/go build

go/bin/go get -d -v .

go/bin/go build

echo "You are good to reboot now."
