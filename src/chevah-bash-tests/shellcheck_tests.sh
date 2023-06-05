#!/usr/bin/env bash
#
# Script for checking all shell scripts in this repo with Shellcheck.
# Not to be executed independently, it's sourced during the 'test' phase.

if [ "$OS" = "win" ]; then
    echo "Shellcheck not supported on Windows, skipping!"
    exit
fi

if [ "$ARCH" = "arm64" ]; then
    echo "Shellcheck not supported on Apple Silicon, skipping!"
    exit
fi

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
echo "Checking executable shell scripts, including their sources:"
for exec_sh_file in "${exec_sh_files[@]}"; do
    echo -e "\t$exec_sh_file"
done
execute "$BUILD_DIR"/shellcheck -ax "${exec_sh_files[@]}"
echo "Skipping non-executable shell scripts (should be sourced by the above):"
for other_sh_file in "${other_sh_files[@]}"; do
    echo -e "\t$other_sh_file"
done

echo "## Checking extra .sh files in ./src/, including sources... ##"
extra_scripts=()
# Do not use mapfile, needs Bash 4. See https://www.shellcheck.net/wiki/SC2207.
while IFS="" read -r line; do
    extra_scripts+=("$line")
done < <(find ./src/ -name '*.sh')
echo "Extra .sh scripts found in ./src/:"
for extra_script in "${extra_scripts[@]}"; do
    echo -e "\t$extra_script"
done
execute "$BUILD_DIR"/shellcheck -ax "${extra_scripts[@]}"
echo "## Checking the chevahbs scripts in ./src/*/ sub-dirs in their dirs... ##"
for src_dir in ./src/*; do
    case "$src_dir" in
        *tests)
            # These dirs don't have chevahbs files.
            echo -e "\tSkipping $src_dir!"
            ;;
        *)
            # chevahbs uses relative paths, must be checked locally.
            execute pushd "$src_dir"
            execute ../../"$BUILD_DIR"/shellcheck -x chevahbs
            execute popd
            ;;
    esac
done
