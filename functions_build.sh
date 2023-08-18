#!/usr/bin/env bash
#
# Pythia-specific build functions.

# Global variables.
COMMAND=""
OS=""
INSTALL_DIR=""

#
# Chevah Build Script command selection.
#
select_chevahbs_command() {
    if [ "$DEBUG" -ne 0 ]; then
        echo "select_chevahbs_command:" "$@"
    fi
    COMMAND="$1"
    OS="$2"
    INSTALL_DIR="$3"
    # Shift first 3 arguments, remaining ones are passed along as $@.
    shift 3

    chevahbs_command="chevahbs_$COMMAND"
    if type "$chevahbs_command" &> /dev/null; then
        "$chevahbs_command" "$@"
    else
        (>&2 echo "Don't know what to do with command: $COMMAND.")
        exit 90
    fi
}


#
# Internal function for downloading sources on-the-fly as needed.
#
download_sources(){
    local project_name="$1"
    local project_ver="$2"
    local link="$3"
    local archive_ext="$4"
    # Sometimes the archive is not named $name-$version.$ext, let's force it.
    local archive_filename="$project_name-$project_ver.$archive_ext"
    # Only download the sources if they are not present.
    if [ ! -e "$archive_filename" ]; then
        echo "## Downloading $project_name version $project_ver... ##"
        execute  "${GET_CMD[@]}" "$archive_filename" "$link"
    else
        echo -e "\t$archive_filename already present, not downloading again."
    fi

    echo "## Verifying checksums for $archive_filename... ##"
    execute "${SHA_CMD[@]}" sha512.sum

    # Current dir is src/$project_name, and sources have full hierarchy.
    # So far, all upstream archives respected the $name-$version convention
    # for the name of the root directory in the archive.
    case "$archive_ext" in
        tar.gz|tgz)
            echo "## Unpacking archive $archive_filename... ##"
            execute "${TAR_CMD[@]}" "$archive_filename" -C ../../build/
            ;;
        zip)
            echo "## Unpacking archive $archive_filename... ##"
            execute "${ZIP_CMD[@]}" "$archive_filename" -d ../../build/
            ;;
        exe|amd64*)
            # No need to use ../../build/"$project_name"-"$project_ver"/ here.
            echo -e "\tNothing to unpack in build/ for $archive_filename."
            ;;
        *)
            (>&2 echo "Unknown archive type for $archive_filename, exiting!")
            exit 89
            ;;
    esac
}


#
# Internal function for calling build script on each source.
#
chevahbs_build() {
    if [ -n "$(type -t chevahbs_patch)" ]; then
        # Looks like the chevahbs script has patches to apply.
        echo "## Patching... ##"
        chevahbs_patch "$@"
    fi
    echo "## Configuring... ##"
    chevahbs_configure "$@"
    echo "## Compiling... ##"
    chevahbs_compile "$@"
}

chevahbs_test() {
    chevahbs_try "$@"
}

chevahbs_install() {
    chevahbs_cp "$@"
}

