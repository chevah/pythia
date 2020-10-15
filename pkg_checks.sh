#!/usr/bin/env bash
#
# Checks for required packages.

# List of OS packages required for building Python/pyOpenSSL/cryptography etc.
# Check for the presence of required packages/commands. This build requires:
#   * a C compiler, e.g. gcc
#   * build tools: make, m4
#   * patch (for applying our own patches)
#   * git (for patching Python's version)
#   * automake, libtool, and headers of a curses library (if building libedit)
#   * perl 5.10.0 and Test::More 0.96 (if building OpenSSL).
# On platforms with multiple C compilers, choose by setting CC in os_quirks.sh.
COMMON_PKGS="gcc make m4 automake libtool texinfo patch"
DEBIAN_PKGS="$COMMON_PKGS git libssl-dev zlib1g-dev libffi-dev libncurses5-dev"
RHEL_PKGS="$COMMON_PKGS git openssl-devel zlib-devel libffi-devel ncurses-devel"
ALPINE_COMMON_PKGS="$COMMON_PKGS\
    git zlib-dev libffi-dev ncurses-dev linux-headers musl-dev openssl-dev"
# Windows is special, but package management is possible through Chocolatey.
# Chocolatey's git package comes with patch, and curl is bundled with MINGW.
CHOCO_PKGS="vcpython27 make git"
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
    ubuntu*)
        # Debian-derived distros are similar in this regard.
        packages="$DEBIAN_PKGS"
        check_command="dpkg --status"
        ;;
    rhel*|amzn*)
        packages="$RHEL_PKGS"
        check_command="rpm --query"
        ;;
    alpine*)
        # Alpine 3.9 switched back to OpenSSL as default.
        packages="$ALPINE_OPENSSL_PKGS"
        check_command="apk info -q -e"
        ;;
    # On remaining OS'es, just check for some of the needed commands.
    macos)
        packages="$CC make m4 git patch libtool perl curl shasum tar unzip"
        ;;
    lnx)
        packages="$packages perl"
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
            packages="make git patch curl sha512sum"
        fi
        ;;
esac

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
        exit 149
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
