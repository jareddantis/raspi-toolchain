# Raspberry Pi Toolchains

Repository for Raspberry Pi cross compiler using the new GCC10 for Raspbian Buster.
This supports all new Raspberry PIs (ARMv7), and the older ones, including Zero, A, B, B+ (ARMv6) with newer GCCs.

You can probably also use this repository for any other ARMv6 and ARMv7 devices.

By default, newer GCC versions do not create correct binaries for ARMv6. Even though you pass the correct `-mcpu=` flag to gcc,
it will create startup code for the newer ARMv7 architecture. Running them on your RasPI Zero will cause an "Illegal Instruction" exception.

See also:
https://stackoverflow.com/questions/55465118/gcc-8-cross-compiler-outputs-armv7-executable-instead-of-armv6

This work is based on the great @tttapa and the Docker file here:
https://gist.github.com/tttapa/534fb671c5f6cced0e1722d3e4aec987

A corresponding Blog post can be found here:
https://solarianprogrammer.com/2018/05/06/building-gcc-cross-compiler-raspberry-pi/

A similar project can also be found here, but it only includes the compiled toolchains, which did not work out of the box for me:
https://sourceforge.net/projects/raspberry-pi-cross-compilers

### Build the toolchain from source

To build the toolchain, just clone this repository and then call:

```bash
docker build -f Dockerfile --network=host -t gcc-rpi-zero .
```

This will take some time since it builds a docker container with the gcc compiler.

To run the docker container, use

```bash
docker run -it gcc-rpi-zero bash
```

### Install from source after building

To get the toolchain from the docker container into your host, just copy the files:

```bash
CONTAINER_ID=$(docker create gcc-rpi-zero)
sudo docker cp $CONTAINER_ID:/opt/cross-pi-gcc /opt/cross-pi-gcc
```

It's important that you put the files into the same directory, since the toolchain has the paths hardcoded inside.

After that feel free to delete the docker container.

## Test the toolchain

This repository contains a simple hello world example.

To cross-compile any executable after you installed the toolchain on your host,
you need to get the current libraries and include files from your raspberry:

```bash
# Use the correct IP address here
rsync -vR --progress -rl --delete-after --safe-links pi@192.168.1.PI:/{lib,usr,etc/ld.so.conf.d,opt/vc/lib} $HOME/rpi/rootfs
```

Then call the script `build_hello_world.sh`.

To test the executable, copy it to your raspi:

```bash
scp build/hello pi@192.168.1.PI:/home/pi/hello
ssh pi@192.168.1.PI
./hello
```
