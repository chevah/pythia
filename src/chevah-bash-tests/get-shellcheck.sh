#!/usr/bin/env bash
#
# Get the latest Shellcheck version into our build folder.
#
# Should be called with the build folder as the first argument.

# Script initialisation.
set -o nounset
set -o pipefail

# If not defined, set default value.
BUILD_DIR="$1"
OS_STRING="$(uname | tr '[:upper:]' '[:lower:]')"

# Upstream Shellcheck stuff.
SHELLCHECK_LNK="https://github.com/koalaman/shellcheck/releases/download/latest"
SHELLCHECK_DIR="shellcheck-latest"
SHELLCHECK_XZ="$SHELLCHECK_DIR.$OS_STRING.x86_64.tar.xz"

# Be verbose by default.
ECHO_CMD="echo"
CURL_CMD="curl"
TAR_CMD="tar xvf"
MV_CMD="mv -v"
RM_CMD="rm -rfv"

#
# Install latest Shellcheck binary.
#
install_latest_shellcheck() {
    $ECHO_CMD "Installing latest Shellcheck..."
    $CURL_CMD --location "$SHELLCHECK_LNK"/"$SHELLCHECK_XZ" \
        --output /tmp/"$SHELLCHECK_XZ"
    $TAR_CMD /tmp/"$SHELLCHECK_XZ" --directory /tmp/
    $MV_CMD -v /tmp/"$SHELLCHECK_DIR"/shellcheck "$BUILD_DIR"
    $RM_CMD /tmp/"$SHELLCHECK_DIR"
}

if [ ! -x "$BUILD_DIR"/shellcheck ]; then
    # Only install Shellcheck if it's not already present.
    install_latest_shellcheck
    exit 0
fi

$ECHO_CMD "Shellcheck already installed."
