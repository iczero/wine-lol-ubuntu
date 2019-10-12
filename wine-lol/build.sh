#!/bin/bash
# Build wine-lol
# dependencies: autoconf autotools-dev bison flex fontforge gawk gettext ffmpeg samba libasound2-dev:i386 libavcodec-dev:i386 libcapi20-dev:i386 libdbus-1-dev:i386 libfontconfig1-dev:i386 libfreetype6-dev:i386 libgif-dev:i386 libgl1-mesa-dev:i386 libglu1-mesa-dev:i386 libgphoto2-dev:i386 libgsm1-dev:i386 libice-dev:i386 libjpeg-dev:i386 libkrb5-dev:i386 liblcms2-dev:i386 libldap2-dev:i386 libmpg123-dev:i386 libopenal-dev:i386 libosmesa6-dev:i386 libpng-dev:i386 libpulse-dev:i386 libsane-dev:i386 libssl-dev:i386 libudev-dev:i386 libv4l-dev:i386 libva-dev:i386 libvulkan-dev:i386 libx11-dev:i386 libxcomposite-dev:i386 libxcursor-dev:i386 libxext-dev:i386 libxi-dev:i386 libxrandr-dev:i386 libxrender-dev:i386 libxt-dev:i386 libgnutls28-dev:i386 libsdl2-dev:i386 libcups2-dev:i386 libtiff-dev:i386 libxml2-dev:i386 libxslt1-dev:i386 libicu-dev:i386 libgtk-3-dev:i386 libncurses-dev:i386 libvkd3d-dev:i386 opencl-c-headers
# NOTE: if something complains about /etc/gtk-3/settings.ini being bork,
# simply move it somewhere else (like settings.ini-backup) and run apt install -f
set -e

version=4.17

_pkgbasever=${version/rc/-rc}
basedir=$PWD

if [[ ! -f wine-${_pkgbasever}.tar.xz ]]; then
    # fetch wine sources
    echo "fetching sources..."
    wget -O wine-${_pkgbasever}.tar.xz https://dl.winehq.org/wine/source/4.x/wine-${_pkgbasever}.tar.xz
    wget -O wine-staging-v${_pkgbasever}.tar.gz https://github.com/wine-staging/wine-staging/archive/v${_pkgbasever}.tar.gz

    tar xvf wine-${_pkgbasever}.tar.xz
    tar xvf wine-staging-v${_pkgbasever}.tar.gz

    # apply patches
    echo "applying patches"
    mv wine-$_pkgbasever wine
    # wine-staging
    pushd wine-staging-$_pkgbasever/patches
    ./patchinstall.sh DESTDIR="$basedir/wine" --all
    popd
    # league patches
    pushd wine
    patch -p1 -i ../wine-lol-poc1-wine.patch
    patch -p1 -i ../wine-lol-patch-stub.patch
    patch -p1 -i ../wine-lol-poc2-wine.patch
    popd
fi

if [[ ! -d wine-32-build ]]; then
    # compile
    echo "compile wine32"
    mkdir wine-32-build

    # point things to wine-lol-glibc
    _RPATH="-rpath=/opt/wine-lol/lib32"
    _LINKER="-dynamic-linker=/opt/wine-lol/lib32/ld-linux.so.2"
    # hackity hack hack
    # we need LDFLAGS to be after -lpthread so it finds the one we have
    # in wine-lol-glibc but configure doesn't do that when verifying the
    # existence of libraries
    # side effect: literally everything is linked to libpthread
    _LOAD_BEFORE="-lpthread"
    export LDFLAGS="${LDFLAGS:--Wl},$_LOAD_BEFORE,$_RPATH,$_LINKER"

    # 32-bit
    export CFLAGS="-m32 $CFLAGS"

    pushd wine-32-build
    ../wine/configure \
        --prefix=/opt/wine-lol \
        --with-x \
        --with-xattr \
        --libdir=/opt/wine-lol/lib32

    make depend LDRPATH_INSTALL="-Wl,$_RPATH,$_LINKER"
    make -j4
    popd
fi

# packaging
echo "creating archive"
mkdir -p dist
pkgdir="$basedir/dist"
cd "$basedir/wine-32-build"
make prefix="$pkgdir/opt/wine-lol" \
     libdir="$pkgdir/opt/wine-lol/lib32" \
     dlldir="$pkgdir/opt/wine-lol/lib32/wine" \
     install

install -d "$pkgdir"/etc/fonts/conf.{avail,d}
install -m644 "$basedir/30-win32-aliases.conf" "$pkgdir"/etc/fonts/conf.avail/30-wine-lol-win32-aliases.conf
ln -s ../conf.avail/30-wine-lol-win32-aliases.conf "$pkgdir"/etc/fonts/conf.d/30-wine-lol-win32-aliases.conf

cd "$pkgdir"
tar cvzf "$basedir/wine-lol.tar.gz" .

