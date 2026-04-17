#!/usr/bin/env bash
#
# Run own tests for the newly-build Python distribution.
# Tests are done with the version from build folder.
#
# Bash checks
set -o nounset    # always check if variables exist
set -o errexit    # always exit on error
set -o errtrace   # trap errors in functions as well
set -o pipefail   # don't ignore exit codes when piping output
set -o functrace  # inherit DEBUG and RETURN traps

TARGET=$1

# Set versions for the software to be built and other defaults.
source build.conf

INSTALL_DIR="$PWD/$BUILD_DIR/python$PY_VERSION-$TARGET"

OS="${TARGET%-*}"    # Retain everything before the last hyphen
ARCH="${TARGET#*-}"  # Retain everything after the first hyphen
export OS
export ARCH

echo "::group::Chevah tests for $OS $ARCH"
if [ ! -d "$BUILD_DIR" ]; then
    (>&2 echo "No $BUILD_DIR sub-directory present, try 'build' first!")
    exit 220
fi

echo "#### Executing Chevah Python tests... ####"
python_binary="$INSTALL_DIR/bin/python"
if [ "$TARGET" == "windows-x64" ]; then
    # Post-cleanup, the binary in /bin is named "python", not "python3.x".
    python_binary="$INSTALL_DIR/lib/python"
fi
test_file="test_python_binary_dist.py"
cp src/chevah-python-tests/"$test_file" "$BUILD_DIR"
cp src/chevah-python-tests/get_binaries_deps.sh "$BUILD_DIR"
pushd "$BUILD_DIR"
execute "$python_binary" "$test_file"
popd
echo "::endgroup::"
