#!/bin/bash

# update the OS

sudo apt-get -y update

sudo apt-get -y upgrade

# Download capture card drivers and SDK

wget https://hellavision.s3-us-west-2.amazonaws.com/Blackmagic_Desktop_Video_Linux_10.9.10.tar.gz

wget https://hellavision.s3-us-west-2.amazonaws.com/Blackmagic_DeckLink_SDK_10.9.10.zip

# Install dependencies

sudo apt-get install -y --allow-unauthenticated nasm autoconf htop \
automake build-essential libass-dev curl zlib1g-dev openssh-server \
autoconf libfreetype6-dev texinfo nvidia-384 zlibc \
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

unzip -n Blackmagic_DeckLink_SDK_10.9.10.zip

mv -n "Blackmagic DeckLink SDK 10.9.10/"  Blackmagic_DeckLink_SDK_10.9.10

tar -xvf Blackmagic_Desktop_Video_Linux_10.9.10.tar.gz

sudo dpkg -i Blackmagic_Desktop_Video_Linux_10.9.10/deb/x86_64/*

sudo cp -r Blackmagic_DeckLink_SDK_10.9.10/Examples/Linux/bin/x86_64/* /bin/

# Download and compile FFmpeg

rm -r -f ~/streamline/FFmpeg/

git clone https://github.com/FFmpeg/FFmpeg.git -b master

cd FFmpeg

# Check out a version of FFmpeg without a certain HLS bug

git checkout f5f2209d689cd17f4bce7ce5c4f0b1634befc785

# Create patch for FFmpeg for an HTTP bug that affects persistent connections over time.

cat > patch.patch << _PATCH_
---
 libavformat/http.c | 13 +++++++++++++
 1 file changed, 13 insertions(+)

diff --git a/libavformat/http.c b/libavformat/http.c
index 344fd60..a93fa54 100644
--- a/libavformat/http.c
+++ b/libavformat/http.c
@@ -1611,6 +1611,18 @@ static int http_write(URLContext *h, const uint8_t *buf, int size)
     return size;
 }

+static int http_read_response(URLContext *h) {
+    HTTPContext *s = h->priv_data;
+    char buf[1024];
+    int ret;
+
+    /* dummy read in nonblocking mode to clear the receive buffer */
+    s->hd->flags |= AVIO_FLAG_NONBLOCK;
+    ret = ffurl_read(s->hd, buf, sizeof(buf));
+    s->hd->flags &= ~AVIO_FLAG_NONBLOCK;
+    return ret;
+}
+
 static int http_shutdown(URLContext *h, int flags)
 {
     int ret = 0;
@@ -1622,6 +1634,7 @@ static int http_shutdown(URLContext *h, int flags)
         ((flags & AVIO_FLAG_READ) && s->chunked_post && s->listen)) {
         ret = ffurl_write(s->hd, footer, sizeof(footer) - 1);
         ret = ret > 0 ? 0 : ret;
+        http_read_response(h);
         s->end_chunked_post = 1;
     }

--
1.9.1
_PATCH_

# Run patch for FFmpeg

patch -p1 < patch.patch

# Configure FFmpeg build

./configure \
  --extra-cflags=-I$HOME/streamline/Blackmagic_DeckLink_SDK_10.9.10/Linux/include \
  --extra-ldflags=-L-I$HOME/streamline/Blackmagic_DeckLink_SDK_10.9.10/Linux/include \
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

rm -r -f *.zip *.deb *.tar FFmpeg*

rm -r -f nv-codec-headers *Blackmagic*

echo "You are ready to reboot."
