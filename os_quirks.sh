#!/usr/bin/env bash
#
# OS quirks for the Pythia build system.

case $OS in
    win)
        # On Windows, the python executable is installed in a different path.
        PYTHON_BIN="$INSTALL_DIR/lib/python.exe"
        # There are no actual dependency builds, only binary wheels are used.
        BUILD_BZIP2="no"
        BUILD_SQLITE="no"
        BUILD_OPENSSL="no"
        PIP_LIBRARIES=("${PIP_LIBRARIES[@]}" \
            pywin32=="$PYWIN32_VERSION" \
            )
        ;;
    linux*)
        if [ -f /etc/alpine-release ]; then
            # The busybox ersatz binary on Alpine Linux is different.
            SHA_CMD=(sha512sum -csw)
        fi
        # Build as portable as possible, only glibc/musl should be needed.
        BUILD_LIBFFI="yes"
        BUILD_ZLIB="yes"
        BUILD_XZ="yes"
        ;;
    macos)
        export CC="clang"
        export CXX="clang++"
        export CFLAGS="${CFLAGS:-} -mmacosx-version-min=10.13"
        # setup.py skips building readline by default, as it sets this to
        # "10.4", and then tries to avoid the broken readline in OS X 10.4.
        export MACOSX_DEPLOYMENT_TARGET=10.13
        # System includes bzip2 libs by default.
        BUILD_BZIP2="no"
        BUILD_XZ="yes"
        SHA_CMD=(shasum --algorithm 512 --check --status --warn)
        ;;
    fbsd*)
        export CC="clang"
        export CXX="clang++"
        # libffi not available in the base system, only as port/package.
        BUILD_LIBFFI="yes"
        # System includes bzip2 libs by default.
        BUILD_BZIP2="no"
        BUILD_XZ="yes"
        # Install package "p5-Digest-SHA" to get shasum binary.
        SHA_CMD=(shasum --algorithm 512 --check --status --warn)
        ;;
    obsd*)
        export CC="clang"
        export CXX="clang++"
        # libffi not available in the base system, only as port/package.
        BUILD_LIBFFI="yes"
        BUILD_XZ="yes"
        SHA_CMD=(sha512 -q -c)
        ;;
    sol*)
        # By default, Sun's Studio compiler is used.
        export CC="cc"
        export CXX="CC"
        export MAKE="gmake"
        # Needed for the subprocess32 module.
        # More at https://github.com/google/python-subprocess32/issues/40.
        export CFLAGS="${CFLAGS:-} -DHAVE_DIRFD"
        # Arch-specific bits and paths.
        if [ "${ARCH%64}" = "$ARCH" ]; then
            # Some libs (e.g. GMP) need to be informed of a 32bit build.
            export ABI="32"
        else
            export CFLAGS="$CFLAGS -m64"
            export LDFLAGS="${LDFLAGS:-} -m64 -L/usr/lib/64 -R/usr/lib/64"
        fi
        # System includes bzip2 libs by default.
        BUILD_BZIP2="no"
        # Solaris 11 is much more modern, but still has some quirks.
        # Multiple system libffi libs are present, this is a problem in 11.4.
        BUILD_LIBFFI="yes"
        BUILD_XZ="yes"
        # Native tar is not that compatible, but the GNU tar should be present.
        TAR_CMD=(gtar xfz)
        ;;
esac

# Compiler-dependent flags. At this moment, the compiler is known.
case "$OS" in
    sol*)
        # Not all packages enable PIC, force it to avoid relocation issues.
        export CFLAGS="$CFLAGS -Kpic"
        ;;
    fbsd*|obsd*)
        # Use PIC (Position Independent Code) on FreeBSD and OpenBSD with Clang.
        export CFLAGS="${CFLAGS:-} -fPIC"
        ;;
esac

# Use PIC (Position Independent Code) with GCC on 64-bit arches (currently all).
if [ "$CC" = "gcc" ]; then
    export CFLAGS="${CFLAGS:-} -fPIC"
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
export MAKE="${MAKE:-} -j${CPUS}"

if [ "$DEBUG" -ne 0 ]; then
    build_flags=(OS ARCH CC CFLAGS MAKE BUILD_LIBFFI BUILD_ZLIB BUILD_BZIP2 \
        BUILD_XZ BUILD_LIBEDIT BUILD_OPENSSL BUILD_SQLITE)
    echo -e "\tBuild variables:"
    for build_var in "${build_flags[@]}"; do
        # This uses Bash's indirect expansion.
        echo "$build_var: ${!build_var}"
    done
fi
