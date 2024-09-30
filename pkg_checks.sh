#!/usr/bin/env bash
#
# Check for the presence of required packages/commands.
#
# This build requires:
#   * a C compiler, e.g. gcc (if there is stuff to build, e.g. not on Windows)
#   * build tools: make, m4 (same as above)
#   * patch (for applying patches from src/, these can be hotfixes to .py files)
#   * git (for patching Python's version, if building Python)
#   * a C++ compiler for testing Python C++ extensions (test_cppext).
#   * automake, libtool, headers of a curses library (if building libedit)
#   * perl 5.10.0 or newer, Test::More 0.96 or newer (if building OpenSSL)
#   * curl, sha512sum, tar, unzip (for downloading and unpacking)
#
# On platforms with multiple C compilers, choose by setting CC in os_quirks.sh.

# List of OS packages required for building Python/pyOpenSSL/cryptography etc.
BASE_PKGS="gcc make m4 patch unzip perl"
if [ "$BUILD_LIBEDIT" = "yes" ]; then
    BASE_PKGS="$BASE_PKGS automake libtool"
fi
APK_PKGS="$BASE_PKGS git curl bash musl-dev linux-headers lddtree \
    openssh-client file unzip g++ musl-locales dejagnu"
DEB_PKGS="$BASE_PKGS tar diffutils git curl \
    openssh-client libtest-simple-perl xz-utils g++ dejagnu"
RPM_PKGS="$BASE_PKGS tar diffutils git-core curl \
    openssh-clients perl-Test-Simple perl-IPC-Cmd xz gcc-c++ dejagnu"

# Check for OS packages required for the build.
MISSING_PACKAGES=""
# Generic list of required commands (not an array because it's never executed).
PACKAGES="$CC make m4 git patch curl sha512sum tar unzip"
# This is defined as an array of commands and opts, to allow it to be quoted.
CHECK_CMD=(command -v)

# $CHECK_CMD should exit with 0 only when checked package is installed.
case "$OS" in
    windows)
        # Nothing to actually build on Windows.
        PACKAGES="curl sha512sum"
        ;;
    macos)
        # Avoid using Homebrew tools from /usr/local. It is also needed to neuter
        # /usr/local libs to avoid polluting the build with unwanted deps.
        # See the macOS job in the "bare" GitHub Actions workflow for details.
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
        PACKAGES="$CC make m4 git patch libtool perl curl shasum tar unzip"
        ;;
    fbsd*)
        PACKAGES="$CC make m4 git patch libtool curl shasum tar unzip"
        ;;
    obsd*)
        PACKAGES="$CC make m4 git patch libtool curl sha512 tar unzip"
        ;;
    linux*)
        if [ -x /sbin/apk ]; then
            # Assumes Alpine Linux 3.12.
            CHECK_CMD=(apk info -q -e)
            PACKAGES="$APK_PKGS"
        elif [ -x /usr/bin/dpkg ]; then
            # Assumes Ubuntu Linux 16.04.
            CHECK_CMD=(dpkg --status)
            PACKAGES="$DEB_PKGS"
        elif [ -x /usr/bin/rpm ]; then
            # Assumes Amazon Linux 2.
            CHECK_CMD=(rpm --query)
            PACKAGES="$RPM_PKGS"
        else
            PACKAGES="$PACKAGES perl"
        fi
        ;;
esac

# External checks with various exit codes are checked below.
set +o errexit

# If $CHECK_CMD is still "(command -v)", it's only a check for needed commands.
if [ -n "$PACKAGES" ]; then
    for package in $PACKAGES ; do
        echo "Checking if $package is available..."
        if ! "${CHECK_CMD[@]}" "$package"; then
            echo "Missing required dependency: $package"
            MISSING_PACKAGES="$MISSING_PACKAGES $package"
        fi
    done
fi

if [ -n "$MISSING_PACKAGES" ]; then
    (>&2 echo "Missing required dependencies: $MISSING_PACKAGES.")
    exit 149
fi

if [ -n "$PACKAGES" ]; then
    echo "All required dependencies are present: $PACKAGES"
fi

# Windows "build" is special, following checks are for other platforms.
if [ "$OS" = "windows" ]; then
    set -o errexit
    return
fi

# Many systems don't have this installed and it's not really need it.
if ! command -v makeinfo >/dev/null; then
    (>&2 echo "# Missing makeinfo, linking it to /bin/true in ~/bin... #")
    execute mkdir -p ~/bin
    execute rm -f ~/bin/makeinfo
    execute ln -s /bin/true ~/bin/makeinfo
    export PATH="$PATH:~/bin/"
fi

# To avoid having Python's uuid module linked to system libs.
echo "# Checking if it's possible to avoid linking to system uuid libs... #"
case "$OS" in
    ubuntu*)
        "${CHECK_CMD[@]}" uuid-dev \
            && echo "To not link to uuid libs, run: apt remove -y uuid-dev"
        ;;
    rhel*|amzn*)
        "${CHECK_CMD[@]}" libuuid-devel \
            && echo -n "To not link to uuid libs, run: " \
            && echo "yum remove -y e2fsprogs-devel libuuid-devel"
        ;;
    *)
        (>&2 echo "Not guarding against linking to uuid libs on this system!")
        ;;
esac

# This script is sourced, execution does not end here.
set -o errexit
