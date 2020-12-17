#!/usr/bin/env bash
#
# Small helper to show final destination for packages uploaded through GitHub actions.

source BUILD_ENV_VARS
echo "Package python-$PYTHON_FULL_VERSION-$OS-$ARCH.tar.gz uploaded to:"
echo "    https://bin.chevah.com:20443/testing/$PYTHON_FULL_VERSION/"
echo "Direct link:"
echo "    https://bin.chevah.com:20443/testing/$PYTHON_FULL_VERSION/python-$PYTHON_FULL_VERSION-$OS-$ARCH.tar.gz"
