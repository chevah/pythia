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
# * get_agent - download Rexx/Putty distribution in cache
#
# It exports the following environment variables:
# * PYTHONPATH - path to the build directory
# * CHEVAH_PYTHON - name of the python versions
# * CHEVAH_OS - name of the current OS
# * CHEVAH_ARCH - CPU type of the current OS
#
# The build directory is used from CHEVAH_BUILD env,
# then read from brink.conf as CHEVAH_BUILD_DIR,
# and will use a default value if not defined there.
#
# The cache directory is read the CHEVAH_CACHE env,
# and then read from brink.conf as CHEVAH_CACHE_DIR,
# and will use a default value if not defined.
#
# You can define your own `execute_venv` function in brink.conf with the
# command used to execute Python inside the newly virtual environment.
#

# Script initialization.
set -o nounset
set -o errexit
set -o pipefail

# Initialize default value.
COMMAND=${1-''}
DEBUG=${DEBUG-0}

# Set default locale.
# We use C (alias for POSIX) for having a basic default value and
# to make sure we explicitly convert all unicode values.
export LANG='C'
export LANGUAGE='C'
export LC_ALL='C'
export LC_CTYPE='C'
export LC_COLLATE='C'
export LC_MESSAGES='C'
export PATH=$PATH:'/sbin:/usr/sbin:/usr/local/bin'

#
# Global variables.
#
# Used to return non-scalar value from functions.
RESULT=''
WAS_PYTHON_JUST_INSTALLED=0
DIST_FOLDER='dist'

# Path global variables.

# Configuration variable.
CHEVAH_BUILD_DIR=""
# Variale used at runtime.
BUILD_FOLDER=""

# Configuration variable
CHEVAH_CACHE_DIR=
# Varible used at runtime.
CACHE_FOLDER=""

PYTHON_BIN=""
PYTHON_LIB=""
LOCAL_PYTHON_BINARY_DIST=""

# Put default values and create them as global variables.
OS='not-detected-yet'
ARCH='not-detected-yet'

# Initialize default values from brink.conf
PYTHON_CONFIGURATION='NOT-YET-DEFINED'
PYTHON_VERSION='not.defined.yet'
PYTHON_PLATFORM='unknown-os-and-arch'
PYTHON_NAME='python2.7'
BINARY_DIST_URI='https://binary.chevah.com/production'
PIP_INDEX='http://pypi.chevah.com'
BASE_REQUIREMENTS=''

#
# Check that we have a pavement.py file in the current dir.
# If not, we are out of the source's root dir and brink.sh won't work.
#
check_source_folder() {

    if [ ! -e pavement.py ]; then
        (>&2 echo 'No "pavement.py" file found in current folder.')
        (>&2 echo 'Make sure you are running "brink.sh" from a source folder.')
        exit 8
    fi
}

# Called to trigger the entry point in the virtual environment.
# Can be overwritten in brink.conf
execute_venv() {
    ${PYTHON_BIN} $PYTHON3_CHECK -c 'from paver.tasks import main; main()' "$@"
}


# Called to update the dependencies inside the newly created virtual
# environment.
update_venv() {
    set +e
    ${PYTHON_BIN} -c 'from paver.tasks import main; main()' deps
    exit_code=$?
    set -e
    if [ $exit_code -ne 0 ]; then
        (>&2 echo 'Failed to run the initial "./brink.sh deps" command.')
        exit 7
    fi
}

# Load repo specific configuration.
source brink.conf


