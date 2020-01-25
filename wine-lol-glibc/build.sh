#!/bin/bash
# build wine-lol-glibc on ubuntu
# derived from https://github.com/M-Reimer/wine-lol-glibc
# build dependencies: bison gcc-multilib
set -e

parallel=4
patch_files=(
    bz20338.patch
    file-truncated-while-reading-soname-after-patchelf.patch
    wine-lol-poc1-glibc.patch
)
configure_flags=(
    --prefix=/opt/wine-lol
    --sysconfdir=/etc
    --datarootdir=/usr/share
    --with-headers=/usr/include
    --with-bugurl=https://bugs.archlinux.org/
    --enable-add-ons
    --enable-bind-now
    --enable-lock-elision
    --enable-multi-arch
    --enable-stack-protector=strong
    --enable-stackguard-randomization
    --enable-static-pie
    --disable-profile
    --disable-werror
    --host=i686-pc-linux-gnu
    --libdir=/opt/wine-lol/lib32
    --libexecdir=/opt/wine-lol/lib32
    --enable-cet
)
version=2.30
basedir=$PWD

# fetch glibc sources
echo "getting sources for glibc"
tarball="glibc-${version}.tar.xz"
if [[ ! -f "$tarball" ]]; then
    wget "https://ftp.gnu.org/gnu/glibc/${tarball}"
    tar xvf "$tarball"
    ln -s glibc-${version} glibc

    # apply patches
    pushd glibc
    for patch in ${patch_files[@]}; do
        echo "Applying patch $patch"
        patch -p1 -N -i $basedir/$patch
    done
    popd
fi

# compile
echo "compiling glibc"
mkdir -p lib32-glibc-build
pushd lib32-glibc-build
export CC="gcc -m32 -mstackrealign"
export CXX="g++ -m32 -mstackrealign"

echo "slibdir=/opt/wine-lol/lib32" >> configparms
echo "rtlddir=/opt/wine-lol/lib32" >> configparms
echo "sbindir=/opt/wine-lol/bin" >> configparms
echo "rootsbindir=/opt/wine-lol/bin" >> configparms

# remove fortify for building libraries
#CPPFLAGS=${CPPFLAGS/-D_FORTIFY_SOURCE=2/}
#CFLAGS=${CFLAGS/-fno-plt/}
#CXXFLAGS=${CXXFLAGS/-fno-plt/}

"$basedir/glibc/configure" ${configure_flags[@]}

# build libraries with fortify disabled
#echo "build-programs=no" >> configparms
#make -j$parallel

# re-enable fortify for programs
#sed -i "/build-programs=/s#no#yes#" configparms

#echo "CC += -D_FORTIFY_SOURCE=2" >> configparms
#echo "CXX += -D_FORTIFY_SOURCE=2" >> configparms
make -j$parallel

# stuff into package
echo "making archive"
pkgdir=$basedir/dist
mkdir -p $pkgdir

make install_root="$pkgdir" install
popd

ln -s /usr/lib/locale "$pkgdir/opt/wine-lol/lib32/locale"

# strip symbols for smaller files
find "$pkgdir"/opt/wine-lol/bin -type f -executable -exec strip $STRIP_BINARIES {} + 2> /dev/null || true
find "$pkgdir"/opt/wine-lol/lib -name '*.a' -type f -exec strip $STRIP_STATIC {} + 2> /dev/null || true

find "$pkgdir"/opt/wine-lol/lib32 -name '*.a' -type f -exec strip $STRIP_STATIC {} + 2> /dev/null || true
find "$pkgdir"/opt/wine-lol/lib32 \
     -not -name 'ld-*.so' \
     -not -name 'libc-*.so' \
     -not -name 'libpthread-*.so' \
     -not -name 'libthread_db-*.so' \
     -name '*-*.so' -type f -exec strip $STRIP_SHARED {} + 2> /dev/null || true

rm -r "$pkgdir/usr/share"
rm -r "$pkgdir/etc"
rmdir "$pkgdir/usr"

cd "$pkgdir"
tar cvzf ../wine-lol-glibc.tar.gz .

