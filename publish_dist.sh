#!/usr/bin/env bash
#
# Uploads dist package, then shows final links.
# To be used through GitHub actions.

set -o nounset
set -o errexit
set -o pipefail

dest_server="bin.chevah.com"
dest_user="github-upload"
root_link="https://bin.chevah.com:20443/testing"

# Get the details needed to show final destination after the upload.
source BUILD_ENV_VARS
pkg_name="python-$PYTHON_FULL_VERSION-$OS-$ARCH.tar.gz"

# The private key comes from GitHub Secrets through the configured workflow.
case $OS in
    win)
        C:\Progra~1\OpenSSH-Win64\sftp.exe -b publish_dist_sftp_batch \
            -i priv_key -o StrictHostKeyChecking=yes "$dest_user"@"$dest_server"

        ;;
    *)
        sftp -b publish_dist_sftp_batch -i priv_key \
            -o StrictHostKeyChecking=yes "$dest_user"@"$dest_server"
        ;;
esac

# Show the final destination.
echo -n "Package $pkg_name uploaded to: "
echo "$root_link/$PYTHON_FULL_VERSION/"
echo -n "Direct link: "
echo "$root_link/$PYTHON_FULL_VERSION/$pkg_name"
