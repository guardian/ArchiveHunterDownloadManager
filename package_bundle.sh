#!/bin/bash -e

#  package_bundle.sh
#  ArchiveHunterDownloadManager
#  Zips up the compiled output, pushes to S3 and and informs the versions server that it has been uploaded

echo -------------------------
echo Compressing output...
echo -------------------------

if [ "${BUILD_NUMBER}" == "" ]; then
    BUILD_NUMBER=DEV
fi
if [ "$BUILD_BRANCH" == "" ]; then
    BUILD_BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
fi

if [ "$OUTPUT_BUCKET" == "" ]; then
    echo OUTPUT_BUCKET is not set
    exit 1
fi

if [ "$DOWNLOAD_VERSION_SERVER" == "" ]; then
    echo DOWNLOAD_VERSION_SERVER is not set
    exit 1
fi

if [ -d bundle ]; then
    echo Removing existing bundling output
    rm -rf bundle
fi

if [ ! -d build/Release/ArchiveHunterDownloadManager.app ]; then
    echo There does not appear to be a release build present. Please compile for release before running this script.
    exit 1
fi

mkdir -p bundle

cp -a build/Release/ArchiveHunterDownloadManager.app bundle/

cd bundle/
zip -r ../ArchiveHunterDownloadManager.zip *
cd ..
rm -rf bundle

echo Done!

echo -------------------------
echo Uploading bundle...
echo -------------------------
shasum -a 256 ArchiveHunterDownloadManager.zip > ArchiveHunterDownloadManager.zip.sha
aws s3 cp ArchiveHunterDownloadManager.zip s3://${OUTPUT_BUCKET}/ArchiveHunterDownloadManager/${BUILD_NUMBER}/ArchiveHunterDownloadManager-${BUILD_NUMBER}.zip --acl public-read
if [ "$?" != "0" ]; then
    echo Could not upload content to S3
    exit 1
fi

aws s3 cp ArchiveHunterDownloadManager.zip.sha s3://${OUTPUT_BUCKET}/ArchiveHunterDownloadManager/${BUILD_NUMBER}/ArchiveHunterDownloadManager-${BUILD_NUMBER}.zip.sha --acl public-read
if [ "$?" != "0" ]; then
    echo Could not upload checksum to S3
    exit 1
fi

BUILD_SHA=$(awk '{print $1}' < ArchiveHunterDownloadManager.zip.sha)

echo -------------------------
echo Informing version server...
echo -------------------------
VERSIONS_JSON='{"event":"newversion","buildId":'${BUILD_NUMBER}',"branch":"'${BUILD_BRANCH}'","productName":"archivehunter-download-manager","downloadUrl":"https://'${OUTPUT_BUCKET}'.s3.amazonaws.com/ArchiveHunterDownloadManager/'${BUILD_NUMBER}'/ArchiveHunterDownloadManager-'${BUILD_NUMBER}'.zip","buildSHA":"'$BUILD_SHA'"}'

echo Version document is ${VERSIONS_JSON}
curl -X POST https://${DOWNLOAD_VERSION_SERVER}/newversion -d${VERSIONS_JSON} --header "Content-Type: application/json" --header "x-api-key: ${VERSIONS_API_KEY}" -D-
echo