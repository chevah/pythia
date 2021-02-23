#!/usr/bin/env bash
#
# Sets up GitHub CI containers for a build job.

set -o nounset
set -o errexit
set -o pipefail

if [ ! -f /etc/os-release ]; then
    # Only CentOS 5 doesn't have this file and is used to build Pythia.
    rpm -i http://www.tuxad.de/rpms/tuxad-release-5-1.noarch.rpm
    yum install -y curl openssh-clients
    rpm -i --nodeps http://binary.chevah.com/third-party-stuff/centos5/endpoint/git{-core,}-2.5.0-1.ep.x86_64.rpm
else
    source /etc/os-release
    case "$ID" in
        alpine)
            apk add git bash curl openssh-client
            curl -o /usr/local/bin/paxctl https://binary.chevah.com/third-party-stuff/alpine/paxctl-3.12
            chmod +x /usr/local/bin/paxctl
            ;;
    esac
fi
