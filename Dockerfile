# docker run -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/mnt --privileged -it singularity_in_docker
# $ docker build -t singularity_in_docker .
# $ docker run -v $PWD:/mnt --privileged -it singularity_in_docker
# $ docker tag singularity_in_docker nathanjmorton/singularity_in_docker
# $ docker push nathanjmorton/singularity_in_docker

# multi-stage build with golang for compiling singularity and singularity-compose
# golang for singularity
FROM golang:1.14.3-buster as singularity-builder

# python for singularity-compose (anaconda distribution has everything)
FROM continuumio/anaconda3 as singularity-compose-builder

FROM rust:1.43-buster as rust-builder

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

# set the workdir; this is where you land in the container 
WORKDIR /mnt 

# set up rust for fun
COPY --from=rust-builder /usr/local/rustup /usr/local/rustup
COPY --from=rust-builder /usr/local/cargo /usr/local/cargo

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.43.1

# rustup --version; 
# cargo --version; 
# rustc --version;

# install deno 
RUN cargo install deno

# install nvm and node
# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install base dependencies
RUN apt-get update && apt-get install -y -q --no-install-recommends \
        apt-transport-https \
        build-essential \
        ca-certificates \
        curl \
        git \
        libssl-dev \
        wget \
        nano \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/nvm
ENV NVM_DIR /usr/local/nvm 
ENV NODE_VERSION 12.16.3

# Install nvm with node and npm
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/v$NODE_VERSION/bin:$PATH

# add docker to run kubernetes 
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN apt-key fingerprint 0EBFCD88
RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
RUN apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
RUN apt-cache madison docker-ce
# RUN docker run hello-world

# install kubernetes 
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.8.1/kind-$(uname)-amd64
RUN chmod +x ./kind
RUN mv ./kind /usr/local/bin/kind

# install kubectl cli
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# install docker-compose for mist.io ce
RUN curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose
