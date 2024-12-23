#!/usr/bin/env bash
#
# Pythia's script for building Python.


# Bash checks
set -o nounset    # always check if variables exist
set -o errexit    # always exit on error
set -o errtrace   # trap errors in functions as well
set -o pipefail   # don't ignore exit codes when piping output
set -o functrace  # inherit DEBUG and RETURN traps

# Default PyPI server to use. Can be overwritten in build.conf.
PIP_INDEX_URL="https://pypi.org/simple"

# Set versions for the software to be built and other defaults.
source build.conf

# Import shared and specific code.
source ./functions.sh
source ./functions_build.sh

# Git revision to inject into Python's sys.version string through chevahbs
# on non-Windows platforms. Also used for compat tests and archived in the dist.
PYTHIA_VERSION="$(git log -n 1 --no-merges --pretty=format:%h)"
exit_on_error $? 250

# Export the variables needed by the chevahbs scripts and the test phase.
export PYTHON_BUILD_VERSION PYTHIA_VERSION PYTHIA_BUILD_TESTS
export BUILD_ZLIB BUILD_BZIP2 BUILD_XZ BUILD_LIBEDIT BUILD_LIBFFI BUILD_OPENSSL

# OS detection is done by the common pythia.sh. The values are saved in a file.
if [ ! -s BUILD_ENV_VARS ]; then
    execute ./pythia.sh detect_os
fi
source BUILD_ENV_VARS

# On Unix, use $ARCH to choose between 32bit or 64bit packages. It's possible
# to force a 32bit build on a 64bit machine, e.g. by setting ARCH in pythia.sh
# as "x86" instead of "x64" for a certain platform.
# $ARCH is also used when "building" Python on Windows and for testing.
# $OS is used when patching/configuring/building/testing.
export ARCH OS

# Local variables for the build process.
PYTHON_BUILD_DIR="$PYTHON_VERSION-$OS-$ARCH"
INSTALL_DIR="$PWD/$BUILD_DIR/$PYTHON_BUILD_DIR"
PYTHON_BIN="$INSTALL_DIR/bin/$PYTHON_VERSION"

# Explicitly choose the C compiler in order to make it possible to switch
# between native compilers and GCC on platforms such as the BSDs and Solaris.
export CC="${CC:-gcc}"
# Used for testing Python C++ extensions (test_cppext).
export CXX="${CXX:-g++}"
# Other needed tools (GNU flavours preferred).
# For proper quoting, _CMD vars are Bash arrays of commands and optional flags.
MAKE_CMD=(make)
SHA_CMD=(sha512sum --check --status --warn)
TAR_CMD=(tar xfz)
ZIP_CMD=(unzip -q)
# $GET_CMD must save to custom filename, which must be appended before the link.
# E.g., to use wget, GET_CMD should be (wget --quiet -O).
GET_CMD=(curl --silent --location --output)

# OS quirks. Sourced last to allow overwriting the above variables.
source os_quirks.sh


