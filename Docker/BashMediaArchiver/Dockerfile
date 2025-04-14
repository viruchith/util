FROM alpine:3.21
# update apk
RUN apk update
# Install dependencies
RUN apk add --no-cache \
    bash \
    file \
    ffmpeg=6.1.2-r1 \
    imagemagick=7.1.1.41-r0 \
    nano \
    tzdata \
    zip
# switch to bash shell
SHELL ["/bin/bash", "-c"]
# set timezone to IST
RUN cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
RUN echo "Asia/Kolkata" > /etc/timezone
# copy files
RUN wget "https://raw.githubusercontent.com/viruchith/util/refs/heads/main/Scripts/Bash/archiver.sh"
# make executable
RUN chmod +x /archiver.sh
# create input and output directories
RUN mkdir -p /input-media
RUN mkdir -p /output-media
