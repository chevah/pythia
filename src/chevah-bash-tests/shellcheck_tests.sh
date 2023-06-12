#!/usr/bin/env bash
#
# Script for checking all shell scripts in this repo with Shellcheck.
# Available independently of all other scripts, except the common functions.sh.
# To be executed from the root of the repository.

# Bash checks
set -o nounset    # always check if variables exist
set -o errexit    # always exit on error
set -o errtrace   # trap errors in functions as well
set -o pipefail   # don't ignore exit codes when piping output

source ./functions.sh

# BUILD_DIR is also defined in build.conf.
BUILD_DIR="build"
OS="$(uname)"
ARCH="$(uname -m)"

case "$OS" in
        MINGW*|MSYS*)
            echo "Shellcheck not supported on Windows, skipping!"
            exit
            ;;
        Darwin)
            if [ "$ARCH" = "arm64" ]; then
                echo "Shellcheck not supported on Apple Silicon, skipping!"
                exit
            fi
            ;;
esac

echo "## Getting shellcheck binary in $BUILD_DIR/ if missing... ##"
execute ./src/chevah-bash-tests/get-shellcheck.sh "$BUILD_DIR"

echo "## Checking executable .sh files in the root dir of the repo... ##"
exec_sh_files=()
other_sh_files=()
for sh_file in ./*.sh; do
    if [ -x "$sh_file" ]; then
        exec_sh_files=("${exec_sh_files[@]}" "$sh_file")
    else
        other_sh_files=("${other_sh_files[@]}" "$sh_file")
    fi
done
echo "Executable shell scripts to be checked (including their sources):"
for exec_sh_file in "${exec_sh_files[@]}"; do
    echo -e "\t$exec_sh_file"
done
execute "$BUILD_DIR"/shellcheck -ax "${exec_sh_files[@]}"
echo "Non-executable scripts to be skipped (should be sourced by the above):"
for other_sh_file in "${other_sh_files[@]}"; do
    echo -e "\t$other_sh_file"
done

echo "## Checking extra .sh files in \"./src/\"... ##"
extra_scripts=()
# Do not use mapfile, needs Bash 4. See https://www.shellcheck.net/wiki/SC2207.
while IFS="" read -r line; do
    extra_scripts+=("$line")
done < <(find ./src -name '*.sh')
echo "Extra shell scripts to be checked under ./src (including sources):"
for extra_script in "${extra_scripts[@]}"; do
    echo -e "\t$extra_script"
done
execute "$BUILD_DIR"/shellcheck -ax "${extra_scripts[@]}"

echo "## Checking the chevahbs scripts in ./src/*/ sub-dirs in their dirs... ##"
echo "chevahbs files to be checked were found in the following sub-dirs:"
for src_dir in ./src/*; do
    if [ -d "$src_dir" ]; then
        if [ -e "$src_dir"/chevahbs ]; then
            echo -e "\t$src_dir"
            # chevahbs uses relative paths, must be checked from the same dir.
            execute cd "$src_dir"
            execute ../../"$BUILD_DIR"/shellcheck -x chevahbs
            execute cd ../../
        fi
    fi
done
