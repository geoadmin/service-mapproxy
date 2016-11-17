#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import botocore
import boto3
import sys


from datetime import datetime, timedelta

import pytz
import argparse


MAPPROXY_CONFIG = 'mapproxy/mapproxy.yaml'

MAPPROXY_BUCKET_LOCATION = os.environ.get('MAPPROXY_BUCKET_LOCATION', 'eu-west-1')
MAPPROXY_PROFILE_NAME = os.environ.get('PROFILE_NAME', None)
CONFIG_BUCKET_NAME = 'swisstopo-internal-filesharing'

DEFAULT_STAGING = 'dev'


class Config():

    def __init__(self, staging='dev', bucket=CONFIG_BUCKET_NAME):

        self.bucket = bucket
        self.staging = staging
        try:
            session = boto3.session.Session(profile_name=MAPPROXY_PROFILE_NAME,  region_name=MAPPROXY_BUCKET_LOCATION)
        except botocore.exceptions.ProfileNotFound as e:
            print "You need to set MAPPROXY_PROFILE_NAME to a valid profile name in $HOME/.aws/credentials"
            print e
            sys.exit(1)
        except botocore.exceptions.BotoCoreError as e:
            print "Cannot establish connection. Check you credentials ({}) " + \
                  "and location ({}).".format(MAPPROXY_PROFILE_NAME, MAPPROXY_BUCKET_LOCATION)
            print e
            sys.exit(2)

        self.s3 = session.resource('s3', config=boto3.session.Config(signature_version='s3v4'))

        self.key = 'config/mapproxy/{}/mapproxy.yaml'.format(staging)

    def list(self, days = 30):
        date_N_days_ago = datetime.utcnow() - timedelta(days=days)
        uk = pytz.timezone('Europe/London')
        someday = uk.localize(date_N_days_ago)

        versions = self.s3.Bucket(CONFIG_BUCKET_NAME).object_versions.filter(Prefix=self.key)
        print "\n\nBucket: {}\nstaging: {}\nConfig file: {}".format(self.bucket, self.staging, self.key)
        print "Latest\t\tVersion_id\t\tLast modified"
        print "-------------------------------------------------------"
        for version in versions:
            print version.is_latest, version.version_id, "{:%Y-%m-%d %H:%M}".format(version.last_modified)
            if version.last_modified < someday:
                break

    def save(self, version_id, output=MAPPROXY_CONFIG):
        object_version = self.s3.ObjectVersion(self.bucket, self.key, version_id)

        try:
            obj = object_version.get()
        except botocore.exceptions.ClientError:
            print "Cannot retrieve object with key '{}' and version_id '{}' in bucket '{}'".format(self.key, version_id, self.bucket)
            sys.exit(2)

        last_modified = obj['LastModified']
        if os.path.isfile(output):
            print "Cannot overwrite {}. Please delete it".format(output)
            sys.exit(2)
        with open(output, 'w') as f:
            f.write('# version_id: {}\n'.format(version_id))
            f.write('# Uploaded on: {:%Y-%m-%d %H:%M}\n'.format(last_modified))
            f.write('# Staging: {}\n\n\n'.format(self.staging))

            body = obj['Body'].read()
            print "Saving config to '{}'".format(output)
            f.write(body)
            f.close()


def main():
    parser = argparse.ArgumentParser(description='List and get previous version of Mapproxy config',
                                     epilog="Usage:\nmapproxify.py  http://mf-chsdi3.dev.bgdi.ch --topics api gewiss")

    parser.add_argument(
        '-s',
        '--staging',
        nargs='?',
        default=DEFAULT_STAGING,
        help="Staging config to use. Default to 'dev'")

    parser.add_argument(
        '-i',
        '--version_id',
        nargs='?',
        type=str,
        help='Version id to save locally',
        required=False)
    parser.add_argument(
        '-o',
        '--output',
        nargs='?',
        default=MAPPROXY_CONFIG,
        help='Filename to save config into. Default to {}'.format(MAPPROXY_CONFIG),
        required=False)

    results = parser.parse_args()

    c = Config(staging=results.staging)
    if results.output and results.version_id:
        c.save(results.version_id, output=results.output)
    else:
        c.list()

if __name__ == '__main__':
    main()
