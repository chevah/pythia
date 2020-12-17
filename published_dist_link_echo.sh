#!/usr/bin/env bash
#
# Helper to show final destination for packages uploaded through GitHub actions.

set -o nounset
set -o errexit
set -o pipefail

root_link="https://bin.chevah.com:20443/testing"

source BUILD_ENV_VARS

pkg_name="python-$PYTHON_FULL_VERSION-$OS-$ARCH.tar.gz"

echo -n "Package $pkg_name uploaded to: "
echo "$root_link/$PYTHON_FULL_VERSION/"
echo -n "Direct link: "
echo "$root_link/$PYTHON_FULL_VERSION/$pkg_name"
