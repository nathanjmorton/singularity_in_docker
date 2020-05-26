# $ docker build -t singularity_in_docker .
# $ docker run -v $PWD:/mnt --privileged -it singularity_in_docker

# multi-stage build with golang for compiling singularity and singularity-compose
# golang for singularity
FROM golang:1.14.3-buster as singularity-builder

# python for singularity-compose (anaconda distribution has everything)
FROM continuumio/anaconda3 as singularity-compose-builder

# use ubuntu as the base image OS runtime for singularity operations
FROM ubuntu:18.04 
ENV DEBIAN_FRONTEND noninteractive

# setup the go binary to compile singularity from source
# copy the go binary and config files from the default go image and put the binary in ubuntu's path for the shell to interpret commands 
COPY --from=singularity-builder /go /go
COPY --from=singularity-builder /usr/local/go /usr/local/go
ENV GOLANG_VERSION 1.14.3
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

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
RUN mkdir -p $GOPATH/src/github.com/sylabs && \
    cd $GOPATH/src/github.com/sylabs && \
    wget -qO- https://github.com/sylabs/singularity/releases/download/v3.5.3/singularity-3.5.3.tar.gz | \
    tar xzv && \
    cd singularity && \
    ./mconfig -p /usr/local/singularity && \
    make -C builddir && \
    make -C builddir install

# put singularity's binary on ubuntu's shell path to interpret its commands
ENV PATH="/usr/local/singularity/bin:$PATH"

# singularity uses this directory to complete its build / run operations on ubuntu
RUN mkdir -p /etc/localtime

# setup the python binary to compile singularity-compose 
COPY --from=singularity-compose-builder /opt/conda /opt/conda

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH

RUN apt-get install -y curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb && \
    apt-get clean

#install singularity-compose with pip
RUN pip install singularity-compose

ENTRYPOINT [ "/usr/bin/tini", "--" ]
CMD [ "/bin/bash" ]


# set the workdir; this is where you land in the container 
WORKDIR /mnt 