clean_build() {
    # Shortcut for clear since otherwise it will depend on python
    echo "Removing ${BUILD_FOLDER}..."
    delete_folder ${BUILD_FOLDER}
    echo "Removing dist..."
    delete_folder ${DIST_FOLDER}
    echo "Removing publish..."
    delete_folder 'publish'
    echo "Cleaning pyc files ..."

    # AIX's find complains if there are no matching files when using +.
    [ $(uname) == AIX ] && touch ./dummy_file_for_AIX.pyc
    # Faster than '-exec rm {} \;' and supported in most OS'es,
    # details at http://www.in-ulm.de/~mascheck/various/find/#xargs
    find ./ -name '*.pyc' -exec rm {} +

    # In some case pip hangs with a build folder in temp and
    # will not continue until it is manually removed.
    # On the OSX build server tmp is in $TMPDIR
    if [ ! -z "${TMPDIR-}" ]; then
        # check if TMPDIR is set before trying to clean it.
        rm -rf ${TMPDIR}/pip*
    else
        rm -rf /tmp/pip*
    fi
}


#
# Removes the download/pip cache entries. Must be called before
# building/generating the distribution.
#
purge_cache() {
    clean_build

    echo "Cleaning download cache ..."
    rm -rf $CACHE_FOLDER/*
}


#
# Delete the folder as quickly as possible.
#
delete_folder() {
    local target="$1"
    # On Windows, we use internal command prompt for maximum speed.
    # See: http://stackoverflow.com/a/6208144/539264
    if [ $OS = "win" -a -d $target ]; then
        cmd //c "del /f/s/q $target > nul"
        cmd //c "rmdir /s/q $target"
    else
        rm -rf $target
    fi
}


#
# Wrapper for executing a command and exiting on failure.
#
execute() {
    if [ $DEBUG -ne 0 ]; then
        echo "Executing:" $@
    fi

    # Make sure $@ is called in quotes as otherwise it will not work.
    set +e
    "$@"
    exit_code=$?
    set -e
    if [ $exit_code -ne 0 ]; then
        (>&2 echo "Failed:" $@)
        exit 1
    fi
}

#
# Update global variables with current paths.
#
update_path_variables() {
    resolve_python_version

    if [ "${OS}" = "win" ] ; then
        PYTHON_BIN="/lib/python.exe"
        PYTHON_LIB="/lib/Lib/"
    else
        PYTHON_BIN="/bin/python"
        PYTHON_LIB="/lib/${PYTHON_NAME}/"
    fi

    # Read first from env var.
    set +o nounset
    BUILD_FOLDER="${CHEVAH_BUILD}"
    CACHE_FOLDER="${CHEVAH_CACHE}"
    set -o nounset

    if [ "${BUILD_FOLDER}" = "" ] ; then
        # Use value from configuration file.
        BUILD_FOLDER="${CHEVAH_BUILD_DIR}"
    fi

    if [ "${BUILD_FOLDER}" = "" ] ; then
        # Use default value if not yet defined.
        BUILD_FOLDER="build-${OS}-${ARCH}"
    fi

    if [ "${CACHE_FOLDER}" = "" ] ; then
        # Use default if not yet defined.
        CACHE_FOLDER="${CHEVAH_CACHE_DIR}"
    fi

    if [ "${CACHE_FOLDER}" = "" ] ; then
        # Use default if not yet defined.
        CACHE_FOLDER="cache"
    fi

    PYTHON_BIN="${BUILD_FOLDER}${PYTHON_BIN}"
    PYTHON_LIB="${BUILD_FOLDER}${PYTHON_LIB}"

    LOCAL_PYTHON_BINARY_DIST="$PYTHON_NAME-$OS-$ARCH"

    export PYTHONPATH=${BUILD_FOLDER}
    export CHEVAH_PYTHON=${PYTHON_NAME}
    export CHEVAH_OS=${OS}
    export CHEVAH_ARCH=${ARCH}
    export CHEVAH_CACHE=${CACHE_FOLDER}

}

#
# Called to update the Python version env var based on the platform
# advertised by the current environment.
#
resolve_python_version() {
    local version_configuration=$PYTHON_CONFIGURATION
    local version_configuration_array
    local candidate
    local candidate_platform
    local candidate_version

    PYTHON_PLATFORM="$OS-$ARCH"

    # Using ':' as a delimiter, populate a dedicated array.
    IFS=: read -a version_configuration_array <<< "$version_configuration"
    # Iterate through all the elements of the array to find the best candidate.
    for (( i=0 ; i < ${#version_configuration_array[@]}; i++ )); do
        candidate="${version_configuration_array[$i]}"
        candidate_platform=$(echo "$candidate" | cut -d "@" -f 1)
        candidate_version=$(echo "$candidate" | cut -d "@" -f 2)
        if [ "$candidate_platform" = "default" ]; then
            # On first pass, we set the default version.
            PYTHON_VERSION=$candidate_version
        elif [ "${PYTHON_PLATFORM%$candidate_platform*}" = "" ]; then
            # If matching a specific platform, we overwrite the default version.
            PYTHON_VERSION=$candidate_version
        fi
    done
}


#
# Install base package.
#
install_base_deps() {
    echo "Installing base requirements: $BASE_REQUIREMENTS."
    pip_install "$BASE_REQUIREMENTS"
}


#
# Wrapper for python `pip install` command.
# * $1 - package_name and optional version.
#
pip_install() {
    set +e
    # There is a bug in pip/setuptools when using custom build folders.
    # See https://github.com/pypa/pip/issues/3564
    rm -rf ${BUILD_FOLDER}/pip-build
    ${PYTHON_BIN} -m \
        pip install \
            --trusted-host pypi.chevah.com \
            --trusted-host deag.chevah.com \
            --index-url=$PIP_INDEX \
            --build=${BUILD_FOLDER}/pip-build \
            $1

    exit_code=$?
    set -e
    if [ $exit_code -ne 0 ]; then
        (>&2 echo "Failed to install $1.")
        exit 2
    fi
}

#
# Check for wget or curl and set needed download commands accordingly.
#
set_download_commands() {
    set +o errexit
    command -v wget > /dev/null
    if [ $? -eq 0 ]; then
        # Using WGET for downloading Python package.
        wget --version > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            # This is not GNU Wget, could be the more frugal wget from Busybox.
            DOWNLOAD_CMD="wget"
        else
            # Use 1MB dots to reduce output and avoid polluting Buildbot pages.
            DOWNLOAD_CMD="wget --progress=dot --execute dot_bytes=1m"
        fi
        ONLINETEST_CMD="wget --spider --quiet"
        set -o errexit
        return
    fi
    command -v curl > /dev/null
    if [ $? -eq 0 ]; then
        # Using CURL for downloading Python package.
        DOWNLOAD_CMD="curl --remote-name"
        ONLINETEST_CMD="curl --fail --silent --head --output /dev/null"
        set -o errexit
        return
    fi
    (>&2 echo "Missing wget and curl! One is needed for online operations.")
    exit 3
}

#
# Download and extract a binary distribution.
#
get_binary_dist() {
    local dist_name=$1
    local remote_base_url=$2

    echo "Getting $dist_name from $remote_base_url..."

    tar_gz_file=${dist_name}.tar.gz
    tar_file=${dist_name}.tar

    mkdir -p ${CACHE_FOLDER}
    pushd ${CACHE_FOLDER}

        # Get and extract archive.
        rm -rf $dist_name
        rm -f $tar_gz_file
        rm -f $tar_file
        execute $DOWNLOAD_CMD $remote_base_url/${tar_gz_file}
        execute gunzip $tar_gz_file
        execute tar -xf $tar_file
        rm -f $tar_gz_file
        rm -f $tar_file

    popd
}

#
# Check if we have a versioned Python distribution.
#
test_version_exists() {
    local remote_base_url=$1
    local target_file=python-${PYTHON_VERSION}-${OS}-${ARCH}.tar.gz

    $ONLINETEST_CMD $remote_base_url/${OS}/${ARCH}/$target_file
    return $?
}

#
# Download and extract in cache the python distributable.
#
get_python_dist() {
    local remote_base_url=$1
    local download_mode=$2
    local python_distributable=python-${PYTHON_VERSION}-${OS}-${ARCH}
    local wget_test

    set +o errexit
    test_version_exists $remote_base_url
    wget_test=$?
    set -o errexit

    if [ $wget_test -eq 0 ]; then
        # We have the requested python version.
        get_binary_dist $python_distributable $remote_base_url/${OS}/${ARCH}
    else
        (>&2 echo "Requested version was not found on the remote server.")
        (>&2 echo "$remote_base_url $python_distributable")
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

    local python_distributable="${CACHE_FOLDER}/${LOCAL_PYTHON_BINARY_DIST}"
    local python_installed_version

    COPY_PYTHON_RECURSIONS=`expr $COPY_PYTHON_RECURSIONS + 1`

    if [ $COPY_PYTHON_RECURSIONS -gt 2 ]; then
        (>&2 echo "Too many calls to copy_python: $COPY_PYTHON_RECURSIONS")
        exit 5
    fi

    # Check that python dist was installed
    if [ ! -s ${PYTHON_BIN} ]; then
        # We don't have a Python binary, so we install it since everything
        # else depends on it.
        echo "Bootstrapping ${LOCAL_PYTHON_BINARY_DIST} environment" \
            "to ${BUILD_FOLDER}..."
        mkdir -p ${BUILD_FOLDER}

        if [ -d ${python_distributable} ]; then
            # We have a cached distributable.
            # Check if is at the right version.
            local cache_ver_file
            cache_ver_file=${python_distributable}/lib/PYTHON_PACKAGE_VERSION
            cache_version='UNVERSIONED'
            if [ -f $cache_ver_file ]; then
                cache_version=`cat $cache_ver_file`
            fi
            if [ "$PYTHON_VERSION" != "$cache_version" ]; then
                # We have a different version in the cache.
                # Just remove it and hope that the next step will download
                # the right one.
                rm -rf ${python_distributable}
            fi
        fi

        if [ ! -d ${python_distributable} ]; then
            # We don't have a cached python distributable.
            echo "No ${LOCAL_PYTHON_BINARY_DIST} environment." \
                "Start downloading it..."
            get_python_dist "$BINARY_DIST_URI/python" "strict"
        fi

        echo "Copying Python distribution files... "
        cp -R ${python_distributable}/* ${BUILD_FOLDER}

        install_base_deps
        WAS_PYTHON_JUST_INSTALLED=1
    else
        # We have a Python, but we are not sure if is the right version.
        local version_file=${BUILD_FOLDER}/lib/PYTHON_PACKAGE_VERSION

        if [ -f $version_file ]; then
            # We have a versioned distribution.
            python_installed_version=`cat $version_file`
            if [ "$PYTHON_VERSION" != "$python_installed_version" ]; then
                # We have a different python installed.

                # Check if we have the to-be-updated version and fail if
                # it does not exists.
                set +o errexit
                test_version_exists "$BINARY_DIST_URI/python"
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
                    $python_installed_version to $PYTHON_VERSION
                rm -rf ${BUILD_FOLDER}/*
                rm -rf ${python_distributable}
                copy_python
            fi
        else
            # The installed python has no version.
            set +o errexit
            test_version_exists "$BINARY_DIST_URI/python"
            local test_version=$?
            set -o errexit
            if [ $test_version -eq 0 ]; then
                echo "Updating Python from UNVERSIONED to $PYTHON_VERSION"
                # We have a different python installed.
                # Remove it and try to install it again.
                rm -rf ${BUILD_FOLDER}/*
                rm -rf ${python_distributable}
                copy_python
            else
                echo "Leaving UNVERSIONED Python."
            fi
        fi
    fi

}


#
# Install dependencies after python was just installed.
#
install_dependencies(){

    if [ $WAS_PYTHON_JUST_INSTALLED -ne 1 ]; then
        return
    fi

    if [ "$COMMAND" == "deps" ] ; then
        # Will be installed soon.
        return
    fi

    update_venv
}


#
# Check version of current OS to see if it is supported.
# If it's too old, exit with a nice informative message.
# If it's supported, return through eval the version numbers to be used for
# naming the package, for example: '7' for RHEL 7.7, '2' for Amazon 2,
# '2004' for Ubuntu 20.04', '312' for Alpine Linux 3.12, '11' for Solaris 11.
#
check_os_version() {
    # First parameter should be the human-readable name for the current OS.
    # For example: "Red Hat Enterprise Linux" for RHEL, "macOS" for Darwin etc.
    # Second and third parameters must be strings composed of integers
    # delimited with dots, representing, in order, the oldest version
    # supported for the current OS and the current detected version.
    # The fourth parameter is used to return through eval the relevant numbers
    # for naming the Python package for the current OS, as detailed above.
    local name_fancy="$1"
    local version_good="$2"
    local version_raw="$3"
    local version_chevah="$4"
    local version_constructed=''
    local flag_supported='good_enough'
    local version_raw_array
    local version_good_array

    if [[ $version_raw =~ [^[:digit:]\.] ]]; then
        (>&2 echo "OS version should only have numbers and periods, but:")
        (>&2 echo "    \$version_raw=$version_raw")
        exit 12
    fi

    # Using '.' as a delimiter, populate the version_* arrays.
    IFS=. read -a version_raw_array <<< "$version_raw"
    IFS=. read -a version_good_array <<< "$version_good"

    # Iterate through all the integers from the good version to compare them
    # one by one with the corresponding integers from the supported version.
    for (( i=0 ; i < ${#version_good_array[@]}; i++ )); do
        version_constructed="${version_constructed}${version_raw_array[$i]}"
        if [ ${version_raw_array[$i]} -gt ${version_good_array[$i]} -a \
            "$flag_supported" = 'good_enough' ]; then
            flag_supported='true'
        elif [  ${version_raw_array[$i]} -lt ${version_good_array[$i]} -a \
            "$flag_supported" = 'good_enough' ]; then
            flag_supported='false'
        fi
    done

    if [ "$flag_supported" = 'false' ]; then
        (>&2 echo "Current version of ${name_fancy} is too old: ${version_raw}")
        (>&2 echo "Oldest supported ${name_fancy} version is: ${version_good}")
        if [ "$OS" = "Linux" ]; then
            # For old and/or unsupported Linux distros there's a second chance!
            check_linux_glibc
        else
            exit 13
        fi
    fi

    # The sane way to return fancy values with a bash function is to use eval.
    eval $version_chevah="'$version_constructed'"
}

#
# For old unsupported Linux distros (some with no /etc/os-release) and for other
# unsupported Linux distros (eg. Arch), we check if the system is glibc-based.
# If so, we use a generic code path that builds everything statically,
# including OpenSSL, thus only requiring glibc 2.X, where X differs by arch.
#
check_linux_glibc() {
    local glibc_version
    local glibc_version_array
    local supported_glibc2_version

    # Supported minimum minor glibc 2.X versions for various arches.
    # For x64, we build on CentOS 5.11 (Final) with glibc 2.5.
    # For arm64, we build on Ubuntu 16.04 with glibc 2.23.
    # Beware we haven't normalized arch names yet.
    case "$ARCH" in
        "amd64"|"x86_64"|"x64")
            supported_glibc2_version=5
            ;;
        "aarch64"|"arm64")
            supported_glibc2_version=23
            ;;
    esac

    (>&2 echo -n "Couldn't detect a supported distribution. ")
    (>&2 echo "Trying to treat it as generic Linux...")

    set +o errexit

    command -v ldd > /dev/null
    if [ $? -ne 0 ]; then
        (>&2 echo "No ldd binary found, can't check for glibc!")
        exit 18
    fi

    ldd --version | egrep "GNU\ libc|GLIBC" > /dev/null
    if [ $? -ne 0 ]; then
        (>&2 echo "No glibc reported by ldd... Unsupported Linux libc?")
        exit 19
    fi

    # Tested with glibc 2.5/2.11.3/2.12/2.23/2.28-31 and eglibc 2.13/2.19.
    glibc_version=$(ldd --version | head -n 1 | rev | cut -d\  -f1 | rev)

    if [[ $glibc_version =~ [^[:digit:]\.] ]]; then
        (>&2 echo "Glibc version should only have numbers and periods, but:")
        (>&2 echo "    \$glibc_version=$glibc_version")
        exit 20
    fi

    IFS=. read -a glibc_version_array <<< "$glibc_version"

    if [ ${glibc_version_array[0]} -ne 2 ]; then
        (>&2 echo "Only glibc 2 is supported! Detected version: $glibc_version")
        exit 21
    fi

    # We pass here because:
    #   1. Building python-package should work with an older glibc version.
    #   2. Our generic "lnx" runtime might work with a slightly older glibc 2.
    if [ ${glibc_version_array[1]} -lt ${supported_glibc2_version} ]; then
        (>&2 echo -n "Detected glibc version: ${glibc_version}. Versions older")
        (>&2 echo " than 2.${supported_glibc2_version} were NOT tested!")

    fi

    set -o errexit

    # glibc 2 detected, we set $OS for a generic Linux build.
    OS="lnx"
}

#
# For glibc-based Linux distros, after checking if current version is
# supported with check_os_version(), $OS might already be set to "lnx"
# if current version is too old, through check_linux_glibc().
#
set_os_if_not_generic() {
    local distro_name="$1"
    local distro_version="$2"

    if [ "$OS" != "lnx" ]; then
        OS="${distro_name}${distro_version}"
    fi
}

#
# Detect OS and ARCH for the current system.
# In some cases we normalize or even override ARCH at the end of this function.
#
detect_os() {

    OS=$(uname -s)

    case "$OS" in
        MINGW*|MSYS*)
            ARCH=$(uname -m)
            OS="win"
            ;;
        Linux)
            ARCH=$(uname -m)
            if [ ! -f /etc/os-release ]; then
                # No /etc/os-release file present, so we don't support this
                # distro, but check for glibc, the generic build should work.
                check_linux_glibc
            else
                source /etc/os-release
                linux_distro="$ID"
                distro_fancy_name="$NAME"
                # Some rolling-release distros (eg. Arch Linux) have
                # no VERSION_ID here, so don't count on it unconditionally.
                case "$linux_distro" in
                    rhel|centos)
                        os_version_raw="$VERSION_ID"
                        check_os_version "Red Hat Enterprise Linux" 7 \
                            "$os_version_raw" os_version_chevah
                        set_os_if_not_generic "rhel" $os_version_chevah
                        if [ "$os_version_chevah" -eq 7 ]; then
                            if openssl version | grep -F -q "1.0.1"; then
                                # 7.0-7.3 has OpenSSL 1.0.1, use generic build.
                                check_linux_glibc
                            fi
                        fi
                        ;;
                    amzn)
                        os_version_raw="$VERSION_ID"
                        check_os_version "$distro_fancy_name" 2 \
                            "$os_version_raw" os_version_chevah
                        set_os_if_not_generic "amzn" $os_version_chevah
                        ;;
                    ubuntu|ubuntu-core)
                        os_version_raw="$VERSION_ID"
                        # For versions with older OpenSSL, use generic build.
                        check_os_version "$distro_fancy_name" 18.04 \
                            "$os_version_raw" os_version_chevah
                        # Only LTS versions are supported. If it doesn't end in
                        # 04 or first two digits are uneven, use generic build.
                        if [ ${os_version_chevah%%04} == ${os_version_chevah} \
                            -o $(( ${os_version_chevah:0:2} % 2 )) -ne 0 ]; then
                            check_linux_glibc
                        fi
                        set_os_if_not_generic "ubuntu" $os_version_chevah
                        ;;
                    alpine)
                        os_version_raw="$VERSION_ID"
                        check_os_version "$distro_fancy_name" 3.12 \
                            "$os_version_raw" os_version_chevah
                        set_os_if_not_generic "alpine" $os_version_chevah
                        ;;
                    *)
                        # Unsupported modern distros such as SLES, Debian, etc.
                        check_linux_glibc
                        ;;
                esac
            fi
            ;;
        Darwin)
            ARCH=$(uname -m)
            os_version_raw=$(sw_vers -productVersion)
            # Tested on 10.13, but this works on 10.12 too. Older versions need
            # "-Wl,-no_weak_imports" in LDFLAGS to avoid runtime issues. More
            # details at https://github.com/Homebrew/homebrew-core/issues/3727.
            check_os_version "macOS" 10.12 "$os_version_raw" os_version_chevah
            # Build a generic package to cover all supported versions.
            OS="macos"
            ;;
        FreeBSD)
            ARCH=$(uname -m)
            os_version_raw=$(uname -r | cut -d'.' -f1)
            check_os_version "FreeBSD" 11 "$os_version_raw" os_version_chevah
            OS="fbsd${os_version_chevah}"
            ;;
        OpenBSD)
            ARCH=$(uname -m)
            os_version_raw=$(uname -r)
            check_os_version "OpenBSD" 6.7 "$os_version_raw" os_version_chevah
            OS="obsd${os_version_chevah}"
            ;;
        SunOS)
            ARCH=$(isainfo -n)
            os_version_raw=$(uname -r | cut -d'.' -f2)
            check_os_version "Solaris" 11 "$os_version_raw" os_version_chevah
            OS="sol${os_version_chevah}"
            check_os_version Solaris 11 "$os_version_raw" os_version_chevah
            if [ "$minor_version" -lt 4 ]; then
                (>&2 echo "Unsupported Solaris 11 version, 11.4 needed.")
                exit 15
            fi
            ;;
        *)
            (>&2 echo "Unsupported operating system: ${OS}.")
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
            case "$OS" in
                win)
                    # 32bit build on Windows 2016, 64bit otherwise.
                    # Should work with a l10n pack too (tested with French).
                    win_ver=$(systeminfo.exe | head -n 3 | tail -n 1 \
                        | cut -d ":" -f 2)
                    if [[ "$win_ver" =~ "Microsoft Windows Server 2016" ]]; then
                        ARCH="x86"
                    fi
                    ;;
            esac
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

# Initialize BUILD_ENV_VARS file when building python-package from scratch.
if [ "$COMMAND" == "detect_os" ]; then
    echo "PYTHON_VERSION=$PYTHON_NAME" > BUILD_ENV_VARS
    echo "OS=$OS" >> BUILD_ENV_VARS
    echo "ARCH=$ARCH" >> BUILD_ENV_VARS
    exit 0
fi

if [ "$COMMAND" = "get_python" ] ; then
    OS=$2
    ARCH=$3
    resolve_python_version
    get_python_dist "$BINARY_DIST_URI/python" "fallback"
    exit 0
fi

if [ "$COMMAND" = "get_agent" ] ; then
    get_binary_dist $2 "$BINARY_DIST_URI/agent"
    exit 0
fi

check_source_folder
copy_python
install_dependencies

# Update brink.conf dependencies when running deps.
if [ "$COMMAND" == "deps" ] ; then
    install_base_deps
fi

case $COMMAND in
    test_ci|test_py3)
        PYTHON3_CHECK='-3'
        ;;
    *)
        PYTHON3_CHECK=''
        ;;
esac

set +e
execute_venv "$@"
exit_code=$?
set -e

exit $exit_code
