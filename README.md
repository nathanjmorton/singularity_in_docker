# Ubuntu:18.04 with singularity and singularity-compose (includes Golang Anaconda Python Rust Deno and nvm/Node 12 LTS as well as Docker and Kubernetes) 

## Commands to build and get inside the container 

```
$ docker build -t singularity_in_docker .
$ docker run -v $PWD:/mnt --privileged -it singularity_in_docker
```

## Commands inside the container

```
$ singularity --version
$ singularity-compose --version
$ go version
$ python -V
$ rustup --version
$ cargo --version 
$ rustc --version
$ deno --version
$ nvm --version
$ node -v
```

