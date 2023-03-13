#!/usr/bin/env bash
#
# Pythia's script for building Python.


# Bash checks
set -o nounset    # always check if variables exist
set -o errexit    # always exit on error
set -o errtrace   # trap errors in functions as well
set -o pipefail   # don't ignore exit codes when piping output

# Get PIP_INDEX_URL for PIP_ARGS in build.conf.
source pythia.conf

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
export PYTHON_BUILD_VERSION PYTHIA_VERSION
export BUILD_ZLIB BUILD_BZIP2 BUILD_XZ BUILD_LIBEDIT BUILD_LIBFFI BUILD_OPENSSL

# OS detection is slow on Windows, only execute it when the file is missing.
if [ ! -r ./BUILD_ENV_VARS ]; then
    execute ./pythia.sh detect_os
fi
# Import build env vars as set by pythia.sh.
source ./BUILD_ENV_VARS

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
export CC="gcc"
# Other needed tools (GNU flavours preferred).
export MAKE="make"
# $GET_CMD must save to custom filename, which must be appended before the link.
# E.g., to use wget, GET_CMD should be "wget --quiet -O".
export GET_CMD="curl --silent --location --output"
export SHA_CMD="sha512sum --check --status --warn"
export TAR_CMD="tar xfz"
export ZIP_CMD="unzip -q"
if [ x$(id -u) != "x0" ]; then
    export SUDO_CMD="sudo"
fi

# OS quirks.
source os_quirks.sh


help_text_clean="Clean build dir. Add -a to clean downloads from src/ too."
command_clean() {
    echo "#### Removing previous build/ sub-directory, if existing... ####"
    execute rm -rf "$BUILD_DIR"

    if [ $# -ne 0 ]; then
        if [ $1 = "-a" ]; then
            echo "## Removing any downloads from src/... ##"
            execute rm -fv src/*/*.{tar.gz,tgz,zip}
        fi
    fi
}


help_text_build="Build Python binaries for current platform."
command_build() {
    # Check for packages required to build on current OS.
    echo "::group::Package/command checks"
    echo "#### Checking for required packages... ####"
    source pkg_checks.sh
    echo "::endgroup::"

    # Clean build dir to avoid contamination from previous builds,
    # but without removing the download archives, to speed up the build.
    command_clean

    # Build stuff statically on most platforms, install headers and libs in the
    # following locations, making sure they are picked up when building Python.
    # $CFLAGS/$CPPFLAGS is another way to ensure this, but it's not as portable.
    execute mkdir -p "$INSTALL_DIR"/{include,lib}
    export LDFLAGS="-L${INSTALL_DIR}/lib/ ${LDFLAGS:-}"
    export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig/:${PKG_CONFIG_PATH:-}"

    build_dep $BUILD_LIBFFI   libffi           $LIBFFI_VERSION
    build_dep $BUILD_ZLIB     zlib             $ZLIB_VERSION
    build_dep $BUILD_BZIP2    bzip2            $BZIP2_VERSION
    build_dep $BUILD_XZ       xz               $XZ_VERSION
    build_dep $BUILD_LIBEDIT  libedit          $LIBEDIT_VERSION
    build_dep $BUILD_SQLITE   sqlite-autoconf  $SQLITE_VERSION
    build_dep $BUILD_OPENSSL  openssl          $OPENSSL_VERSION

    build_python

    # Python modules installed with pip. Built locally if not on Windows.
    command_install_python_modules

    cleanup_install_dir

    # Build the new package.
    make_dist ${PYTHON_BUILD_DIR}

    # Generate a SFTP batch for uploading the package.
    build_publish_dist_sftp_batch
}


# This builds Python's dependencies: libffi, bzip2, openssl, etc.
build_dep() {
    local dep_boolean=$1
    local dep_name=$2
    local dep_version=$3

    if [ $dep_boolean = "yes" ]; then
        # This is where building happens.
        build $dep_name $dep_version
        # If there's something to be done post-build, here's the place.
        if [ $dep_name = "openssl" ]; then
            if [ "${OS%linux*}" = "" ]; then
                # On x64 Linux, OpenSSL installs only to lib64/ sub-dir.
                # More so, under Docker its "make install" fails. To have all
                # libs under lib/, the OpenSSL files are installed manually.
                # '-Wl,-rpath' voodoo is needed to build cryptography with pip.
                export LDFLAGS="-Wl,-rpath,${INSTALL_DIR}/lib/ ${LDFLAGS}"
            fi
            # Needed for building cryptography.
            export CPPFLAGS="${CPPFLAGS:-} -I${INSTALL_DIR}/include"
        fi
    elif [ $dep_boolean = "no" ]; then
        (>&2 echo "    Skip building $dep_name")
    else
        (>&2 echo "Unknown env var for building ${dep_name}. Exiting!")
        exit 248
    fi
}


# This builds Python itself.
build_python() {
    if [ $OS = "win" ]; then
        # Python "build" is a very special case under Windows.
        execute pushd src/Python-Windows
        execute ./chevahbs Python $PYTHON_BUILD_VERSION $INSTALL_DIR
        execute popd
    else
        build Python $PYTHON_BUILD_VERSION
    fi
}

# This gets get-pip.py
download_get_pip() {
    echo "## Downloading get-pip.py... ##"
    if [ ! -e "$BUILD_DIR"/get-pip.py ]; then
        execute $GET_CMD \
            "$BUILD_DIR"/get-pip.py https://bootstrap.pypa.io/get-pip.py
    fi
}


# Compile and install all Python extra libraries.
command_install_python_modules() {
    echo "::group::Install Python modules with pip $PIP_VERSION"
    echo "#### Installing Python modules... ####"

    # Install latest PIP, then instruct it to get exact versions of setuptools.
    # Otherwise, get-pip.py will always try to get latest versions.
    download_get_pip
    echo "# Installing latest pip with preferred setuptools version... #"
    execute $PYTHON_BIN "$BUILD_DIR"/get-pip.py $PIP_ARGS \
        pip==$PIP_VERSION --no-setuptools setuptools==$SETUPTOOLS_VERSION

    # pycparser is installed first as setup_requires is ugly.
    # https://pip.pypa.io/en/stable/reference/pip_install/#controlling-setup-requires
    echo "# Installing pycparser with preferred setuptools version... #"
    execute $PYTHON_BIN -m pip \
        install $PIP_ARGS -U pycparser==$PYCPARSER_VERSION

    if [ $OS = 'win' ]; then
        echo "    Skip makefile updating on Windows"
    else
        echo "# Updating Python config Makefile for newly-built Python... #"
        makefile="$(ls $INSTALL_DIR/lib/$PYTHON_VERSION/config*/Makefile)"
        makefile_orig="${makefile}.orig"

        execute cp $makefile $makefile_orig
        execute sed "s#^prefix=.*#prefix= $INSTALL_DIR#" "$makefile_orig" \
            > "$makefile"
    fi

    for library in $PIP_LIBRARIES ; do
        execute "$PYTHON_BIN" -m pip install $PIP_ARGS $library
    done

    echo "::endgroup::"
}


