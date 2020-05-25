# $ docker build -t singularity_in_docker .
# $ docker run -v $PWD:/mnt --privileged -it singularity_in_docker

# multi-stage build with golang for compiling singularity
FROM golang:1.14.3-buster as builder

# use ubuntu as the base image OS runtime for singularity operations
FROM ubuntu:18.04 
ENV DEBIAN_FRONTEND noninteractive
# copy the go binary and config files from the default go image and put the binary in ubuntu's path for the shell to interpret commands 
COPY --from=builder /go /go
COPY --from=builder /usr/local/go /usr/local/go
ENV GOLANG_VERSION 1.14.3
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH


# RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
# WORKDIR $GOPATH

# install singularity's dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    uuid-dev \
    libgpgme11-dev \
    squashfs-tools \
    libseccomp-dev \
    wget \
    pkg-config \
    git \
    cryptsetup

# make the singularity build directory, download the github repo for latest distro, unzip, configure build & install with the go commands 
# note: this code is adapted from docker2singularity Dockerfile which specifies the /usr/local/var/singularity/mnt directory probably for some operations related to its task (creating a sif file in docker) and is not needed; i have included it to make minimal changes for prototyping a singularity in docker image
RUN mkdir -p $GOPATH/src/github.com/sylabs && \
    cd $GOPATH/src/github.com/sylabs && \
    wget -qO- https://github.com/sylabs/singularity/releases/download/v3.5.3/singularity-3.5.3.tar.gz | \
    tar xzv && \
    cd singularity && \
    ./mconfig -p /usr/local/singularity && \
    make -C builddir && \
    make -C builddir install

RUN mkdir -p /etc/localtime

# put singularity's binary on ubuntu's shell path to interpret its commands
ENV PATH="/usr/local/singularity/bin:$PATH"
WORKDIR /mnt 


