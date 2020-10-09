#!/usr/bin/env bash
#
# Pythia-specific functions.

# Global variables.
COMMAND=""
OS=""
INSTALL_DIR=""

#
# Chevah Build Script command selection.
#
select_chevahbs_command() {
    if [ $DEBUG -ne 0 ]; then
        echo "select_chevahbs_command:" $@
    fi
    COMMAND=$1
    OS=$2
    INSTALL_DIR=$3
    # Shift the standard arguments, and the rest will be passed to all
    # commands.
    shift 3

    chevahbs_command="chevahbs_$COMMAND"
    type $chevahbs_command &> /dev/null
    if [ $? -eq 0 ]; then
        $chevahbs_command $@
    else
        (>&2 echo "Don't know what to do with command: ${COMMAND}.")
        exit 90
    fi
}


#
# Internal function for downloading sources on-the-fly as needed.
# Do not quote the *_CMD vars, as required parameters might be included!
#
download_sources(){
    local project_name=$1
    local project_ver=$2
    local link=$3
    local archive_ext=$4
    # Sometimes the archive is not named $name-$version.$ext, let's force it.
    local archive_filename="$project_name"-"$project_ver"."$archive_ext"
    # Only download the sources if they are not present.
    if [ ! -e "$archive_filename" ]; then
        echo "## Downloading $project_name version ${project_ver}... ##"
        execute $GET_CMD "$archive_filename" "$link"
    else
        echo "    $archive_filename already present, not downloading again."
    fi

    echo "## Verifying checksums for ${archive_filename}... ##"
    execute $SHA_CMD sha512.sum

    # Current dir is src/$project_name, and sources have full hierarchy.
    # So far, all upstream archives respected the $name-$version convention
    # for the name of the root directory in the archive.
    case "$archive_ext" in
        tar.gz|tgz)
            echo "## Unpacking archive ${archive_filename}... ##"
            execute $TAR_CMD "$archive_filename" -C ../../build/
            ;;
        zip)
            echo "## Unpacking archive ${archive_filename}... ##"
            execute $ZIP_CMD "$archive_filename" -d ../../build/
            ;;
        *msi|exe)
            # No need to use ../../build/"$project_name"-"$project_ver"/ here.
            echo "    Nothing to unpack for ${archive_filename}."
            ;;
        *)
            (>&2 echo "Unknown archive type for ${archive_filename}, exiting!")
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
        chevahbs_patch $@
    fi
    echo "## Configuring... ##"
    chevahbs_configure $@
    echo "## Compiling... ##"
    chevahbs_compile $@
    echo "## Installing... ##"
    chevahbs_install $@
}


build() {
    # This has the form: "libffi", "zlib", "bzip", "libedit", etc.
    # It's present in 'src/` and contains `chevahbs`, checksums, patches.
    # Also used when downloading the gzipp'ed tarball and unpacking it.
    project_name="$1"
    # This has the form: "3.2.1", "1.2.11". etc.
    project_ver="$2"

    # This is where sources are unpacked, patched, and built.
    version_dir="$1"-"$2"
    own_build_dir="$BUILD_DIR"/"$version_dir"

    # This is were the builds are installed.
    install_dir="$PWD/$BUILD_DIR/$PYTHON_BUILD_DIR"
    # Whole build/ sub-dir should be cleared already, let's make sure.
    echo "## Removing $own_build_dir if existing... ##"
    execute rm -rf "$own_build_dir"

    # Downloads happen in src/ to not get lost when wiping the build/ dir.
    echo "## Downloading in src/${project_name}... ##"
    execute pushd "src/$project_name"
    # Go through local project's chevahbs to pick up the link and come back
    # in download_sources() to get the sources, check them, and unpack.
    execute ./chevahbs getsources $OS $install_dir $project_name $project_ver
    execute popd

    # The build script is then copied alongide patches to the current build dir.
    execute cp src/$project_name/chevahbs $own_build_dir/
    if [ $(ls src/$project_name/*.patch 2>/dev/null | wc -l) -gt 0 ]; then
        echo "The following patches are to be copied:"
        execute ls -1 src/$project_name/*.patch
        execute cp src/$project_name/*.patch $own_build_dir/
    fi

    # The actual build happens here.
    execute pushd $own_build_dir
    execute ./chevahbs build $OS $install_dir $project_ver
        if [ -e "Makefile" ]; then
            lib_config_dir="$install_dir/lib/config"
            makefile_name="Makefile.${OS}.${version_dir}"
            execute mkdir -p "$lib_config_dir"
            execute cp Makefile "$lib_config_dir"/"$makefile_name"
        fi
    execute popd
}


#
# Create the distributable archive.
#
# It also generates the symlink to latest build.
#
# Args:
#  * kind = (agent|python2.5)
#  * target_dir = name of the dir to be archived.
#
make_dist(){
    kind=$1
    target_dir=$2

    target_path=../dist/${kind}/${OS}/${ARCH}
    target_common=python-${PYTHON_BUILD_VERSION}.${PYTHON_PACKAGE_VERSION}-${OS}-${ARCH}
    target_tar=${target_path}/${target_common}.tar
    target_tar_gz=${target_tar}.gz

    tar_gz_file=${target_dir}.tar.gz
    tar_gz_source_file=${target_common}.tar.gz

    # Create a clean dist dir.
    execute rm -rf ${DIST_DIR}
    execute mkdir -p ${DIST_DIR}/${kind}/${OS}/${ARCH}

    # Create tar inside dist dir.
    execute pushd ${BUILD_DIR}
        echo "#### Creating $target_tar_gz from $target_dir. ####"
        execute tar -cf $target_tar $target_dir
        execute gzip $target_tar
    execute popd
}


# Move source to target, making sure mv will not fail if a dir
# already exists.
#
# The move is done by merging the dirs.
safe_move() {
    source=$1
    target=$2
    execute cp -r $source $target
    execute rm -rf $source
}


#
# Wipe the manifest of source.
#
wipe_manifest() {
    local wiper=$1
    local source=$2

    echo "Extracting manifests for ${source}..."
    execute $wiper --verbose --extract ${source}.embedded $source

    echo "Patching manifests to use our redistributable version..."
    execute sed -e \
        "s|version=\"9.0.21022.8\"|version=\"${REDISTRIBUTABLE_VERSION}\"|" \
        < ${source}.embedded \
        > ${source}.manifest

    execute rm -f --verbose ${source}.embedded
}


#
# Safety DB IDs to be ignored when using pyOpenSSL 0.13.1.
# Reported upstream at https://github.com/pyupio/safety/issues/174.
#
add_ignored_safety_ids_for_pyopenssl_false_positives() {
    # Safety ID 36533 (CVE-2018-1000807):
    #     "Python Cryptographic Authority pyopenssl version prior to version
    #     17.5.0 contains a CWE-416: Use After Free vulnerability in X509
    #     object handling that can result in Use after free can lead to
    #     possible denial of service or remote code execution.. This attack
    #     appear to be exploitable via Depends on the calling application and
    #     if it retains a reference to the memory.. This vulnerability appears
    #     to have been fixed in 17.5.0."
    # Safety ID 36534 (CVE-2018-1000808):
    #     "Python Cryptographic Authority pyopenssl version Before 17.5.0
    #     contains a CWE - 401 : Failure to Release Memory Before Removing Last
    #     Reference vulnerability in PKCS #12 Store that can result in Denial
    #     of service if memory runs low or is exhausted."
    SAFETY_FALSE_POSITIVES_OPTS="$SAFETY_FALSE_POSITIVES_OPTS -i 36533 -i 36534"
}
