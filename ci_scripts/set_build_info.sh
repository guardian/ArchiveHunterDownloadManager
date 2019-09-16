#!/bin/bash

if [ "${BUILD_NUMBER}" == "" ]; then
	declare -x BUILD_NUMBER=DEV
fi

if [ "${BUILD_BRANCH}" == "" ]; then
	declare -x BUILD_BRANCH=$(git branch --no-color | grep -E '^\*' | cut -c 3-)
fi

if [ "${BUILD_BRANCH}" == "master" ]; then
	declare -x BRANCH_SUFFIX=""
else
	declare -x BRANCH_SUFFIX=" from ${BUILD_BRANCH}"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion Build ${BUILD_NUMBER}${BRANCH_SUFFIX}" "ArchiveHunterDownloadManager/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${BUILD_NUMBER}" "ArchiveHunterDownloadManager/Info.plist"
