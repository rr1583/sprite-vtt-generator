FROM golang:1.20.1-alpine as base_stage

RUN apk add --no-cache git

ENV FFMPEG_VERSION=4.3.5
#ENV LD_LIBRARY_PATH=/tmp/ffmpeg/lib/
#ENV PKG_CONFIG_PATH=/tmp/ffmpeg/lib/pkgconfig/

WORKDIR /tmp/ffmpeg

# install ffmpeg
RUN set -e && \
  apk add --update build-base curl nasm tar bzip2 zlib-dev openssl-dev yasm-dev lame-dev libogg-dev x264-dev libvpx-dev libvorbis-dev x265-dev freetype-dev libass-dev libwebp-dev rtmpdump-dev libtheora-dev opus-dev && \
  DIR=$(mktemp -d) && cd ${DIR} && \
  curl -L -s https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz | tar zxvf - -C . && \
  cd ffmpeg-${FFMPEG_VERSION} && \
  ./configure --enable-version3 --enable-gpl --enable-nonfree --enable-small --enable-libmp3lame --enable-libx264 --enable-libx265 --enable-libvpx --enable-libtheora --enable-libvorbis --enable-libopus --enable-libass --enable-libwebp --enable-librtmp --enable-postproc --enable-swresample --enable-libfreetype --enable-openssl --disable-debug && \
  make && \
  make install && \
  make distclean && \
  apk del build-base curl tar bzip2 nasm && \
  rm -rf /var/cache/apk/* ${DIR}

FROM base_stage as go_stage

RUN apk add --no-cache imagemagick build-base

WORKDIR /go

# install the mt tool
# Prior versions cloned a specific commit of mutschler/mt, but that commit was
# removed upstream. Installing via `go install` ensures the build succeeds.
RUN go install github.com/mutschler/mt/v2@v2.0.0
