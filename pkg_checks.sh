#!/usr/bin/env bash
#
# Check for the presence of required packages/commands.
#
# This build requires:
#   * a C compiler, e.g. gcc
#   * build tools: make, m4
#   * patch (for applying patches from src/)
#   * git (for patching Python's version, if actually building it)
#   * automake, libtool, headers of a curses library (if building libedit)
#   * perl 5.10.0 or newer, Test::More 0.96 or newer (if building OpenSSL)
#   * curl, sha512sum, tar, unzip (for downloading and unpacking)
#
# On platforms with multiple C compilers, choose by setting CC in os_quirks.sh.

# List of OS packages required for building Python/pyOpenSSL/cryptography etc.
BASE_PKGS="gcc make m4 automake libtool patch unzip"
DEB_PKGS="$BASE_PKGS tar diffutils \
    git zlib1g-dev liblzma-dev libffi-dev libncurses5-dev libssl-dev"
RPM_PKGS="$BASE_PKGS tar diffutils \
    git-core libffi-devel zlib-devel xz-devel ncurses-devel openssl-devel"

# Check for OS packages required for the build.
MISSING_PACKAGES=""
PACKAGES="$CC make m4 git patch curl sha512sum tar unzip"
# This is defined as an array of commands and opts, to allow it to be quoted.
CHECK_CMD=(command -v)

# $CHECK_CMD should exit with 0 only when checked packages is installed.
case "$OS" in
    rhel*|amzn*)
        PACKAGES="$RPM_PKGS"
        CHECK_CMD=(rpm --query)
        ;;
    ubuntu*)
        PACKAGES="$DEB_PKGS"
        CHECK_CMD=(dpkg --status)
        ;;
    win)
        PACKAGES="curl sha512sum"
        ;;
    macos)
        # Avoid using Homebrew tools from /usr/local. It is also needed to mess
        # with libs there to avoid polluting the build with unwanted deps.
        # See the macOS jobs in the "bare" GitHub Actions workflow for details.
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
        PACKAGES="$PACKAGES perl"
        ;;
esac

# External checks with various exit codes are checked below.
set +o errexit

# If $CHECK_CMD is still (command -v), it's only a check for needed commands.
if [ -n "$PACKAGES" ]; then
    for package in $PACKAGES ; do
        echo "Checking if $package is available..."
        "${CHECK_CMD[@]}" $package
        if [ $? -ne 0 ]; then
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
if [ "$OS" = "win" ]; then
    set -o errexit
    return
fi

# Many systems don't have this installed and it's not really need it.
command -v makeinfo >/dev/null
if [ $? -ne 0 ]; then
    (>&2 echo "# Missing makeinfo, linking it to /bin/true in ~/bin... #")
    execute mkdir -p ~/bin
    execute rm -f ~/bin/makeinfo
    execute ln -s /bin/true ~/bin/makeinfo
    export PATH="$PATH:~/bin/"
fi

# This script is sourced, execution does not end here.
set -o errexit
