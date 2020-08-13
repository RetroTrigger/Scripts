#!/bin/bash

if [ "$1" == "" ]; then
    echo "Usage: $0 1.8.0"
    echo "to download and install MakeMKV 1.8.0"

# Collect sudo credentials
sudo -v

VER="$1"
TMPDIR=`mktemp -d`

# Install prerequisites
sudo apt-get install build-essential pkg-config libc6-dev libssl-dev libexpat1-dev libavcodec-dev libgl1-mesa-dev libqt4-dev

# Install this version of MakeMKV
pushd $TMPDIR

for PKG in bin oss; do
    PKGDIR="makemkv-$PKG-$VER"
    PKGFILE="$PKGDIR.tar.gz"

    wget "http://www.makemkv.com/download/$PKGFILE"
    tar xzf $PKGFILE

    pushd $PKGDIR
    # pre-1.8.6 version
    if [ -e "./makefile.linux" ]; then
        make -f makefile.linux
        sudo make -f makefile.linux install

    # post-1.8.6 version
    else
        if [ -e "./configure" ]; then
            ./configure
        fi
        make
        sudo make install
    fi

    popd
done

popd

# Remove temporary directory
if [ -e "$TMPDIR" ]; then rm -rf $TMPDIR;

fi
