#!/bin/bash

sudo apt-get -y install \
    openssh-server \
    screen \
    pkg-config \
    nasm \
    yasm \
    unzip \
    curl \
    axel \
    autoconf \
    automake \
    build-essential \
    cmake \
    htop \
    git-core \
    libass-dev \
    libgnutls28-dev \
    libsdl2-dev \
    libtool \
    libvdpau-dev \
    libssl-dev \
    dkms \
    libssh-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    libegl1-mesa \
    meson \
    ninja-build \
    texinfo \
    libfdk-aac-dev \
    libx264-dev \
    libopus-dev \
    libunistring-dev \
    libaom-dev \
    nvidia-driver-470 \
    nvidia-cuda-toolkit

mkdir ~/streamline2
cd ~/streamline2

#download and install Black Magic SDK
rm -r bmdsdk/
axel --no-clobber  https://streamlinevideo.s3.us-west-1.amazonaws.com/Blackmagic_DeckLink_SDK_12.1.zip
unzip  -n  Blackmagic_DeckLink_SDK_12.1.zip
mv 'Blackmagic DeckLink SDK 12.1' bmdsdk

#download and install Black Magic Desktop drivers and software
rm -r bmddv/
axel --no-clobber https://streamlinevideo.s3.us-west-1.amazonaws.com/Blackmagic_Desktop_Video_Linux_12.1.tar
tar -xf Blackmagic_Desktop_Video_Linux_12.1.tar
mv Blackmagic_Desktop_Video_Linux_12.1 bmddv
sudo dpkg -i  ~/streamline2/bmddv/deb/x86_64/*

#create working directory
mkdir ~/streamline2/ffmpeg_sources

#install svt-av1
cd ~/streamline2/ffmpeg_sources
git -C SVT-AV1 pull 2> /dev/null || git clone https://github.com/AOMediaCodec/SVT-AV1.git
mkdir -p SVT-AV1/build
cd SVT-AV1/build
PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DCMAKE_BUILD_TYPE=Release -DBUILD_DEC=OFF -DBUILD_SHARED_LIBS=OFF ..
PATH="$HOME/bin:$PATH" make -j 128

make install
#install CUDA SDK
#echo "Installing CUDA and the latest driver repositories from repositories"
#wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
#sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
#wget https://developer.download.nvidia.com/compute/cuda/11.4.2/local_installers/cuda-repo-ubuntu2004-11-4-local_11.4.2-470.57.02-1_amd64.deb
#sudo apt-key add /var/cuda-repo-ubuntu2004-11-4-local/7fa2af80.pub
#sudo dpkg -i cuda-repo-ubuntu2004-11-4-local_11.4.2-470.57.02-1_amd64.deb

#install NVIDIA  SDK
echo "Installing the NVIDIA NVENC SDK."
cd ~/streamline2
git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
cd nv-codec-headers
make -j 128
sudo make install
cd ~/streamline2

#compile ffmpeg
echo "Compiling ffmpeg"
cd ~/streamline2
git clone https://github.com/FFmpeg/FFmpeg -b master
cd FFmpeg

./configure \
  --extra-cflags="-I$HOME/streamline2/bmdsdk/Linux/include" \
  --extra-ldflags="-L-I$HOME/streamline2/bmdsdk/Linux/include" \
  --extra-cflags="-I$HOME/streamline2/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/streamline2/ffmpeg_build/lib" \
  --extra-cflags="-I/usr/local/cuda/include/" \
  --extra-ldflags="-L/usr/local/cuda/lib64/" \
  --extra-cflags=-I/usr/local/include/ \
  --extra-ldflags=-L/usr/local/include/ \
  --enable-cuda-nvcc \
  --enable-cuvid \
  --enable-libnpp \
  --enable-gpl \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libopus \
  --enable-libx264 \
  --enable-nonfree \
  --enable-nvenc \
  --enable-decklink \
  --enable-libsvtav1

make -j 128
sudo make install
make distclean
hash -r

echo "Complete!"
