# https://solarianprogrammer.com/2018/05/06/building-gcc-cross-compiler-raspberry-pi/

# Latest on Pi 0W at the time of writing (2022-12-14)
FROM debian:bullseye

# This should match the one on your raspi
ENV GCC_VERSION gcc-10.2.0
ENV GLIBC_VERSION glibc-2.31
ENV BINUTILS_VERSION binutils-2.35.2
ARG DEBIAN_FRONTEND=noninteractive


# Install some tools and compilers + clean up
RUN apt-get update && \
    apt-get install -y rsync git wget build-essential cmake gdb gdbserver bzip2 && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Use GCC 8 as the default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 999 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 999 \
 && update-alternatives --install /usr/bin/cc  cc  /usr/bin/gcc-10 999 \
 && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-10 999

# Add a user called `develop`
RUN useradd -ms /bin/bash develop
RUN echo "develop   ALL=(ALL:ALL) ALL" >> /etc/sudoers

WORKDIR /home/develop

# Download and extract GCC
RUN wget https://ftp.gnu.org/gnu/gcc/${GCC_VERSION}/${GCC_VERSION}.tar.gz && \
    tar xf ${GCC_VERSION}.tar.gz && \
    rm ${GCC_VERSION}.tar.gz
# Download and extract LibC
RUN wget https://ftp.gnu.org/gnu/libc/${GLIBC_VERSION}.tar.bz2 && \
    tar xjf ${GLIBC_VERSION}.tar.bz2 && \
    rm ${GLIBC_VERSION}.tar.bz2
# Download and extract BinUtils
RUN wget https://ftp.gnu.org/gnu/binutils/${BINUTILS_VERSION}.tar.bz2 && \
    tar xjf ${BINUTILS_VERSION}.tar.bz2 && \
    rm ${BINUTILS_VERSION}.tar.bz2
# Download the GCC prerequisites
RUN cd ${GCC_VERSION} && contrib/download_prerequisites && rm *.tar.*

# Build BinUtils
RUN mkdir -p /opt/cross-pi-gcc
WORKDIR /home/develop/build-binutils
RUN ../${BINUTILS_VERSION}/configure \
        --prefix=/opt/cross-pi-gcc --target=arm-linux-gnueabihf \
        --with-arch=armv6 --with-fpu=vfp --with-float=hard \
        --disable-multilib
RUN make -j$(nproc)
RUN make install

# Build the first part of GCC
WORKDIR /home/develop/build-gcc
RUN ../${GCC_VERSION}/configure \
        --prefix=/opt/cross-pi-gcc \
        --target=arm-linux-gnueabihf \
        --enable-languages=c,c++,fortran \
        --with-arch=armv6 --with-fpu=vfp --with-float=hard \
        --disable-multilib
RUN make -j$(nproc) 'LIMITS_H_TEST=true' all-gcc
RUN make install-gcc
ENV PATH=/opt/cross-pi-gcc/bin:${PATH}

# Install dependencies
RUN apt-get update && \
    apt-get install -y gawk bison python3 && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Download and install the Linux headers
WORKDIR /home/develop
RUN git clone --depth=1 https://github.com/raspberrypi/linux
WORKDIR /home/develop/linux
# Possible values for KERNEL:
#   kernel     Pi 1, Pi Zero, Pi Zero W    (32-bit)
#   kernel7    Pi 2, Pi 3                  (32-bit)
#   kernel7l   Pi 4                        (32-bit)
#   kernel8    Pi 3, Pi 4                  (64-bit)
ENV KERNEL=kernel
RUN make ARCH=arm INSTALL_HDR_PATH=/opt/cross-pi-gcc/arm-linux-gnueabihf headers_install

# Apply GLIBC patch for newer GCC
# Warning: Might not be needed for newer versions of GLIBC
WORKDIR /home/develop/${GLIBC_VERSION}
RUN wget -O glibc.patch 'https://gist.githubusercontent.com/jareddantis/e3695eed5c3afc1776381654b4bbb33b/raw/e21e93fd00d622a2c63dd6f86f8c83152e727859/glibc-2.31-gcc-10.patch' && \
    patch -p1 < glibc.patch && \
    rm glibc.patch

# Build GLIBC
WORKDIR /home/develop/build-glibc
RUN ../${GLIBC_VERSION}/configure \
        --prefix=/opt/cross-pi-gcc/arm-linux-gnueabihf \
        --build=$MACHTYPE --host=arm-linux-gnueabihf --target=arm-linux-gnueabihf \
        --with-arch=armv6 --with-fpu=vfp --with-float=hard \
        --with-headers=/opt/cross-pi-gcc/arm-linux-gnueabihf/include \
        --disable-multilib libc_cv_forced_unwind=yes
RUN make install-bootstrap-headers=yes install-headers
RUN make -j8 csu/subdir_lib
RUN install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/arm-linux-gnueabihf/lib
RUN arm-linux-gnueabihf-gcc -nostdlib -nostartfiles -shared -x c /dev/null \
        -o /opt/cross-pi-gcc/arm-linux-gnueabihf/lib/libc.so
RUN touch /opt/cross-pi-gcc/arm-linux-gnueabihf/include/gnu/stubs.h

# Continue building GCC
WORKDIR /home/develop/build-gcc
RUN make -j$(nproc) all-target-libgcc
RUN make install-target-libgcc

# Finish building GLIBC
WORKDIR /home/develop/build-glibc
RUN make -j$(nproc)
RUN make install

# Finish building GCC
WORKDIR /home/develop/build-gcc
RUN make -j$(nproc)
RUN make install

#RUN cp -r /opt/cross-pi-gcc /opt/cross-pi-${GCC_VERSION}
#
#WORKDIR /home/develop/build-gcc9
#RUN ../gcc-9.2.0/configure \
#        --prefix=/opt/cross-pi-gcc \
#        --target=arm-linux-gnueabihf \
#        --enable-languages=c,c++,fortran \
#        --with-arch=armv6 --with-fpu=vfp --with-float=hard \
#        --disable-multilib
#RUN make -j$(nproc) all-gcc
#RUN make install-gcc

USER develop
