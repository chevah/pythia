#!/usr/bin/env bash
# Copyright (c) 2010-2020 Adi Roiban.
# See MIT LICENSE for details.
#
# This file has no version. Documentation is found in this comment.
#
# Helper script for bootstrapping a Python based build system on Unix/Msys.
#
# It is similar with a python-virtualenv but it will not used the local
# Python version and can be used on systems without a local Python.
#
# It will delegate the argument to the execute_venv function,
# with the exception of these commands:
# * clean - remove everything, except cache
# * purge - remove (empty) the cache
# * get_python - download Python distribution in cache
#
# It exports the following environment variables:
# * PYTHONPATH - path to the build directory
# * CHEVAH_PYTHON - name of the python versions
# * CHEVAH_OS - name of the current OS
# * CHEVAH_ARCH - CPU type of the current OS
# * CHEVAH_CACHE - path to the cache directory
# * PIP_INDEX_URL - URL for the used PyPI server.
#
# The build directory is used from CHEVAH_BUILD env,
# then read from pythia.conf as CHEVAH_BUILD_DIR,
# and will use a default value if not defined there.
#
# The cache directory is read the CHEVAH_CACHE env,
# and then read from pythia.conf as CHEVAH_CACHE_DIR,
# and will use a default value if not defined.
#
# You can define your own `execute_venv` function in pythia.conf with the
# command used to execute Python inside the newly virtual environment.
#

# Bash checks
set -o nounset    # always check if variables exist
set -o errexit    # always exit on error
set -o errtrace   # trap errors in functions as well
set -o pipefail   # don't ignore exit codes when piping output

# Initialize default values.
COMMAND=${1-''}
DEBUG=${DEBUG-0}

# Set default locale.
# We use C (alias for POSIX) for having a basic default value and
# to make sure we explicitly convert all unicode values.
export LANG="C"
export LANGUAGE="C"
export LC_ALL="C"
export LC_CTYPE="C"
export LC_COLLATE="C"
export LC_MESSAGES="C"
export PATH="$PATH:/sbin:/usr/sbin:/usr/local/bin"

#
# Global variables.
#
WAS_PYTHON_JUST_INSTALLED=0
DIST_FOLDER="dist"

# Path global variables.

# Configuration variable.
CHEVAH_BUILD_DIR=""
# Variable used at runtime.
BUILD_FOLDER=""

# Configuration variable
CHEVAH_CACHE_DIR=
# Varible used at runtime.
CACHE_FOLDER=""

PYTHON_BIN=""
PYTHON_LIB=""
LOCAL_PYTHON_BINARY_DIST=""

# Put default values and create them as global variables.
OS="not-detected-yet"
ARCH="not-detected-yet"

# Initialize default values, some are overwritten from pythia.conf.
PYTHON_NAME="not.yet.defined"
PYTHON_CONFIGURATION="NOT-YET-DEFINED"
PYTHON_VERSION="not.defined.yet"
PYTHON_PLATFORM="unknown-os-and-arch"
BINARY_DIST_URI="https://github.com/chevah/pythia/releases/download"
PIP_INDEX_URL="https://pypi.org/simple"
# This is defined as an array to be passed as a chain of options.
BASE_REQUIREMENTS=()

#
# Check that we have a pavement.py file in the current dir.
# If not, we are out of the source's root dir and pythia.sh won't work.
#
check_source_folder() {
    if [ ! -e pavement.py ]; then
        (>&2 echo "No 'pavement.py' file found in current folder.")
        (>&2 echo "Make sure you are running 'pythia.sh' from a source folder.")
        exit 8
    fi
}

# Called to trigger the entry point in the virtual environment.
# Can be overwritten in pythia.conf
execute_venv() {
    "$PYTHON_BIN" -c "from paver.tasks import main; main()" "$@"
}


