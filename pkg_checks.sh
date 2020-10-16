#!/usr/bin/env bash
#
# Check for the presence of required packages/commands.
# Install missing ones if possible.
#
# This build requires:
#   * a C compiler, e.g. gcc
#   * build tools: make, m4
#   * patch (for applying patches from src/)
#   * git (for patching Python's version)
#   * automake, libtool, and headers of a curses library (if building libedit)
#   * perl 5.10.0 and Test::More 0.96 (if building OpenSSL)
#   * wget/curl, sha512sum, tar, and unzip for (downloading and unpacking).
#
# On platforms with multiple C compilers, choose by setting CC in os_quirks.sh.

# List of OS packages required for building Python/pyOpenSSL/cryptography etc.
BASE_PKGS="gcc make m4 automake libtool texinfo patch wget tar coreutils unzip"
DPKG_PKGS="$BASE_PKGS git libssl-dev zlib1g-dev libffi-dev libncurses5-dev"
RPM_PKGS="$BASE_PKGS git openssl-devel zlib-devel libffi-devel ncurses-devel"
APK_PKGS="$BASE_PKGS \
    git zlib-dev libffi-dev ncurses-dev linux-headers musl-dev openssl-dev"
# Windows is special, but package management is possible through Chocolatey.
# Curl, sha512sum, and unzip are bundled with MINGW.
CHOCO_PKGS="vcpython27 make"
CHOCO_PRESENT="unknown"

# Check for OS packages required for the build.
missing_packages=""
packages="$CC make m4 git patch wget sha512sum tar unzip"
check_command="command -v"

choco_shim() {
    local pkg=$1
    choco list --local-only --limit-output | grep -iq ^"${pkg}|"
}

case "$OS" in
    rhel*|amzn*)
        packages="$RPM_PKGS"
        check_command="rpm --query"
        ;;
    ubuntu*)
        packages="$DPKG_PKGS"
        check_command="dpkg --status"
        ;;
    alpine*)
        packages="$APK_PKGS"
        check_command="apk info -q -e"
        ;;
    win)
        # The windows build is special.
        echo "## Looking for Chocolatey... ##"
        command -v choco
        if [ $? -eq 0 ]; then
            # Chocolatey is present, let's use it.
            CHOCO_PRESENT="yes"
            packages=$CHOCO_PKGS
            check_command=choco_shim
        else
            packages="make patch curl sha512sum"
        fi
        ;;
    macos)
        # Avoid using Homebrew tools from /usr/local, some break when messing
        # with files there to avoid polluting the build with unwanted deps.
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
        packages="$CC make m4 git patch libtool perl curl shasum tar unzip"
        ;;
    lnx)
        packages="$packages perl"
        ;;
esac

# If $check_command is still "command -v", it's only a check for needed commands.
if [ -n "$packages" ]; then
    for package in $packages ; do
        echo "Checking if $package is available..."
        $check_command $package
        if [ $? -ne 0 ]; then
            echo "Missing required dependency: $package"
            missing_packages="$missing_packages $package"
        fi
    done
fi

if [ -n "$missing_packages" ]; then
    (>&2 echo "Missing required dependencies: $missing_packages.")
    if [ $CHOCO_PRESENT = "yes" ]; then
        echo "## Installing missing Chocolatey packages... ##"
        # No execute here, dotnet3.5's scripts (dep of vcpython27) fail w/ bash.
        choco install --yes $missing_packages
    else
        case "$OS" in
            ubuntu*)
                echo "## Installing missing dpkg packages... ##"
                execute sudo apt install -y $missing_packages
                ;;
            rhel*|amzn*)
                echo "## Installing missing rpm packages... ##"
                execute sudo yum install $missing_packages
                ;;
            alpine*)
                echo "## Installing missing apk packages... ##"
                execute sudo apk add $missing_packages
                ;;
            *)
                (>&2 echo "Don't know how to install missing stuff!")
                exit 149
                ;;
        esac
    fi
fi

if [ -n "$packages" ]; then
    echo "All required dependencies are present: $packages"
fi

# Many systems don't have this installed and it's not really need it.
command -v makeinfo >/dev/null
if [ $? -ne 0 ]; then
    (>&2 echo "Missing makeinfo, trying to link it to /bin/true in ~/bin...")
    execute mkdir -p ~/bin
    execute ln -s /bin/true ~/bin/makeinfo
    export PATH="$PATH:~/bin/"
fi
