#!/usr/bin/env bash
#
# $REDISTRIBUTABLE_VERSION is the Microsoft Visual C++ 2008 revision to collect.
# See README.txt for more details.

source ../../functions.sh


if [ -d $REDISTRIBUTABLE_VERSION ]; then
    echo "Redistributables sub-dir already exists, not collecting them again..."
    exit
fi

for ARCH in x86 amd64; do
    echo "Creating $REDISTRIBUTABLE_VERSION/$ARCH sub-dir..."
    execute mkdir -p $REDISTRIBUTABLE_VERSION/$ARCH
    echo "Copying $ARCH redistributable DLLs..."
    execute cp $(find /c/Windows/WinSxS -name 'msvc?90.dll' \
        | grep $REDISTRIBUTABLE_VERSION \
        | grep WinSxS/$ARCH) $REDISTRIBUTABLE_VERSION/$ARCH/
    echo "Copying the preformatted $ARCH Manifest file..."
    execute cp Microsoft.VC90.CRT.manifest.$ARCH $REDISTRIBUTABLE_VERSION/$ARCH/
done
