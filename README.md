# docker-centos-intel
Dockerfile that installs INTEL compilers and NEURON using CentOS 8

## Instructions
Before building the image make sure to copy M1 repo in the same folder as the docker file

```
git clone https://github.com/iomaganaris/M1.git
cd M1
git checkout magkanar/coreneuron_mod2c
cd ..
tar -czvf M1.tar.gz M1
docker build -t intel_centos8:2.0 .
```