# Called to update the dependencies inside the newly created virtual
# environment.
update_venv() {
    # After updating the python version, the existing pyc files might no
    # longer be valid.
    _clean_pyc

    set +e
    "$PYTHON_BIN" -c "from paver.tasks import main; main()" deps
    exit_code=$?
    set -e
    if [ $exit_code -ne 0 ]; then
        (>&2 echo "Failed to run the initial './pythia.sh deps' command.")
        exit 7
    fi

    set +e
    "$PYTHON_BIN" -c "from paver.tasks import main; main()" build
    exit_code=$?
    set -e
    if [ $exit_code -ne 0 ]; then
        (>&2 echo "Failed to run the initial './pythia.sh build' command.")
        exit 8
    fi
}

# Load repo specific configuration.
source pythia.conf


clean_build() {
    # Shortcut for clear since otherwise it will depend on python
    echo "Removing $BUILD_FOLDER..."
    delete_folder "$BUILD_FOLDER"
    echo "Removing $DIST_FOLDER..."
    delete_folder "$DIST_FOLDER"
    echo "Removing publish/..."
    delete_folder publish/

    # In some case pip hangs with a build folder in temp and
    # will not continue until it is manually removed.
    # On the OSX build server tmp is in $TMPDIR
    if [ -n "${TMPDIR-}" ]; then
        # check if TMPDIR is set before trying to clean it.
        rm -rf "$TMPDIR"/pip*
    else
        rm -rf /tmp/pip*
    fi
}


_clean_pyc() {
    echo "Cleaning pyc files ..."
    # Faster than '-exec rm {} \;' and supported in most OS'es,
    # details at https://www.in-ulm.de/~mascheck/various/find/#xargs
    find ./ -name '*.pyc' -exec rm {} +
}


