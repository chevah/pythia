#!/usr/bin/env bash
#
# OS quirks for the Pythia build system.

case $OS in
    windows)
        # On Windows, the python executable is installed in a different path.
        PYTHON_BIN="$INSTALL_DIR/lib/python.exe"
        # There are no actual dependency builds, only binary wheels are used.
        BUILD_BZIP2="no"
        BUILD_SQLITE="no"
        BUILD_OPENSSL="no"
        PIP_LIBRARIES+=(pywin32=="$PYWIN32_VERSION")
        ;;
    linux*)
        # Build as portable as possible, only glibc/musl should be needed.
        export CFLAGS="${CFLAGS:-} -mtune=generic"
        BUILD_LIBFFI="yes"
        BUILD_ZLIB="yes"
        BUILD_XZ="yes"
        if [ -f /etc/alpine-release ]; then
            # The busybox ersatz binary on Alpine Linux is different.
            SHA_CMD=(sha512sum -csw)
        fi
        ;;
    macos)
        export CC="clang"
        export CXX="clang++"
        if [ "$ARCH" = "x64" ]; then
            export CFLAGS="${CFLAGS:-} -mmacosx-version-min=10.13"
            # setup.py skips building readline by default, as it sets this to
            # "10.4", and then tries to avoid the broken readline in OS X 10.4.
            export MACOSX_DEPLOYMENT_TARGET=10.13
        else
            export CFLAGS="${CFLAGS:-} -mmacosx-version-min=11.0"
            # setup.py skips building readline by default, as it sets this to
            # "10.4", and then tries to avoid the broken readline in OS X 10.4.
            export MACOSX_DEPLOYMENT_TARGET=11.0
        fi
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
        export MAKE_CMD=(gmake)
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
case "$CC" in
    gcc*)
        export CFLAGS="${CFLAGS:-} -fPIC"
        ;;
esac

# Get number of useful CPUs, to enable parallel builds where applicable.
case "$OS" in
    windows)
        # Logical CPUs (including hyper-threading) in Windows 2000 or newer.
        CPUS="$NUMBER_OF_PROCESSORS"
        ;;
    macos|fbsd*|obsd*)
        # Logical CPUs.
        CPUS="$(sysctl -n hw.ncpu)"
        ;;
    sol*)
        # Physical CPUs. 
        CPUS="$(/usr/sbin/psrinfo -p)"
        ;;
    *)
        # Only Linux distros should be left, look for logical CPUS.
        # Don't use lscpu/nproc or other stuff not present on older distros.
        CPUS="$(getconf _NPROCESSORS_ONLN)"
        ;;
esac
MAKE_CMD=("${MAKE_CMD[@]}" -j"$CPUS")
