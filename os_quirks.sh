#!/usr/bin/env bash
#
# OS quirks for the Pythia build system.

case $OS in
    win)
        # On Windows, python executable is installed at a different path.
        LOCAL_PYTHON_BINARY=./$LOCAL_PYTHON_BINARY_DIST/lib/python3.exe
        PYTHON_BIN=$INSTALL_DIR/lib/python3.exe
        # On Windows Server 2016, redistributables are older.
        if [ "$ARCH" = "x86" ]; then
            export REDISTRIBUTABLE_VERSION="9.0.30729.9247"
        fi
        # On Windows, there are no actual dependency builds.
        export BUILD_BZIP2="no"
        export BUILD_LIBEDIT="no"
        export BUILD_GMP="no"
        export BUILD_SQLITE="no"
        PIP_LIBRARIES="$PIP_LIBRARIES \
            gmpy2==${GMPY2_VERSION}
            pywin32==${PYWIN32_VERSION} \
            "
        # GitHub's "runners" don't have wget installed, curl comes with MinGW.
        export GET_CMD="curl --silent --output"
        # On Windows, only one of the installers is downloaded.
        export SHA_CMD="$SHA_CMD --ignore-missing"
        # FIXME:3: sha512sum fails on Windows under GitHub/Travis CI.
        if [ x"$USERNAME" = x"runneradmin" -o x"$USERNAME" = x"travis" ]; then
            (>&2 echo '    No usable sha512sum.exe. Will not check checksums!')
            export SHA_CMD="true"
        fi
        ;;
    alpine*)
        # By default, the busybox ersatz binaries are used.
        export GET_CMD="wget -q -O"
        export SHA_CMD="sha512sum -csw"
        ;;
    lnx)
        # Build as portable as possible, only glibc 2.x should be needed.
        export BUILD_LIBFFI="yes"
        export BUILD_ZLIB="yes"
        export BUILD_LIBEDIT="no"
        # Generic Linux might be an old distro with OpenSSL 0.9.8 libraries.
        # To avoid linking to local libs, build own OpenSSL libs.
        export BUILD_OPENSSL="yes"
        # Generic builds on CentOS 5 have issues with Let's Encrypt certs.
        export GET_CMD="wget --quiet --no-check-certificate -O"
        ;;
    macos)
        export CC="clang"
        export CXX="clang++"
        # Build as compatible as it makes sense. See brink.sh for the reason.
        export CFLAGS="$CFLAGS -mmacosx-version-min=10.12"
        # setup.py skips building readline by default, as it sets this to
        # "10.4", and then tries to avoid the broken readline in OS X 10.4.
        export MACOSX_DEPLOYMENT_TARGET=10.12
        # System includes bzip2 libs by default.
        export BUILD_BZIP2="no"
        # 10.13 and newer come with LibreSSL instead of the old OpenSSL libs.
        # But 10.13 has version 2.2.7, while cryptography 2.9 requires 2.7.
        # Therefore, build OpenSSL for both stdlib and cryptography.
        export BUILD_OPENSSL="yes"
        export GET_CMD="curl --silent --output"
        export SHA_CMD="shasum --algorithm 512 --check --status --warn"
        ;;
    fbsd*)
        export CC="clang"
        export CXX="clang++"
        # libffi not available in the base system, only as port/package.
        export BUILD_LIBFFI="yes"
        # System includes bzip2 libs by default.
        export BUILD_BZIP2="no"
        ;;
    obsd*)
        export CC="clang"
        export CXX="clang++"
        # libffi not available in the base system, only as port/package.
        export BUILD_LIBFFI="yes"
        ;;
    sol*)
        # By default, Sun's Studio compiler is used.
        export CC="cc"
        export CXX="CC"
        export MAKE="gmake"
        # Needed for the subprocess32 module.
        # More at https://github.com/google/python-subprocess32/issues/40.
        export CFLAGS="$CFLAGS -DHAVE_DIRFD"
        # Arch-specific bits and paths.
        if [ "${ARCH%64}" = "$ARCH" ]; then
            # GMP needs to be informed of a 32bit build.
            export ABI="32"
        else
            export CFLAGS="$CFLAGS -m64"
            export LDFLAGS="$LDFLAGS -m64 -L/usr/lib/64 -R/usr/lib/64"
        fi
        # System includes bzip2 libs by default.
        export BUILD_BZIP2="no"
        # Solaris 11 is much more modern, but still has some quirks.
        # Multiple system libffi libs present, this is a problem in 11.4.
        export BUILD_LIBFFI="yes"
        ;;
esac

# Compiler-dependent flags. At this moment, the compiler is known.
if [ "${OS%sol*}" = "" ]; then
    # Not all packages enable PIC, force it to avoid relocation issues.
    export CFLAGS="$CFLAGS -Kpic"
elif [ "${OS%fbsd*}" = "" -o "${OS%obsd*}" = "" ]; then
    # Use PIC (Position Independent Code) on FreeBSD and OpenBSD with Clang.
    export CFLAGS="${CFLAGS} -fPIC"
elif [ "$CC" = "gcc" -a ${ARCH%%64} != "$ARCH" ]; then
    # Use PIC (Position Independent Code) with GCC on 64-bit arches.
    export CFLAGS="${CFLAGS} -fPIC"
fi

# Get number of useful CPUs, to enable parallel builds where applicable.
case "$OS" in
    win)
        # Logical CPUs (including hyper-threading) in Windows 2000 or newer.
        CPUS="$NUMBER_OF_PROCESSORS"
        ;;
    macos|fbsd*|obsd*)
        # Logical CPUs.
        CPUS=$(sysctl -n hw.ncpu)
        ;;
    sol*)
        # Physical CPUs. 
        CPUS=$(/usr/sbin/psrinfo -p)
        ;;
    *)
        # Only Linux distros should be left, look for logical CPUS.
        # Don't use lscpu/nproc or other stuff not present on older distros.
        CPUS=$(getconf _NPROCESSORS_ONLN)
        ;;
esac
export MAKE="$MAKE -j${CPUS}"