#
# Removes the download/pip cache entries. Must be called before
# building/generating the distribution.
#
purge_cache() {
    clean_build

    echo "Cleaning download cache ..."
    rm -rf "${CACHE_FOLDER:?}"/*
}


#
# Delete the folder as quickly as possible.
#
delete_folder() {
    local target=$1
    # On Windows, we use internal command prompt for maximum speed.
    # See: https://stackoverflow.com/a/6208144/539264
    if [ "$OS" = "win" ]; then
        if [ -d "$target" ]; then
            cmd //c "del /f/s/q $target > nul"
            cmd //c "rmdir /s/q $target"
        fi
    else
        rm -rf "$target"
    fi
}


#
# Wrapper for executing a command and exiting on failure.
#
execute() {
    if [ "$DEBUG" -ne 0 ]; then
        echo "Executing:" "$@"
    fi

    # Make sure $@ is called in quotes as otherwise it will not work.
    set +e
    "$@"
    exit_code=$?
    set -e
    if [ $exit_code -ne 0 ]; then
        (>&2 echo "Failed:" "$@")
        exit 1
    fi
}

#
# Update global variables with current paths.
#
update_path_variables() {
    resolve_python_version

    if [ "$OS" = "win" ] ; then
        PYTHON_BIN="/lib/python.exe"
        PYTHON_LIB="/lib/Lib/"
    else
        PYTHON_BIN="/bin/python"
        PYTHON_LIB="/lib/$PYTHON_NAME/"
    fi

    # Read first from env var.
    set +o nounset
    BUILD_FOLDER="$CHEVAH_BUILD"
    CACHE_FOLDER="$CHEVAH_CACHE"
    set -o nounset

    if [ -z "$BUILD_FOLDER" ] ; then
        # Use value from configuration file.
        BUILD_FOLDER="$CHEVAH_BUILD_DIR"
    fi

    if [ -z "$BUILD_FOLDER" ] ; then
        # Use default value if not yet defined.
        BUILD_FOLDER="build-$OS-$ARCH"
    fi

    if [ -z "$CACHE_FOLDER" ] ; then
        # Use default if not yet defined.
        CACHE_FOLDER="$CHEVAH_CACHE_DIR"
    fi

    if [ -z "$CACHE_FOLDER" ] ; then
        # Use default if not yet defined.
        CACHE_FOLDER="cache"
    fi

    PYTHON_BIN="$BUILD_FOLDER/$PYTHON_BIN"
    PYTHON_LIB="$BUILD_FOLDER/$PYTHON_LIB"

    LOCAL_PYTHON_BINARY_DIST="$PYTHON_NAME-$OS-$ARCH"

    export PYTHONPATH="$BUILD_FOLDER"
    export CHEVAH_PYTHON="$PYTHON_NAME"
    export CHEVAH_OS="$OS"
    export CHEVAH_ARCH="$ARCH"
    export CHEVAH_CACHE="$CACHE_FOLDER"
    export PIP_INDEX_URL="$PIP_INDEX_URL"

}

#
# Called to update the Python version env var based on the platform
# advertised by the current environment.
#
resolve_python_version() {
    local version_configuration="$PYTHON_CONFIGURATION"
    local version_configuration_array
    local candidate
    local candidate_platform
    local candidate_version

    PYTHON_PLATFORM="$OS-$ARCH"

    # Using ':' as a delimiter, populate a dedicated array.
    IFS=: read -r -a version_configuration_array <<< "$version_configuration"
    # Iterate through all the elements of the array to find the best candidate.
    for (( i=0 ; i < ${#version_configuration_array[@]}; i++ )); do
        candidate="${version_configuration_array[$i]}"
        candidate_platform="$(echo "$candidate" | cut -d"@" -f1)"
        candidate_version="$(echo "$candidate" | cut -d"@" -f2)"
        if [ "$candidate_platform" = "default" ]; then
            # On first pass, we set the default version.
            PYTHON_VERSION="$candidate_version"
        elif [ -z "${PYTHON_PLATFORM%"$candidate_platform"*}" ]; then
            # If matching a specific platform, we overwrite the default version.
            PYTHON_VERSION="$candidate_version"
        fi
    done
}


#
# Install base package.
#
install_base_deps() {
    echo "::groups::Installing base requirements:" "${BASE_REQUIREMENTS[@]}"

    set +e
    # There is a bug in pip/setuptools when using custom build folders.
    # See https://github.com/pypa/pip/issues/3564
    rm -rf "${BUILD_FOLDER:?}"/pip-build
    "$PYTHON_BIN" -m \
        pip install \
            --index-url="$PIP_INDEX_URL" \
            "${BASE_REQUIREMENTS[@]}"

    exit_code=$?

    echo "::endgroup::"

    set -e
    if [ $exit_code -ne 0 ]; then
        (>&2 echo "Failed to install" "${BASE_REQUIREMENTS[@]}")
        exit 2
    fi
}

#
# Check for curl and set needed download commands accordingly.
#
set_download_commands() {
    set +o errexit
    if command -v curl > /dev/null; then
        # Options not used because of no support in older curl versions:
        #     --retry-connrefused (since curl 7.52.0)
        #     --retry-all-errors (since curl 7.71.0)
        # Retry 2 times, allocating 10s for the connection phase,
        # at most 300s for an attempt, sleeping for 5s between retries.
        # Variables wouldn't work when quoted, using Bash arrays instead.
        CURL_RETRY_OPTS=(\
            --retry 2 \
            --connect-timeout 10 \
            --max-time 300 \
            --retry-delay 5 \
            )
        DOWNLOAD_CMD=(curl --remote-name --location "${CURL_RETRY_OPTS[@]}")
        ONLINETEST_CMD=(curl --fail --silent --head "${CURL_RETRY_OPTS[@]}" \
            --output /dev/null)
        set -o errexit
        return
    fi
    (>&2 echo "Missing curl! It is needed for downloading the Python package.")
    exit 3
}

#
# Download and extract a binary distribution.
#
get_binary_dist() {
    local dist_name=$1
    local remote_base_url=$2

    echo "Getting $dist_name from $remote_base_url..."

    tar_gz_file="$dist_name".tar.gz
    tar_file="$dist_name".tar

    mkdir -p "$CACHE_FOLDER"
    pushd "$CACHE_FOLDER"

        # Get and extract archive.
        rm -rf "$dist_name"
        rm -f "$tar_gz_file"
        rm -f "$tar_file"
        execute "${DOWNLOAD_CMD[@]}" "$remote_base_url"/"$tar_gz_file"
        execute gunzip -f "$tar_gz_file"
        execute tar -xf "$tar_file"
        rm -f "$tar_gz_file"
        rm -f "$tar_file"

    popd
}

#
# Check if we have a versioned Python distribution.
#
test_version_exists() {
    local remote_base_url=$1
    local target_file="python-$PYTHON_VERSION-$OS-$ARCH.tar.gz"

    echo "Checking $remote_base_url/$PYTHON_VERSION/$target_file..."
    "${ONLINETEST_CMD[@]}" "$remote_base_url"/"$PYTHON_VERSION"/"$target_file"
    return $?
}

#
# Download and extract in cache the python distributable.
#
get_python_dist() {
    local remote_base_url=$1
    local python_distributable="python-$PYTHON_VERSION-$OS-$ARCH"
    local onlinetest_errorcode

    set +o errexit
    test_version_exists "$remote_base_url"
    onlinetest_errorcode=$?
    set -o errexit

    if [ $onlinetest_errorcode -eq 0 ]; then
        # We have the requested python version.
        get_binary_dist "$python_distributable" \
            "$remote_base_url"/"$PYTHON_VERSION"
    else
        (>&2 echo "Couldn't find package on remote server. Full link:")
        echo "$remote_base_url/$PYTHON_VERSION/$python_distributable.tar.gz"
        exit 4
    fi
}


# copy_python can be called in a recursive way, and this is here to prevent
# accidental infinite loops.
COPY_PYTHON_RECURSIONS=0
#
# Copy python to build folder from binary distribution.
#
copy_python() {
    local python_distributable="$CACHE_FOLDER/$LOCAL_PYTHON_BINARY_DIST"
    local python_installed_version

    COPY_PYTHON_RECURSIONS="$((COPY_PYTHON_RECURSIONS + 1))"

    if [ "$COPY_PYTHON_RECURSIONS" -gt 2 ]; then
        (>&2 echo "Too many calls to copy_python: $COPY_PYTHON_RECURSIONS")
        exit 5
    fi

    # Check that python dist was installed
    if [ ! -s "$PYTHON_BIN" ]; then
        # We don't have a Python binary, so we install it since everything
        # else depends on it.
        echo "::group::Get Python"
        echo "Bootstrapping $LOCAL_PYTHON_BINARY_DIST environment" \
            "to $BUILD_FOLDER..."
        mkdir -p "$BUILD_FOLDER"

        if [ -d "$python_distributable" ]; then
            # We have a cached distributable.
            # Check if is at the right version.
            local cache_ver_file
            cache_ver_file="$python_distributable"/lib/PYTHIA_VERSION
            cache_version="UNVERSIONED"
            if [ -f "$cache_ver_file" ]; then
                cache_version="$(cut -d"-" -f1 < "$cache_ver_file")"
            fi
            if [ "$PYTHON_VERSION" != "$cache_version" ]; then
                # We have a different version in the cache.
                # Just remove it and hope that the next step will download
                # the right one.
                rm -rf "$python_distributable"
            fi
        fi

        if [ ! -d "$python_distributable" ]; then
            # We don't have a cached python distributable.
            echo "No $LOCAL_PYTHON_BINARY_DIST environment." \
                "Start downloading it..."
            get_python_dist "$BINARY_DIST_URI"
        fi

        echo "Copying Python distribution files... "
        cp -R "$python_distributable"/* "$BUILD_FOLDER"

        echo "::endgroup::"

        install_base_deps
        WAS_PYTHON_JUST_INSTALLED=1
    else
        # We have a Python, but we are not sure if is the right version.
        local version_file="$BUILD_FOLDER"/lib/PYTHIA_VERSION

        # If we are upgrading the cache from Python 2,
        # This file is required, so we create it if non-existing.
        touch "$version_file"
        python_installed_version="$(cut -d"-" -f1 < "$version_file")"
        if [ "$PYTHON_VERSION" != "$python_installed_version" ]; then
            # We have a different python installed.
            # Check if we have the to-be-updated version and fail if
            # it does not exists.
            set +o errexit
            test_version_exists "$BINARY_DIST_URI"
            local test_version=$?
            set -o errexit
            if [ $test_version -ne 0 ]; then
                (>&2 echo "The build is now at $python_installed_version.")
                (>&2 echo "Failed to find the required $PYTHON_VERSION.")
                (>&2 echo "Check your configuration or the remote server.")
                exit 6
            fi

            # Remove it and try to install it again.
            echo "Updating Python from" \
                "$python_installed_version to $PYTHON_VERSION"
            rm -rf "${BUILD_FOLDER:?}"/*
            rm -rf "$python_distributable"
            copy_python
        fi
    fi
}


#
# Install dependencies after python was just installed.
#
install_dependencies(){
    if [ "$WAS_PYTHON_JUST_INSTALLED" -ne 1 ]; then
        return
    fi

    update_venv

    # Deps command was just requested.
    # End the process here so that we will not re-run it as part of the
    # general command handling.
    if [ "$COMMAND" = "deps" ] ; then
        exit 0
    fi

}


#
# Check version of current OS to see if it is supported.
# If it's too old, exit with a nice informative message.
# If it's supported, return through eval the version numbers to be used for
# naming the package, e.g.: '12' for FreeBSD 12.x, '114' for Solaris 11.4.
#
check_os_version() {
    # First parameter should be the human-readable name for the current OS.
    # For example: "Solaris" for SunOS ,"macOS" for Darwin, etc.
    # Second and third parameters must be strings composed of integers
    # delimited with dots, representing, in order, the oldest version
    # supported for the current OS and the current detected version.
    # The fourth parameter is used to return through eval the relevant numbers
    # for naming the Python package for the current OS, as detailed above.
    local name_fancy="$1"
    local version_good="$2"
    local version_raw="$3"
    local version_chevah="$4"
    # Version string built in this function, passed back for naming the package.
    # Uses the same number of version sections as the $version_chevah variable,
    # e.g. for FreeBSD it would be "12", even if OS version is actually "12.1".
    local version_built=""
    # If major/minor/patch/etc version sections are the same, it's good enough.
    local flag_supported="good_enough"
    local version_raw_array
    local version_good_array

    if [[ "$version_raw" =~ [^[:digit:]\.] ]]; then
        (>&2 echo "OS version should only have numbers and periods, but:")
        (>&2 echo "    \$version_raw=$version_raw")
        exit 12
    fi

    # Using '.' as a delimiter, populate the version_* arrays.
    IFS=. read -r -a version_raw_array <<< "$version_raw"
    IFS=. read -r -a version_good_array <<< "$version_good"

    # Iterate through all the integers from the good version to compare them
    # one by one with the corresponding integers from the version to check.
    for (( i=0 ; i < ${#version_good_array[@]}; i++ )); do
        version_built="${version_built}${version_raw_array[$i]}"
        # There is nothing to do if versions are the same, that's good enough.
        if [ "${version_raw_array[$i]}" -gt "${version_good_array[$i]}" ]; then
            # First newer version! Comparing more minor versions is irrelevant.
            # Up to now, compared versions were the same, if there were others.
            if [ "$flag_supported" = "good_enough" ]; then
                flag_supported="newer_version"
            fi
        elif [ "${version_raw_array[$i]}" -lt "${version_good_array[$i]}" ];then
            # First older version! Comparing more minor versions is irrelevant.
            # Up to now, compared versions were the same, if there were others.
            if [ "$flag_supported" = "good_enough" ]; then
                flag_supported="false"
            fi
        fi
    done

    # If $flag_supported is "newer_version" or "good_enough" is irrelevant.
    if [ "$flag_supported" = "false" ]; then
        (>&2 echo "Detected version of $name_fancy is: $version_raw.")
        (>&2 echo "For versions older than $name_fancy $version_good,")
        (>&2 echo "there is currently no support.")
        exit 13
    fi

    # The sane way to return fancy values with a Bash function is to use eval.
    eval "$version_chevah"="'$version_built'"
}

#
# On Linux, we check if the system is based on glibc or musl.
# If so, we use a generic code path that builds everything statically,
# including OpenSSL, thus only requiring glibc or musl.
#
check_linux_libc() {
    local ldd_output_file=".chevah_libc_version"
    set +o errexit

    if ! command -v ldd > /dev/null; then
        (>&2 echo "No ldd binary found, can't check for glibc!")
        exit 18
    fi

    ldd --version > "$ldd_output_file" 2>&1
    if grep -E -q "GNU libc|GLIBC" "$ldd_output_file"; then
        check_glibc_version
    else
        if grep -E -q ^"musl libc" $ldd_output_file; then
            check_musl_version
        else
            (>&2 echo "Unknown libc reported by ldd... Unsupported Linux.")
            rm "$ldd_output_file"
            exit 19
        fi
    fi

    set -o errexit
}

check_glibc_version(){
    local glibc_version
    local glibc_version_array
    local supported_glibc2_version

    # Supported minimum minor glibc 2.X versions for various arches.
    # For x64, we build on Amazon 2 with glibc 2.26.
    # For arm64, we used to build on Ubuntu 16.04 with glibc 2.23.
    # Beware we haven't normalized arch names yet.
    case "$ARCH" in
        "amd64"|"x86_64"|"x64")
            supported_glibc2_version=26
            ;;
        "aarch64"|"arm64")
            supported_glibc2_version=23
            ;;
        *)
            (>&2 echo "$ARCH is an unsupported arch for generic Linux!")
            exit 17
            ;;
    esac

    echo "No specific runtime for the current distribution / version / arch."
    echo "Minimum glibc version for this arch: 2.$supported_glibc2_version."

    # Tested with glibc 2.5/2.11.3/2.12/2.23/2.28-35 and eglibc 2.13/2.19.
    glibc_version="$(head -n 1 "$ldd_output_file" | rev | cut -d" " -f1 | rev)"
    rm "$ldd_output_file"

    if [[ "$glibc_version" =~ [^[:digit:]\.] ]]; then
        (>&2 echo "Glibc version should only have numbers and periods, but:")
        (>&2 echo "    \$glibc_version=$glibc_version")
        exit 20
    fi

    IFS=. read -r -a glibc_version_array <<< "$glibc_version"

    if [ "${glibc_version_array[0]}" -ne 2 ]; then
        (>&2 echo "Only glibc 2 is supported! Detected version: $glibc_version")
        exit 21
    fi

    # Decrement supported_glibc2_version above if building against older glibc.
    if [ "${glibc_version_array[1]}" -lt "$supported_glibc2_version" ]; then
        (>&2 echo "NOT good. Detected version is older: $glibc_version!")
        exit 22
    else
        echo "All is good. Detected glibc version: $glibc_version."
    fi

    # Supported glibc version detected, set $OS for a generic glibc Linux build.
    OS="linux"
}

check_musl_version(){
    local musl_version
    local musl_version_array
    local musl_version_unsupported="false"
    local supported_musl11_version=24

    echo "No specific runtime for the current distribution / version / arch."
    echo "Minimum musl version for this arch: 1.1.$supported_musl11_version."

    # Tested with musl 1.1.24/1.2.2.
    musl_version="$(grep -E ^"Version" "$ldd_output_file" | cut -d" " -f2)"
    rm "$ldd_output_file"

    if [[ "$musl_version" =~ [^[:digit:]\.] ]]; then
        (>&2 echo "Musl version should only have numbers and periods, but:")
        (>&2 echo "    \$musl_version=$musl_version")
        exit 25
    fi

    IFS=. read -r -a musl_version_array <<< "$musl_version"

    # Decrement supported_musl11_version above if building against older musl.
    if [ "${musl_version_array[0]}" -lt 1 ]; then
        musl_version_unsupported="true"
    elif [ "${musl_version_array[0]}" -eq 1 ]; then      
        if [ "${musl_version_array[1]}" -lt 1 ];then
            musl_version_unsupported="true"
        elif [ "${musl_version_array[1]}" -eq 1 ];then
            if [ "${musl_version_array[2]}" -lt "$supported_musl11_version" ]
            then
                (>&2 echo "NOT good. Detected version is older: $musl_version!")
                exit 27
            fi
        fi
    fi

    if [ "$musl_version_unsupported" = "true" ]; then
        (>&2 echo "Only musl 1.1 or greater supported! Detected: $musl_version")
        exit 26
    fi

    echo "All is good. Detected musl version: $musl_version."

    # Supported musl version detected, set $OS for a generic musl Linux build.
    OS="linux_musl"
}


#
# Detect OS and ARCH for the current system.
# In some cases we normalize or even override ARCH at the end of this function.
#
detect_os() {
    os_version_chevah=""
    OS="$(uname -s)"

    case "$OS" in
        MINGW*|MSYS*)
            ARCH="$(uname -m)"
            OS="win"
            ;;
        Linux)
            ARCH="$(uname -m)"
            check_linux_libc
            ;;
        Darwin)
            ARCH="$(uname -m)"
            os_version_raw="$(sw_vers -productVersion)"
            check_os_version "macOS" 10.13 "$os_version_raw" os_version_chevah
            # Build a generic package to cover all supported versions.
            OS="macos"
            ;;
        FreeBSD)
            ARCH="$(uname -m)"
            os_version_raw="$(uname -r | cut -d'.' -f1)"
            check_os_version "FreeBSD" 12 "$os_version_raw" os_version_chevah
            OS="fbsd$os_version_chevah"
            ;;
        OpenBSD)
            ARCH="$(uname -m)"
            os_version_raw="$(uname -r)"
            check_os_version "OpenBSD" 6.7 "$os_version_raw" os_version_chevah
            OS="obsd$os_version_chevah"
            ;;
        SunOS)
            ARCH="$(isainfo -n)"
            ver_major="$(uname -r | cut -d"." -f2)"
            case $ver_major in
                11)
                    ver_minor="$(uname -v | cut -d"." -f2)"
                    ;;
                *)
                    # Note $ver_minor detection doesn't work on older versions.
                    (>&2 echo "Unsupported Solaris version: $ver_major.")
                    exit 15
                    ;;
            esac
            os_version_raw="$ver_major.$ver_minor"
            check_os_version "Solaris" 11.4 "$os_version_raw" os_version_chevah
            OS="sol$os_version_chevah"
            ;;
        *)
            (>&2 echo "Unsupported operating system: $OS.")
            exit 14
            ;;
    esac

    # Normalize arch names. Force 32bit builds on some OS'es.
    case "$ARCH" in
        "i386"|"i686")
            ARCH="x86"
            ;;
        "amd64"|"x86_64")
            ARCH="x64"
            ;;
        "aarch64")
            ARCH="arm64"
            ;;
    esac
}

detect_os
update_path_variables
set_download_commands

if [ "$COMMAND" = "clean" ] ; then
    clean_build
    exit 0
fi

if [ "$COMMAND" = "purge" ] ; then
    purge_cache
    exit 0
fi

# Pass OS-specific values through a file when building Python from scratch.
if [ "$COMMAND" = "detect_os" ]; then
    echo "PYTHON_VERSION=$PYTHON_NAME" > BUILD_ENV_VARS
    echo "OS=$OS" >> BUILD_ENV_VARS
    echo "ARCH=$ARCH" >> BUILD_ENV_VARS
    exit 0
fi

if [ "$COMMAND" = "get_python" ] ; then
    OS=$2
    ARCH=$3
    resolve_python_version
    get_python_dist "$BINARY_DIST_URI"
    exit 0
fi

check_source_folder
copy_python
install_dependencies

# Update pythia.conf dependencies when running deps.
if [ "$COMMAND" = "deps" ] ; then
    install_base_deps
fi

set +e
execute_venv "$@"
exit_code=$?
set -e

exit $exit_code
