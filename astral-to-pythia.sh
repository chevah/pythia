#!/usr/bin/env bash
#
# Script to generate Python virtual environments compatible with pythia
# based on the astra-sh/python-build-standalone Python builds.

set -o errexit

# linux-x64 | linux-arm64 | linux_musl-x64 | macos-x64 | macos-arm64
# windows-x64
TARGET="$1"

source build.conf

# x86_64_v2-*
# Targets 64-bit Intel/AMD CPUs approximately newer than Nehalem (released in 2008).
# Binaries will have SSE3, SSE4, and other CPU instructions added after the ~initial x86-64 CPUs were launched in 2003.

LINUX_X64="x86_64_v2-unknown-linux-gnu"
LINUX_ARM64="aarch64-unknown-linux-gnu"
LINUX_MUSL_X64="x86_64_v2-unknown-linux-musl"
MACOS_ARM64="aarch64-apple-darwin"
MACOS_X64="x86_64-apple-darwin"
WINDOWS_X64="x86_64-pc-windows-msvc"

# Start with a clean build
#rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cd $BUILD_DIR

case "$TARGET" in
    linux-x64)
        pbs_arch=${LINUX_X64}
        ;;
    linux-arm64)
        pbs_arch=${LINUX_ARM64}
        ;;
    linux_musl-x64)
        pbs_arch="${LINUX_MUSL_X64}"
        ;;
    macos-x64)
        pbs_arch="${MACOS_X64}"
        ;;
    macos-arm64)
        pbs_arch="${MACOS_ARM64}"
        ;;
    windows-x64)
        pbs_arch="${WINDOWS_X64}"
        ;;
    *)
        #
        echo "Unknown target ${TARGET}"
        exit 1

        ;;
esac


file_name="${pbs_arch}-install_only_stripped.tar.gz"
source_url="https://github.com/astral-sh/python-build-standalone/releases/download/$PBS_RELEASE/cpython-${PY_RELEASE}+${PBS_RELEASE}-${file_name}"
echo "> Downloading $file_name"
curl -L -o $file_name $source_url

echo "> Extracting $file_name"

# Delete any leftover from a previous failed extraction.
# Used during dev when the whole build folder is not cleaned.
rm -rf python

tar xzf $file_name


case "$TARGET" in
    *windows*)
        # Do stuff
        mv python lib
        mkdir python
        mv lib python
        rm -rf python/lib/include
        rm -rf python/lib/tcl
        rm -f python/lib/libs/_tkinter.lib
        rm -f python/lib/DLLs/tcl*.dll
        rm -f python/lib/DLLs/tk*.dll
        cp ../src/zipfile_init.py python/lib/Lib/zipfile/__init__.py
        python_bin="python/lib/python"
        ${python_bin} -m pip install \
            --index-url="$PIP_INDEX_URL" \
            pywin32==${PYWIN32_VERSION}
        ;;
    *)
        # Linux and MacOS
        mv python/include python/lib

        # Cleanup bin folder with simple bin/python
        mv python/bin/python${PY_VERSION} python/python
        rm -rf python/bin
        mkdir python/bin
        mv python/python python/bin/

        rm -rf python/share
        rm -rf python/lib/itcl*
        rm -rf python/lib/tcl*
        rm -rf python/lib/tk*
        rm -rf python/lib/thread*
        rm -f python/lib/libtcl*
        rm -rf python/lib/python${PY_VERSION}/tkinter
        rm -rf python/lib/python${PY_VERSION}/turtledemo
        rm -f python/lib/python${PY_VERSION}/lib-dynload/_tkinter*
        cp ../src/zipfile_init.py python/lib/python${PY_VERSION}/zipfile/__init__.py
        python_bin="./python/bin/python"
        ;;
esac

ls -al python/*

pythia_version="${PY_RELEASE}.${PBS_RELEASE}-${TARGET}"
echo -n "${pythia_version}" > python/lib/PYTHIA_VERSION

pythia_base="python${PY_VERSION}-${TARGET}"
mv python ${pythia_base}
echo "> Creating ${pythia_base} for ${pythia_version} to ../dist/"

tar czf ../dist/python-${PYTHIA_RELEASE}-${TARGET}.tar.gz ${pythia_base}
