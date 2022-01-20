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

# Install GCC 8 compiler
RUN dnf group install -y "Development Tools"

# Install INTEL OneAPI Compilers (with classic ones)
RUN yum install -y intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic intel-oneapi-mpi-devel-2021.5.0

# Test compilers and mpi
RUN source /opt/intel/oneapi/setvars.sh && \
gcc --version && g++ --version && \
icc --version && icpc --version && \
mpicc -v && mpicxx -v && mpiicc -v && mpiicpc -v

# Install all needed packages for NEURON
RUN yum install -y wget git ncurses-devel python3-devel which readline-devel libjpeg-devel zlib-devel

# Install NEURON and NMODL dependencies
RUN pip3 install cmake setuptools scikit-build Jinja2 PyYAML pytest 'sympy>=1.3,<1.9'

# Clone NEURON
RUN git clone --recursive https://github.com/neuronsimulator/nrn.git

# Install NEURON and CoreNEURON with INTEL compiler
RUN source /opt/intel/oneapi/setvars.sh && \
cd nrn && \
mkdir build && \
cd build && \
export CC=$(which icc) && \
export CXX=$(which icpc) && \
cmake .. \
    -DNRN_ENABLE_INTERVIEWS=OFF \
    -DNRN_ENABLE_RX3D=OFF \
    -DNRN_ENABLE_MPI=ON \
    -DCORENRN_ENABLE_OPENMP=OFF \
    -DNRN_ENABLE_CORENEURON=ON \
    -DCORENRN_ENABLE_GPU=OFF \
    -DCORENRN_ENABLE_NMODL=ON \
    -DCORENRN_NMODL_FLAGS=" sympy --analytic" \
    -DNRN_ENABLE_PYTHON=ON \
    -DPYTHON_EXECUTABLE=$(which python3) \
    -DNRN_ENABLE_TESTS=OFF \
    -DCORENRN_ENABLE_UNIT_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX=./install \
    -DCMAKE_CXX_COMPILER=$(which icpc) \
    -DCMAKE_C_COMPILER=$(which icc) && \
cmake --build . --parallel 4 --target install

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
RUN git clone https://github.com/suny-downstate-medical-center/netpyne.git

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
sed -i "s#cfg.coreneuron = .*#cfg.coreneuron = True#g" cfg.py && \
mpirun -n 8 ./x86_64/special -mpi -python init.py
