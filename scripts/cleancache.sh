#!/bin/bash


DEFAULT_EPSG=3857

command -v s3rm >/dev/null 2>&1 || { echo >&2 "I require s3rm but it's not installed.  Try 'pip install tool-aws'. Aborting."; exit 1; }


: "${EPSG:=${DEFAULT_EPSG}}"
: "${MAPPROXY_BUCKET_NAME?Need to set MAPPROXY_BUCKET_NAME}"
: "${PROFILE_NAME?Need to set PROFILE_NAME, an AWS profile to access the ${MAPPROXY_BUCKET_NAME} bucket}"

echo
echo "*** WARNING ***"
echo "This script is about to delete **all** tiles for **all** layers"
echo "in the bucket=${MAPPROXY_BUCKET_NAME} and projection=${EPSG}."
echo

read -p "Is this what you want to do? [y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then

    for layer in $( aws s3 --profile ${PROFILE_NAME} ls  s3://${MAPPROXY_BUCKET_NAME}/1.0.0/ | awk '{split($0,a," "); print a[2]}' | sort --reverse )
    do
        echo ${layer}
        for timestamp in $( aws s3 --profile ${PROFILE_NAME} ls  s3://${MAPPROXY_BUCKET_NAME}/1.0.0/${layer}default/ | awk '{split($0,a," "); print a[2]}')
        do 
            echo ${timestamp}
            s3rm --profile ${PROFILE_NAME} --force --bucket  ${MAPPROXY_BUCKET_NAME}    --prefix 1.0.0/${layer}default/${timestamp}${EPSG}/
        done
    done
    echo "Done"
else
    echo "Exiting."
fi