help_text_test=\
"Run own tests for the newly-build Python distribution."
command_test() {
    local test_file="test_python_binary_dist.py"
    local python_binary="$PYTHON_BIN"
    if [ $OS != 'win' ]; then
        # Post-cleanup, the binary in /bin is named "python", not "python3.x".
        local python_binary="$INSTALL_DIR/bin/python"
    fi

    echo "::group::Chevah tests"
    echo "#### Executing Chevah tests... ####"
    execute cp src/chevah-python-test/$test_file "$BUILD_DIR"
    execute cp src/chevah-python-test/get_binaries_deps.sh "$BUILD_DIR"
    execute pushd "$BUILD_DIR"
    execute $python_binary $test_file
    echo "::endgroup::"

    echo "::group::Security tests"
    echo "## Testing for outdated packages and security issues... ##"
    execute $python_binary -m pip list --outdated --format=columns
    execute $python_binary -m pip install $PIP_ARGS safety=="$SAFETY_VERSION"
    execute $python_binary -m safety check --full-report
    echo "::endgroup::"

    execute popd
}


help_text_compat=\
"Run the test suite from chevah/compat master."
command_compat() {
    local new_python_conf="${PYTHON_BUILD_VERSION}.${PYTHIA_VERSION}"
    execute pushd "$BUILD_DIR"

    # This is quite hackish, as compat is arm-twisted to use the local version.
    echo "::group::Compat tests"
    echo '#### Running chevah's compat tests... ####'
    echo '## Removing any pre-existing compat code... ####'
    execute rm -rf compat/
    execute git clone https://github.com/chevah/compat.git --depth=1 -b master
    execute pushd compat
    # Copy over current pythia stuff, as some changes might require it.
    execute cp ../../pythia.{conf,sh} ./
    # Patch compat to use the newly-built Python, then copy it to cache/.
    echo -e "\nPYTHON_CONFIGURATION=default@${new_python_conf}" >> pythia.conf
    execute mkdir cache
    execute cp -r ../"$PYTHON_BUILD_DIR" cache/
    # Make sure everything is done from scratch in the current dir.
    unset CHEVAH_CACHE CHEVAH_BUILD
    # Some tests might still fail due to causes not related to the new Python.
    execute ./pythia.sh deps
    execute ./pythia.sh test_ci

    execute popd
    echo "::endgroup::"
}


# Launch the whole thing.
select_command $@
