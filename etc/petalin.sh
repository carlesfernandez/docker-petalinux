#!/bin/bash
# Run from a PetaLinux project directory
latest=$(docker image list | grep ^petalinux | awk '{ print $2 }' | sort | tail -1)
echo "Starting petalinux:$latest"
mkdir -p $PWD/tftpboot
if [ $GENIUX_MIRROR_PATH ]
    then
        docker run -ti -v "$PWD":"$PWD" -v $GENIUX_MIRROR_PATH:/source_mirror -v "$PWD/tftpboot":/tftpboot -w "$PWD" --rm -u petalinux petalinux:$latest $@
    else
        docker run -ti -v "$PWD":"$PWD" -v "$PWD/tftpboot":/tftpboot -w "$PWD" --rm -u petalinux petalinux:$latest $@
fi
