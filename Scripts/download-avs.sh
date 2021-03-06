#!/bin/bash

#
# Wire
# Copyright (C) 2016 Wire Swiss GmbH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.
#


set -e

OPEN_SOURCE_AVS_VERSION=24
APPSTORE_AVS_VERSION=2.7.21

##################################
# CREDENTIALS
##################################
# prepare credentials if needed
if [[ -n "${GITHUB_ACCESS_TOKEN}" ]]; then
	ACCESS_TOKEN_QUERY="?access_token=${GITHUB_ACCESS_TOKEN}"
fi

##################################
# SET UP PATHS
##################################
AVS_LOCAL_PATH="wire-avs-ios"

if [ -z "${AVS_REPO}" ]; then
	echo "ℹ️  Using wire open source iOS binary"
	AVS_REPO="wireapp/avs-ios-binaries"
	AVS_LIBNAME="wire-avs-ios"
	if [ -z "${AVS_VERSION}" ]; then
		AVS_VERSION="${OPEN_SOURCE_AVS_VERSION}"
	fi
else 
	echo "ℹ️  Using custom AVS binary"
	AVS_VERSION="${AVS_CUSTOM_VERSION}"
	AVS_LIBNAME="avs-ios"
	if [ -z "${AVS_VERSION}" ]; then
		AVS_VERSION="${APPSTORE_AVS_VERSION}"
	fi
fi

##################################
# VERSIONS TO DOWNLOAD
##################################
# if version is not specified, get the latest
if [ -z "${AVS_VERSION}" ]; then
	LATEST_VERSION_PATH="https://api.github.com/repos/${AVS_REPO}/releases/latest"
	# need to get tag of last version
	AVS_VERSION=`curl -sLJ "${LATEST_VERSION_PATH}${ACCESS_TOKEN_QUERY}" | python -c 'import json; import sys; print json.load(sys.stdin)["tag_name"]'`
	if [ -z "${AVS_VERSION}" ]; then
		echo "❌  Can't find latest version for ${LATEST_VERSION_PATH} ⚠️"
		exit 1
	fi
	echo "ℹ️  Latest version is ${AVS_VERSION}"
fi

AVS_FILENAME="${AVS_LIBNAME}.${AVS_VERSION}.tar.bz2"
AVS_RELEASE_TAG_PATH="https://api.github.com/repos/${AVS_REPO}/releases/tags/${AVS_VERSION}"
	
##################################
# SET UP FOLDERS
##################################
LIBS_PATH=./Libraries

if [ ! -e $LIBS_PATH ]
then
    mkdir $LIBS_PATH
fi

pushd $LIBS_PATH > /dev/null

# remove previous, will unzip new
rm -fr $AVS_LIBNAME > /dev/null

##################################
# DOWNLOAD
##################################
if [ -e "${AVS_FILENAME}" ]; then
	# file already there? Just unzip it 
	echo "ℹ️  Existing archive ${AVS_FILENAME} found, skipping download"
else
	# DOWNLOAD
	echo "ℹ️  Downloading ${AVS_RELEASE_TAG_PATH}..."
	
	# Get tag json: need to parse json to get assed URL
	TEMP_FILE=`mktemp`
	curl -sLJ "${AVS_RELEASE_TAG_PATH}${ACCESS_TOKEN_QUERY}" -o "${TEMP_FILE}"
	ASSET_URL=`cat ${TEMP_FILE} | python -c 'import json; import sys; print json.load(sys.stdin)["assets"][0]["url"]'`
	rm "${TEMP_FILE}"
	if [ -z "${ASSET_URL}" ]; then
		echo "❌  Can't fetch release ${AVS_VERSION} ⚠️"
	fi
	# get file
	TEMP_FILE=`mktemp`
	echo "Redirected to ${ASSET_URL}..."
	curl -LJ "${ASSET_URL}${ACCESS_TOKEN_QUERY}" -o "${TEMP_FILE}" -H "Accept: application/octet-stream"
	if [ ! -f "${TEMP_FILE}" ]; then
		echo "❌  Failed to download ${ASSET_URL} ⚠️"
		exit 1
	fi
	mv "${TEMP_FILE}" "${AVS_FILENAME}" > /dev/null
	echo "✅  Done downloading!"
fi

##################################
# UNPACK
##################################
echo "ℹ️  Installing in ${LIBS_PATH}/${AVS_LIBNAME}..."
mkdir $AVS_LIBNAME
if ! tar -xvzf $AVS_FILENAME -C $AVS_LIBNAME > /dev/null; then
	rm -fr $AVS_FILENAME
	echo "❌  Failed to install, is the downloaded file valid? ⚠️"
	exit 1
fi
echo "✅  Done"

popd  > /dev/null