# shellcheck disable=SC2034 # Only used through compgen.
help_text_clean="Clean build dir. Add -a to remove downloads and saved values."
command_clean() {
    echo "#### Removing previous build sub-directory, if existing... ####"
    execute rm -rf "$BUILD_DIR"

    if [ $# -ne 0 ]; then
        if [ "$1" = "-a" ]; then
            echo "## Removing all downloads from src/... ##"
            execute rm -fv src/*/*.{tar.gz,tgz,zip}
            echo "## Removing all local files with saved values... ##"
            execute rm -fv BUILD_ENV_VARS BUILD_ENV_ARRAYS
        fi
    fi
}


# shellcheck disable=SC2034 # Only used through compgen.
help_text_build="Build Python binaries for current platform."
command_build() {
    echo "::group::Package/command checks"
    # Check for packages required to build on current OS.
    echo "#### Checking for required packages... ####"
    source pkg_checks.sh
    echo "::endgroup::"

    # Clean build dir to avoid contamination from previous builds,
    # but without removing the download archives, to speed up next builds.
    command_clean "$@"

    # Build stuff statically on most platforms, install headers and libs in the
    # following locations, making sure they are picked up when building Python.
    execute mkdir -p "$INSTALL_DIR"/{include,lib}
    export LDFLAGS="-L${INSTALL_DIR}/lib/ ${LDFLAGS:-}"
    export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig/:${PKG_CONFIG_PATH:-}"
    # On certain OS'es, some modules require this (zlib, bz2, lzma, sqlite3).
    export CPPFLAGS="${CPPFLAGS:-} -I${INSTALL_DIR}/include"

    build_dep "$BUILD_LIBFFI"   libffi           "$LIBFFI_VERSION"
    build_dep "$BUILD_ZLIB"     zlib             "$ZLIB_VERSION"
    build_dep "$BUILD_BZIP2"    bzip2            "$BZIP2_VERSION"
    build_dep "$BUILD_XZ"       xz               "$XZ_VERSION"
    build_dep "$BUILD_LIBEDIT"  libedit          "$LIBEDIT_VERSION"
    build_dep "$BUILD_SQLITE"   sqlite-autoconf  "$SQLITE_VERSION"
    build_dep "$BUILD_OPENSSL"  openssl          "$OPENSSL_VERSION"

    build_python

    # Python modules installed w/ pip. Some are built locally (not on Windows).
    command_install_python_modules

    # Cleanups the dir to be packaged, also moves include/ from the root dir.
    cleanup_install_dir

    # Build the new package.
    make_dist "$PYTHON_BUILD_DIR"

    # Generate a SFTP batch for uploading the package.
    build_publish_dist_sftp_batch

    # Put include/ back where it belongs, for building testing modules.
    bring_back_include
}


# This builds Python's dependencies: libffi, bzip2, openssl, etc.
build_dep() {
    local dep_boolean="$1"
    local dep_name="$2"
    local dep_version="$3"

    if [ "$dep_boolean" = "yes" ]; then
        # This is where building happens.
        build "$dep_name" "$dep_version"
        # If there's something to be done post-build, here's the place.
    elif [ "$dep_boolean" = "no" ]; then
        (>&2 echo -e "\tSkip building $dep_name")
    else
        (>&2 echo "Unknown env var for building $dep_name. Exiting!")
        exit 248
    fi
}


# This builds Python itself.
build_python() {
    if [ "$OS" = "windows" ]; then
        # Python "build" is a very special case under Windows.
        execute pushd src/Python-Windows
        execute ./chevahbs Python "$PYTHON_BUILD_VERSION" "$INSTALL_DIR"
        execute popd
    else
        build Python "$PYTHON_BUILD_VERSION"
    fi
}

bootstrap_pip(){
    echo "### Bootstrapping pip... ###"
    if [ "$OS" = "windows" ]; then
        # The embeddable Windows package doesn't include "ensurepip".
        echo "## Downloading get-pip.py... ##"
        if [ ! -e "$BUILD_DIR"/get-pip.py ]; then
            execute "${GET_CMD[@]}" "$BUILD_DIR"/get-pip.py "$BOOTSTRAP_GET_PIP"
        fi
        execute "$PYTHON_BIN" "$BUILD_DIR"/get-pip.py "${PIP_ARGS[@]}" \
            pip=="$PIP_VERSION" --no-setuptools \
            setuptools=="$SETUPTOOLS_VERSION"
    else
        echo "## Installing pip from included ensurepip module... ##"
        execute "$PYTHON_BIN" -m ensurepip --upgrade
    fi
}
# Compile and install all Python extra libraries.
command_install_python_modules() {
    echo "::group::Install Python modules with pip $PIP_VERSION"
    echo "#### Installing Python modules... ####"

    # Install latest PIP, then instruct it to get exact version of setuptools.
    bootstrap_pip
    echo "# Installing latest pip with preferred setuptools version... #"
    execute "$PYTHON_BIN" -m pip install "${PIP_ARGS[@]}" \
        pip=="$PIP_VERSION" setuptools=="$SETUPTOOLS_VERSION"

    # pycparser is installed first as setup_requires is ugly.
    # https://pip.pypa.io/en/stable/reference/pip_install/#controlling-setup-requires
    echo "# Installing pycparser with preferred setuptools version... #"
    execute "$PYTHON_BIN" -m pip install "${PIP_ARGS[@]}" \
        -U pycparser=="$PYCPARSER_VERSION"

    if [ "$OS" = "windows" ]; then
        echo -e "\tSkip makefile updating on Windows"
    else
        echo "# Updating Python config Makefile for newly-built Python... #"
        makefile="$(ls "$INSTALL_DIR"/lib/"$PYTHON_VERSION"/config*/Makefile)"
        makefile_orig="$makefile".orig

        execute cp "$makefile" "$makefile_orig"
        execute sed "s#^prefix=.*#prefix= $INSTALL_DIR#" "$makefile_orig" \
            > "$makefile"
    fi

    for library in "${PIP_LIBRARIES[@]}" ; do
        execute "$PYTHON_BIN" -m pip install "${PIP_ARGS[@]}" "$library"
    done

    echo "# Uninstalling wheel... #"
    execute "$PYTHON_BIN" -m pip uninstall --yes wheel

    echo "# Regenerating requirements.txt file... #"
    execute "$PYTHON_BIN" -m pip freeze --all > requirements.txt

    echo "::endgroup::"
}


