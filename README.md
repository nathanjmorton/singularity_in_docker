# Ubuntu:18.04 with Singularity

```
$ docker build -t singularity_in_docker .
$ docker run -v $PWD:/mnt --privileged -it singularity_in_docker
```
