FROM centos:8

# Avoid using sudo in the rest of the file
RUN su -

# Needed to install the INTEL OneAPI packages
RUN echo $'[oneAPI] \n\
name=Intel(R) oneAPI repository\n\
baseurl=https://yum.repos.intel.com/oneapi\n\
enabled=1\n\
gpgcheck=1\n\
repo_gpgcheck=1\n\
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB' > /tmp/oneAPI.repo
RUN mv /tmp/oneAPI.repo /etc/yum.repos.d

# Upgrade default packages
RUN yum upgrade -y

# Install GCC 8 compiler and mpich
RUN dnf group install -y "Development Tools"
RUN dnf install -y redhat-rpm-config mpich-devel
ENV PATH=${PATH}:/usr/lib64/mpich/bin

# Install INTEL OneAPI Compilers (with classic ones)
RUN yum install -y intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic

# Test compilers and mpi
RUN source /opt/intel/oneapi/setvars.sh && \
gcc --version && g++ --version && \
icc --version && icpc --version && \
mpicc --version

# Install all needed packages for NEURON
RUN yum install -y wget git ncurses-devel python3-devel which

# Install cmake
RUN pip3 install cmake

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

# Clone netpyne
RUN git clone https://github.com/iomaganaris/netpyne.git && \
cd netpyne && \
git checkout magkanar/coreneuron_rebase

# install netpyne requirements
RUN cd netpyne && \
pip3 install -e .

# Copy M1 from host
ADD M1.tar.gz /

# Build special for M1
RUN source /opt/intel/oneapi/setvars.sh && \
cd M1/sim && \
/nrn/build/install/bin/nrnivmodl -coreneuron ../mod

# Run simulation
RUN source /opt/intel/oneapi/setvars.sh && \
export PYTHONPATH=/netpyne:/nrn/build/install/lib/python:/nrn/build/install/lib64/python:$PYTHONPATH && \
cd M1/sim && \
mpirun -n 8 ./x86_64/special -mpi -python init.py