# shellcheck disable=SC2034 # Only used through compgen.
help_text_test="Run own tests for the newly-build Python distribution."
command_test() {
    local test_file="test_python_binary_dist.py"
    local python_binary="$PYTHON_BIN"

    echo "::group::Chevah tests"
    if [ ! -d "$BUILD_DIR" ]; then
        (>&2 echo "No $BUILD_DIR sub-directory present, try 'build' first!")
        exit 220
    fi

    echo "#### Executing Chevah Python tests... ####"
    if [ "$OS" != "windows" ]; then
        # Post-cleanup, the binary in /bin is named "python", not "python3.x".
        local python_binary="$INSTALL_DIR/bin/python"
    fi
    execute cp src/chevah-python-tests/"$test_file" "$BUILD_DIR"
    execute cp src/chevah-python-tests/get_binaries_deps.sh "$BUILD_DIR"
    execute pushd "$BUILD_DIR"
    execute "$python_binary" "$test_file"
    execute popd
    echo "::endgroup::"

    echo "::group::Security tests"
    echo "## Testing for outdated packages... ##"
    execute "$python_binary" -m pip list --outdated --format=columns
    echo "::endgroup::"

    echo "::group::Shell tests"
    echo "#### Executing Chevah shell tests... ####"
    execute ./src/chevah-bash-tests/shellcheck_tests.sh
    echo "::endgroup::"
}


# shellcheck disable=SC2034 # Only used through compgen.
help_text_compat="Run the test suite from chevah/compat master."
command_compat() {
    local new_python_ver="$PYTHON_BUILD_VERSION.$PYTHIA_VERSION"
    execute pushd "$BUILD_DIR"

    # This is quite hackish, as compat is arm-twisted to use the local version.
    echo "::group::Compat tests"
    echo "#### Running chevah's compat tests... ####"
    echo "## Removing any pre-existing compat code... ##"
    execute rm -rf compat/
    echo "## Cloning compat's master branch... ##"
    execute git clone https://github.com/chevah/compat.git --depth=1 -b master
    execute pushd compat
        # Make sure everything is done from scratch in the current dir.
        echo "## Unsetting CHEVAH_CACHE and CHEVAH_BUILD... ##"
        unset CHEVAH_CACHE CHEVAH_BUILD
        # Copy over current pythia stuff, as some changes might require it.
        echo "## Patching compat code to use current pythia version... ##"
        execute cp ../../pythia.{conf,sh} ./
        # Patch compat to use the current's branch version.
        echo -e "\nPYTHON_CONFIGURATION=default@${new_python_ver}" >>pythia.conf
        execute mkdir cache
        # Copy dist file to local cache, if existing. If not, maybe it's online.
        cp ../../"$DIST_DIR"/"$PYTHON_BUILD_VERSION.$PYTHIA_VERSION"/* cache/
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
}



#
# Launch the whole thing.
#

# Bash arrays are not exported to child processes. More details at
# https://www.mail-archive.com/bug-bash@gnu.org/msg01774.html.
# Therefore, pass _CMD stuff to the "chevahbs" scripts in a file to be sourced.
# The unusual quoting avoids mixing strings and arrays.
# Indentation helps when showing the arrays during debugging.
(
    echo -e "\tMAKE_CMD=(" "${MAKE_CMD[@]}" ")"
    echo -e "\tGET_CMD=(" "${GET_CMD[@]}" ")"
    echo -e "\tSHA_CMD=(" "${SHA_CMD[@]}" ")"
    echo -e "\tTAR_CMD=(" "${TAR_CMD[@]}" ")"
    echo -e "\tZIP_CMD=(" "${ZIP_CMD[@]}" ")"
) > BUILD_ENV_ARRAYS

if [ "$DEBUG" -ne 0 ]; then
    build_flags=(OS ARCH CC CFLAGS BUILD_LIBFFI BUILD_ZLIB BUILD_BZIP2 \
        BUILD_XZ BUILD_LIBEDIT BUILD_OPENSSL BUILD_SQLITE)
    echo -e "Build variables:"
    for build_var in "${build_flags[@]}"; do
        # This uses Bash's indirect expansion.
        echo -e "\t$build_var: ${!build_var}"
    done
    echo "Bash arrays to import in chevahbs scripts:"
    cat BUILD_ENV_ARRAYS
fi

select_command "$@"
