#!/usr/bin/env bash
#
# Check for the presence of required packages/commands.
# If possible, install missing ones.
#
# This build requires:
#   * a C compiler, e.g. gcc
#   * build tools: make, m4
#   * patch (for applying patches from src/)
#   * git (for patching Python's version, if building it)
#   * automake, libtool, and headers of a curses library (if building libedit)
#   * perl 5.10.0 and Test::More 0.96 (if building OpenSSL)
#   * wget/curl, sha512sum, tar, and unzip (for downloading and unpacking).
#
# On platforms with multiple C compilers, choose by setting CC in os_quirks.sh.

# List of OS packages required for building Python/pyOpenSSL/cryptography etc.
BASE_PKGS="gcc make m4 automake libtool texinfo patch wget tar coreutils unzip"
DPKG_PKGS="$BASE_PKGS \
    git libssl-dev zlib1g-dev libffi-dev libncurses5-dev liblzma-dev"
RPM_PKGS="$BASE_PKGS git openssl-devel zlib-devel libffi-devel ncurses-devel"
# Alpine uses by default the ersatz wget/tar/sha51sum binaries from Busybox.
APK_PKGS="gcc make m4 automake libtool texinfo patch unzip \
    git zlib-dev libffi-dev ncurses-dev linux-headers musl-dev openssl-dev"
# Windows is special, but package management is possible through Chocolatey.
# Curl, sha512sum, and unzip are bundled with MINGW.
CHOCO_PKGS="vcpython27 make"
CHOCO_PRESENT="unknown"

# Check for OS packages required for the build.
MISSING_PACKAGES=""
PACKAGES="$CC make m4 git patch wget sha512sum tar unzip"
CHECK_CMD="command -v"

choco_shim() {
    local pkg=$1
    choco list --local-only --limit-output | grep -iq ^"${pkg}|"
}

# $CHECK_CMD should exit with 0 only when checked packages is installed.
case "$OS" in
    rhel*|amzn*)
        PACKAGES="$RPM_PKGS"
        CHECK_CMD="rpm --query"
        ;;
    ubuntu*)
        PACKAGES="$DPKG_PKGS"
        CHECK_CMD="dpkg --status"
        ;;
    alpine*)
        PACKAGES="$APK_PKGS"
        CHECK_CMD="apk info -q -e"
        ;;
    win)
        # The windows build is special.
        echo "## Looking for Chocolatey... ##"
        command -v choco
        if [ $? -eq 0 ]; then
            # Chocolatey is present, let's use it.
            CHOCO_PRESENT="yes"
            PACKAGES=$CHOCO_PKGS
            CHECK_CMD=choco_shim
        else
            PACKAGES="make curl sha512sum"
        fi
        ;;
    macos)
        # Avoid using Homebrew tools from /usr/local, some break when messing
        # with libs there to avoid polluting the build with unwanted deps.
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
        PACKAGES="$CC make m4 git patch libtool perl curl shasum tar unzip"
        ;;
    lnx)
        PACKAGES="$PACKAGES perl"
        ;;
esac

# If $CHECK_CMD is still "command -v", it's only a check for needed commands.
if [ -n "$PACKAGES" ]; then
    for package in $PACKAGES ; do
        echo "Checking if $package is available..."
        $CHECK_CMD $package
        if [ $? -ne 0 ]; then
            echo "Missing required dependency: $package"
            MISSING_PACKAGES="$MISSING_PACKAGES $package"
        fi
    done
fi

if [ -n "$MISSING_PACKAGES" ]; then
    (>&2 echo "Missing required dependencies: $MISSING_PACKAGES.")
    if [ $CHOCO_PRESENT = "yes" ]; then
        echo "## Installing missing Chocolatey packages... ##"
        # No execute here, dotnet3.5's scripts (dep of vcpython27) fail w/ bash.
        choco install --yes $MISSING_PACKAGES
    else
        case "$OS" in
            ubuntu*)
                echo "## Installing missing dpkg packages... ##"
                execute sudo apt install -y $MISSING_PACKAGES
                ;;
            rhel*|amzn*)
                echo "## Installing missing rpm packages... ##"
                execute sudo yum install $MISSING_PACKAGES
                ;;
            alpine*)
                echo "## Installing missing apk packages... ##"
                execute sudo apk add $MISSING_PACKAGES
                ;;
            *)
                (>&2 echo "Don't know how to install missing dependencies.")
                exit 149
                ;;
        esac
    fi
fi

if [ -n "$PACKAGES" ]; then
    echo "All required dependencies are present: $PACKAGES"
fi

# Many systems don't have this installed and it's not really need it.
command -v makeinfo >/dev/null
if [ $? -ne 0 ]; then
    (>&2 echo "Missing makeinfo, trying to link it to /bin/true in ~/bin...")
    execute mkdir -p ~/bin
    execute ln -s /bin/true ~/bin/makeinfo
    export PATH="$PATH:~/bin/"
fi
