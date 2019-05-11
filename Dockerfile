FROM ubuntu:16.04

RUN apt-get update -y && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y tzdata && \
    ln -fs /usr/share/zoneinfo/America/Chicago /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt-get install -y libvtk6-dev libvtk6.2 gsl-bin libgsl0-dev \
         liblapack3 liblapack-dev liblapacke-dev libopenblas-dev libpq-dev \
         libpqxx-dev libpq5 git wget libproj-dev && \
    find /usr/lib -name libpq.so -exec ln -s {} /usr/lib/libpq.so ';'

RUN export version=3.14 && \
    export build=3 && \
    cd /tmp && \
    wget https://cmake.org/files/v$version/cmake-$version.$build.tar.gz && \
    tar -xzvf cmake-$version.$build.tar.gz && \
    cd cmake-$version.$build/ && \
    ./bootstrap && \
    make -j4 && \
    make install

 RUN export NUM_THREADS=4 && \
    export ITK_VERSION=v4.9.0 && \
    export ITK_SOURCE_DIR=/opt/itk-${ITK_VERSION} && \
    export ITK_BUILD_DIR=${ITK_SOURCE_DIR}-build && \
    export ITK_DIR=${ITK_BUILD_DIR} && \
    git clone --depth 1 --branch ${ITK_VERSION} \
        https://github.com/InsightSoftwareConsortium/ITK.git ${ITK_SOURCE_DIR} && \
    mkdir -p ${ITK_BUILD_DIR} && \
    cd ${ITK_BUILD_DIR} && \
    cmake ${ITK_SOURCE_DIR} -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
        -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -DModule_ITKReview=OFF && \
    make --jobs=$NUM_THREADS --keep-going && \
    make install && \
    ldconfig -v

RUN cd /opt && \
    export ITK_DIR=/opt/itk-v4.9.0-build && \
    git clone https://github.com/Slicer/SlicerExecutionModel.git && \ 
    mkdir -p /opt/SlicerExecutionModel-build && \
    cd /opt/SlicerExecutionModel-build && \
    cmake /opt/SlicerExecutionModel && \
    make -j ${NUM_THREADS}

COPY . /opt/dmri-tool
RUN mkdir -p /opt/dmritool-build && \
    cd /opt/dmritool-build && \
    export OPENBLAS_NUM_THREADS=1 && \
    export OMP_NUM_THREADS=1 && \
    cmake -DGenerateCLP_DIR=/opt/SlicerExecutionModel-build/GenerateCLP \
          -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DDMRITOOL_USE_MKL=OFF \
          -DDMRITOOL_USE_FASTLAPACK=ON -DDMRITOOL_USE_OPENMP=ON \
          -DBUILD_QT_APPLICATIONS=OFF -DDMRITOOL_WRAP_MATLAB=OFF \
          /opt/dmri-tool && \
    make -j 2 && \
    make install && \
    echo "export PATH=$PATH:/usr/local/dmritool/bin" >> /root/.bashrc