#
# Build-related stuff.
#
build() {
    # First parameter can be "libffi", "zlib", "bzip", "Python", etc.
    # It's a sub-dir in src/ containing chevahbs scripts / checksums / patches.
    # Also used when downloading the gzipped tarball and unpacking it.
    project_name="$1"
    # Second parameter has the form: "3.2.1", "1.1.1t", "3410200", etc.
    project_ver="$2"
    echo "::group::" "$1 $2" "build"
    echo "#### Building $1 version $2... ####"

    # This is where sources are unpacked, patched, and built.
    version_dir="$1-$2"
    own_build_dir="$BUILD_DIR/$version_dir"

    # This is were the builds are installed.
    install_dir="$PWD/$BUILD_DIR/$PYTHON_BUILD_DIR"
    # Whole build/ sub-dir should be cleared already, let's make sure.
    echo "## Removing $own_build_dir if existing... ##"
    execute rm -rf "$own_build_dir"

    # Downloads happen in src/ to not get lost when wiping the build/ dir.
    echo "## Downloading in src/$project_name... ##"
    execute pushd "src/$project_name"
    # Go through local project's chevahbs to pick up the link and come back
    # in download_sources() to get the sources, check them, and unpack.
    execute ./chevahbs getsources "$OS" "$install_dir" \
        "$project_name" "$project_ver"
    execute popd

    # The build script is then copied alongide patches to the current build dir.
    execute cp src/"$project_name"/chevahbs "$own_build_dir"/
    if [ "$(find src/"$project_name" -name '*.patch' | wc -l)" -gt 0 ]; then
        echo "The following patches are to be copied:"
        execute ls -1 src/"$project_name"/*.patch
        execute cp src/"$project_name"/*.patch "$own_build_dir"/
    fi

    # The actual build happens here.
    execute pushd "$own_build_dir"
    execute ./chevahbs build "$OS" "$install_dir" "$project_ver"
    echo "::endgroup::"

    echo "::group::" "$1 $2" "test"
    echo "#### Testing $1 version $2... ####"
    execute ./chevahbs test "$OS"
    echo "::endgroup::"

    echo "::group::" "$1 $2" "install"
    echo "#### Installing $1 version $2... ####"
    execute ./chevahbs install "$OS" "$install_dir"
    if [ -e "Makefile" ]; then
        lib_config_dir="$install_dir/lib/config"
        makefile_name="Makefile.$OS.$version_dir"
        execute mkdir -p "$lib_config_dir"
        execute cp Makefile "$lib_config_dir/$makefile_name"
    fi
    execute popd
    echo "::endgroup::"
}


#
# Put stuff where it's expected and remove some of the cruft.
#
cleanup_install_dir() {
    local python_lib_file="lib$PYTHON_VERSION.a"

    echo "::group::Clean up Python install dir"
    execute pushd "$BUILD_DIR/$PYTHON_BUILD_DIR"
        echo "Cleaning up Python's caches and compiled files..."
        find lib/ | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf

        # Move include/ to lib/include/.
        echo "Moving the include/ sub-dir out of the way..."
        execute mv include/ lib/

        case $OS in
            windows)
                echo -e "\tSkipping further cleaning of install dir"
                ;;
            *)
                execute rm -rf tmp
                # Move all binaries to lib/config
                execute mkdir -p lib/config
                execute mv bin/ lib/config/
                execute mkdir bin
                execute pushd lib/config/bin/
                    # Move Python binary back as bin/python, then link to it.
                    execute mv "$PYTHON_VERSION" ../../../bin/python
                    execute ln -s ../../../bin/python "$PYTHON_VERSION"
                    # OS-related fixed for the Python binaries.
                    case "$OS" in
                        macos)
                            # The binary is already stripped on macOS.
                            execute rm python3
                            execute ln -s "$PYTHON_VERSION" python3
                            ;;
                        *)
                            execute strip "$PYTHON_VERSION"
                            ;;
                    esac
                    # Remove the sizable sqlite3 binary.
                    execute rm sqlite3
                execute popd
                # OS-related stripping for libs.
                case "$OS" in
                    macos)
                        # Darwin's strip command is different.
                        execute strip -r lib/lib*.a
                        ;;
                    *)
                        execute strip lib/lib*.a
                        # On CentOS 5, libffi and OpenSSL install to lib64/
                        # by default. To have all libs under lib/, required
                        # files are copied by chevahbs scripts during build.
                        # Here, make sure there's nothing installed to lib64/.
                        if [ -d lib64 ]; then
                            echo "lib64/ sub-dir found!"
                            exit 88
                        fi
                        ;;
                esac
                # Symlink the copy of libpython3.*.a too.
                execute pushd lib/"$PYTHON_VERSION"/config-*
                    execute rm "$python_lib_file"
                    execute ln -s ../../"$python_lib_file"
                execute popd
                # Remove the big test/ sub-dir.
                execute rm -rf lib/"$PYTHON_VERSION"/test/
                # Remove OpenSSL files if present.
                execute rm -rf ssl/
                # Remove (mostly OpenSSL) docs and manuals.
                execute rm -rf share/
                # Move stray pkgconfig/* to lib/pkgconfig/.
                if [ -d pkgconfig ]; then
                    execute mv pkgconfig/* lib/pkgconfig/
                    execute rmdir pkgconfig
                fi
                ;;
        esac
        # Test that only bin/ and lib/ sub-dirs are left.
        for element in *; do
            case "$element" in
                bin|lib)
                    true
                    ;;
                *)
                    echo "Unwanted element in root dir: $element"
                    exit 97
                    ;;
            esac
        done
    execute popd

    # Output Pythia's own version to a dedicated file in the archive.
    echo "$PYTHON_BUILD_VERSION.$PYTHIA_VERSION-$OS-$ARCH" \
        > "$BUILD_DIR/$PYTHON_BUILD_DIR/lib/PYTHIA_VERSION"

    echo "::endgroup::"
}


#
# Create the distributable archive.
#
# Args:
#  * target_dir = name of the dir to be archived.
#
make_dist(){
    local target_dir="$1"
    local full_ver="$PYTHON_BUILD_VERSION.$PYTHIA_VERSION"
    local target_path="../$DIST_DIR/$full_ver"
    local target_tar="$target_path/python-$full_ver-$OS-$ARCH.tar"

    # Clean dist dir and only create a sub-dir for current version.
    execute rm -rf "$DIST_DIR"
    execute mkdir -p "$DIST_DIR/$full_ver"

    execute pushd "$BUILD_DIR"
        echo "#### Creating $target_tar.gz from $target_dir. ####"
        execute tar -cf "$target_tar" "$target_dir"
        execute gzip "$target_tar"
    execute popd
}


#
# Move lib/include/ back to include/ in Python's build dir,
# otherwise building modules for testing the package is going to fail.
#
bring_back_include(){
    execute pushd "$BUILD_DIR/$PYTHON_BUILD_DIR"
        echo "Moving back the include/ sub-dir for building testing modules..."
        execute mv lib/include/ ./
    execute popd
}

#
# Construct a SFTP batch file for uploading testing packages.
# Files are uploaded with a temporary name and then renamed to final name.
#
build_publish_dist_sftp_batch() {
    local full_ver="$PYTHON_BUILD_VERSION.$PYTHIA_VERSION"
    local local_dir="$DIST_DIR/$full_ver"
    local upload_dir="testing/$full_ver"
    local pkg_file="python-$full_ver-$OS-$ARCH.tar.gz"
    local local_file="$local_dir/$pkg_file"
    local dest_file="$upload_dir/$pkg_file"

    # The mkdir command is prefixed with '-' to allow it to fail because
    # $upload_dir exists if this is not the first upload for this version.
    echo "-mkdir $upload_dir"                  > build/publish_dist_sftp_batch
    echo "put $local_file $dest_file.part"    >> build/publish_dist_sftp_batch
    echo "rename $dest_file.part $dest_file"  >> build/publish_dist_sftp_batch
}
