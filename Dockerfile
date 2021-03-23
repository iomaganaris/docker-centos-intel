FROM centos:8
RUN su -
RUN echo $'[oneAPI] \n\
name=Intel(R) oneAPI repository\n\
baseurl=https://yum.repos.intel.com/oneapi\n\
enabled=1\n\
gpgcheck=1\n\
repo_gpgcheck=1\n\
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB' > /tmp/oneAPI.repo
RUN mv /tmp/oneAPI.repo /etc/yum.repos.d
RUN yum upgrade -y
RUN yum install -y which
# Install GCC 8 compiler
RUN dnf group install -y "Development Tools"
RUN dnf install -y redhat-rpm-config mpich-devel
ENV PATH=${PATH}:/usr/lib64/mpich/bin
# Install INTEL OneAPI
#RUN yum install -y intel-basekit #intel-hpckit
#RUN yum --disablerepo="*" --enablerepo="oneAPI" list available
#RUN yum install -y intel-oneapi-common-licensing-2021.1.1-2021.1.1-60.noarch intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-2021.1.1.x86_64 intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-runtime-2021.1.1.x86_64 intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-common-2021.1.1.noarch 
#RUN yum install -y intel-basekit
#RUN yum install -y intel-hpckit
RUN yum install -y intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic
RUN source /opt/intel/oneapi/setvars.sh && \
gcc --version && g++ --version && \
icc --version && icpc --version && \
mpicc --version
# Install all needed packages for NEURON
RUN yum install -y wget git ncurses-devel python3-devel
# Install cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3.tar.gz && \
tar -zxvf cmake-3.17.3.tar.gz && \
cd cmake-3.17.3 && \
yum install -y openssl-devel && \
./bootstrap --prefix=/usr/local && \
make -j8 && \
make install
# Install mpich
#RUN wget https://www.mpich.org/static/tarballs/3.4.1/mpich-3.4.1.tar.gz && \
#tar xzf mpich-3.4.1.tar.gz && \
#cd mpich-3.4.1 && \
#./configure --prefix=/mpich-install --with-device=ch4:ofi && \
#make -j8 && \
#make install
# Clone NEURON
RUN git clone https://github.com/neuronsimulator/nrn.git
# Install NEURON and CoreNEURON with INTEL compiler
RUN source /opt/intel/oneapi/setvars.sh && \
export PATH=/mpich-install/bin:$PATH && \
cd nrn && \
mkdir build && \
cd build && \
export CC=$(which icc) && \
export CXX=$(which icpc) && \
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DNRN_ENABLE_CORENEURON=ON -DNRN_ENABLE_INTERVIEWS=OFF -DNRN_ENABLE_RX3D=OFF && \ 
#-DMPI_C_COMPILER=/mpich-install/bin/mpicc -DMPI_CXX_COMPILER=/mpich-install/bin/mpicxx -DMPI_CXX_HEADER_DIR=/mpich-install/include && \
make -j8 && \
make install
# Clone ringtest
RUN git clone https://github.com/neuronsimulator/ringtest.git
# Create special for ringtest
RUN source /opt/intel/oneapi/setvars.sh && \
cd ringtest && \
/nrn/build/install/bin/nrnivmodl -coreneuron mod
# Run ringtest
RUN source /opt/intel/oneapi/setvars.sh && \
export PYTHONPATH=$PYTHONPATH:/nrn/build/install/lib/python:/nrn/build/install/lib64/python && \
cd ringtest && \
mpirun -n 2 ./x86_64/special -mpi -python ringtest.py
