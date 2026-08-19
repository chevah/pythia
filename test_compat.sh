#!/usr/bin/env bash
#
# Test the Pythia distribtution availabe in DIST agains compat.
# Test are done agains the fully packed version from dist.
#

# Bash checks
set -o nounset    # always check if variables exist
set -o errexit    # always exit on error
set -o errtrace   # trap errors in functions as well
set -o pipefail   # don't ignore exit codes when piping output
set -o functrace  # inherit DEBUG and RETURN traps

TEST_BRANCH='737-python-3.14-update'

# Set versions for the software to be built and other defaults.
source build.conf

# Run the test suite from chevah/compat master.

execute pushd "$BUILD_DIR"

# This is quite hackish, as compat is arm-twisted to use the local version.
echo "::group::Compat tests"
echo "#### Running chevah's compat tests... ####"
echo "## Removing any pre-existing compat code... ##"
execute rm -rf compat/
echo "## Cloning compat's $TEST_BRANCH branch... ##"
execute git clone https://github.com/chevah/compat.git --depth=1 -b $TEST_BRANCH
execute pushd compat
    # Make sure everything is done from scratch in the current dir.
    echo "## Unsetting CHEVAH_CACHE and CHEVAH_BUILD... ##"
    unset CHEVAH_CACHE CHEVAH_BUILD
    # Copy over current pythia stuff, as some changes might require it.
    echo "## Patching compat code to use current pythia version... ##"
    execute cp ../../pythia.{conf,sh} ./
    # Patch compat to use the current's branch version.
    echo -e "\nPYTHON_CONFIGURATION=default@${PYTHIA_RELEASE}" >>pythia.conf
    execute mkdir cache
    # Copy dist file to local cache, if existing. If not, maybe it's online.
    cp ../../"$DIST_DIR"/* cache/
    # Some tests could fail due to causes not related to the new Python.
    echo "## Getting compat deps... ##"
    execute ./pythia.sh deps
    echo "## Running normal compat tests... ##"
    # Why not test_normal? See https://github.com/chevah/compat/issues/691.
    execute ./pythia.sh test -vs normal
    if [ "${CI:-}" = "true" ]; then
        echo "## Running ci2 compat tests... ##"
        execute ./pythia.sh test_ci2
    fi
execute popd
echo "::endgroup::"
