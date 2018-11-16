#!/bin/bash
#
# Since: October, 2014
# Author: bruno.borges@oracle.com
# Description: script to build a Docker image for WebLogic
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
# Copyright (c) 2014-2018 Oracle and/or its affiliates. All rights reserved.
#

usage() {
cat << EOF

Usage: buildDockerImage.sh -v [version] [-d | -g ] [-s] [-c]
Builds a Docker Image for Oracle WebLogic.

Parameters:
   -v: version to build. Required.
       Choose one of: $(for i in $(ls -d */); do echo -n "${i%%/}  "; done)
   -d: creates image based on 'developer' distribution
   -g: creates image based on 'generic' distribution
   -c: enables Docker image layer cache during build
   -s: skips the MD5 check of packages

* select one distribution only: -d, or -g

LICENSE UPL 1.0

Copyright (c) 2014-2018 Oracle and/or its affiliates. All rights reserved.

EOF
exit 0
}

# Validate packages
checksumPackages() {
  echo "Checking if required packages are present and valid..."
  md5sum -c Checksum.$DISTRIBUTION
  if [ "$?" -ne 0 ]; then
    echo "MD5 for required packages to build this image did not match!"
    echo "Make sure to download missing files in folder $VERSION. See *.download files for more information"
    exit $?
  fi
}

if [ "$#" -eq 0 ]; then usage; fi

# Parameters
DEVELOPER=0
GENERIC=0
VERSION="12.2.1.3"
SKIPMD5=0
NOCACHE=true
while getopts "hcsdgiv:" optname; do
  case "$optname" in
    "h")
      usage
      ;;
    "s")
      SKIPMD5=1
      ;;
    "d")
      DEVELOPER=1
      ;;
    "g")
      GENERIC=1
      ;;
    "v")
      VERSION="$OPTARG"
      ;;
    "c")
      NOCACHE=false
      ;;
    *)
    # Should not occur
      echo "Unknown error while processing options inside buildDockerImage.sh"
      ;;
  esac
done

# Which distribution to use?
if [ $((DEVELOPER + GENERIC)) -gt 1 ]; then
  usage
elif [ $DEVELOPER -eq 1 ]; then
  DISTRIBUTION="developer"
elif [ $GENERIC -eq 1 ]; then
  DISTRIBUTION="generic"
else
  echo "Invalid distribution, please elect one distribution only: -d, or -g"
  exit 1
fi

# Publish a different Version number than what is specified by Dockerfile
PUBLISH_VERSION=${PUBLISH_VERSION:-$VERSION}

# WebLogic Image Name
IMAGE_NAME="oracle/weblogic:${PUBLISH_VERSION}-$DISTRIBUTION"

# Go into version folder
cd $VERSION

if [ ! "$SKIPMD5" -eq 1 ]; then
  checksumPackages
else
  echo "Skipped MD5 checksum."
fi

echo "====================="

# Proxy settings
PROXY_SETTINGS=""
if [ "${http_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg http_proxy=${http_proxy}"
fi

if [ "${https_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg https_proxy=${https_proxy}"
fi

if [ "${ftp_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg ftp_proxy=${ftp_proxy}"
fi

if [ "${no_proxy}" != "" ]; then
  PROXY_SETTINGS="$PROXY_SETTINGS --build-arg no_proxy=${no_proxy}"
fi

if [ "$PROXY_SETTINGS" != "" ]; then
  echo "Proxy settings were found and will be used during build."
fi

# Packge file name overrides
EXTRA_BUILD_ARGS=""
if [ "${PKG_NAME}" != "" ]; then
  EXTRA_BUILD_ARGS="$EXTRA_BUILD_ARGS --build-arg PKG_NAME=${PKG_NAME}"
fi
if [ "${JAR_NAME}" != "" ]; then
  EXTRA_BUILD_ARGS="$EXTRA_BUILD_ARGS --build-arg JAR_NAME=${JAR_NAME}"
fi
if [ "$EXTRA_BUILD_ARGS" != "" ]; then
  echo "Package and Jar file name settings were found and will be used during build."
fi

# ################## #
# BUILDING THE IMAGE #
# ################## #
echo "Building image '$IMAGE_NAME' ..."

# BUILD THE IMAGE (replace all environment variables)
BUILD_START=$(date '+%s')
docker build --force-rm=$NOCACHE --no-cache=$NOCACHE $PROXY_SETTINGS $EXTRA_BUILD_ARGS -t $IMAGE_NAME -f Dockerfile.$DISTRIBUTION . || {
  echo "There was an error building the image."
  exit 1
}
BUILD_END=$(date '+%s')
BUILD_ELAPSED=`expr $BUILD_END - $BUILD_START`

echo ""

if [ $? -eq 0 ]; then
cat << EOF
  WebLogic Docker Image for '$DISTRIBUTION' version ${PUBLISH_VERSION} is ready to be extended:

    --> $IMAGE_NAME

  Build completed in $BUILD_ELAPSED seconds.

EOF
else
  echo "WebLogic Docker Image was NOT successfully created. Check the output and correct any reported problems with the docker build operation."
fi
