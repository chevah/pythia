#!/usr/bin/env bash
#
# Get the latest Shellcheck version into our build folder.
#
# Should be called with the build folder as the first argument.
# Snatched from chevah/server repo, and improved to also work on macOS x64.
# Another change: this uses $BUILD_DIR, not $BUILD_DIR/bin.

# Bash checks
set -o nounset    # always check if variables exist
set -o errexit    # always exit on error
set -o errtrace   # trap errors in functions as well
set -o pipefail   # don't ignore exit codes when piping output

BUILD_DIR="$1"
OS_STRING="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
fi

# Upstream Shellcheck stuff.
SHELLCHECK_LNK="https://github.com/koalaman/shellcheck/releases/download/latest"
SHELLCHECK_DIR="shellcheck-latest"
SHELLCHECK_XZ="$SHELLCHECK_DIR.$OS_STRING.$ARCH.tar.xz"


# Using Bash arrays for commands, to make them quotable.
# Be non-verbose by default.
if [ "${DEBUG-0}" -ne 0 ]; then
    ECHO_CMD=(echo)
    CURL_CMD=(curl)
    TAR_CMD=(tar xvf)
    MV_CMD=(mv -v)
    RM_CMD=(rm -rfv)
else
    ECHO_CMD=(true)
    CURL_CMD=(curl --silent)
    TAR_CMD=(tar xf)
    MV_CMD=(mv)
    RM_CMD=(rm -rf)
fi

#
# Install latest Shellcheck binary.
#
install_latest_shellcheck() {
    "${ECHO_CMD[@]}" "Installing latest Shellcheck..."
    "${CURL_CMD[@]}" --location "$SHELLCHECK_LNK"/"$SHELLCHECK_XZ" \
        --output /tmp/"$SHELLCHECK_XZ"
    "${TAR_CMD[@]}" /tmp/"$SHELLCHECK_XZ" --directory /tmp/
    # The end slash assures that the destination is a dir, not a new file.
    "${MV_CMD[@]}" -v /tmp/"$SHELLCHECK_DIR"/shellcheck "$BUILD_DIR"/
    "${RM_CMD[@]}" /tmp/"$SHELLCHECK_DIR"
}

if [ ! -x "$BUILD_DIR"/shellcheck ]; then
    # Only install Shellcheck if it's not already present.
    install_latest_shellcheck
    exit 0
fi

"${ECHO_CMD[@]}" "Shellcheck already installed."
