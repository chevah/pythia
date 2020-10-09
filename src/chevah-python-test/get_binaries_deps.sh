#!/usr/bin/env bash

# Uses 'ldd' or equivalents to list all dependencies for the python binary and
# .so files in the current hierarchy of directories (to be run in 'build/').

set -o nounset
set -o errexit
set -o pipefail

checker="ldd"
os="$(uname)"

if [ "$os" = "Darwin" ]; then
    checker="otool -L"
elif [ "$os" = "SunOS" ]; then
    # By default, Solaris' ldd picks up too many libs.
    checker="ldd -L"
elif [ "$os" = "Linux" ]; then
    if [ -f /etc/alpine-release ]; then
        # musl's ldd has issues with some Python modules, so we use lddtree,
        # which is forked from pax-utils and installed by default in Alpine.
        checker="lddtree -l"
    fi
fi

# This portable invocation of find will get a raw list of linked libs
# for the current binaries in the current sub-directory, usually 'build'.
find ./ -type f \( -name "python" -o -name "*.so" \) -exec $checker {} \;
