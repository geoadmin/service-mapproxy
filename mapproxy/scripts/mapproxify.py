#!/usr/bin/env python
# -*- coding: utf-8 -*-


"""
mapproxyfy.py Script to generate a MapProxy config file from a layer list.

Each layer's timestamp, we should define. a source, two cache and two layers.
A layer for two timestamps will have the following elements:

layers:
    ch.swisstopo.pixelkarte-farbe_20140520
    ch.swisstopo.pixelkarte-farbe_20140520_source
    ch.swisstopo.pixelkarte-farbe_20111027
    ch.swisstopo.pixelkarte-farbe_20111027_source
    ch.swisstopo.pixelkarte-farbe


caches:
     ch.swisstopo.pixelkarte-farbe_20140520_cache
     ch.swisstopo.pixelkarte-farbe_20140520_cache_out
     ch.swisstopo.pixelkarte-farbe_20111027_cache
     ch.swisstopo.pixelkarte-farbe_2011127_cache_out


source:
     ch.swisstopo.pixelkarte-farbe_20140520_source
     ch.swisstopo.pixelkarte-farbe_20111127_source


"""

import os
import argparse
import sys
import yaml
import json
import httplib2

import logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('mapproxify')


DEBUG = False
LANG = 'de'
topics = []
baseTopics = ['api']
USE_S3_CACHE = False

total_timestamps = 0

DEFAULT_SERVICE_URL = 'https://api3.geo.admin.ch'

DEFAULT_EPSG_21781_ZOOM_LEVELS = 26

DEFAULT_WMTS_BASE_URL = 'http://internal-vpc-lb-internal-wmts-infra-1291171036.eu-west-1.elb.amazonaws.com'

EPSG_21781_RESOlUTIONS = [4000, 3750, 3500, 3250, 3000, 2750, 2500, 2250, 2000, 1750, 1500, 1250, 1000, 750, 650, 500, 250, 100, 50, 20, 10, 5, 2.5, 2, 1.5, 1, 0.5, 0.25, 0.1]

DEFAULT_SERVICES = ['demo', 'wms', 'wmts']
EPSG_CODES = ['4258',  # ETRS89 (source: epsg-registry.org, but many WMTS client use 4852)
              '4326',  # WGS1984
              '2056',  # LV95
              '3857']  # Pseudo-Mercator Webmapping

USE_SERVERNAME_AS_BODID = True
current_timestamps = {}


basedir = os.path.dirname(os.path.abspath(os.path.join(os.path.abspath(__file__), '../..')))

MAPPROXY_PROFILE_NAME = os.environ.get('MAPPROXY_PROFILE_NAME', None)
MAPPROXY_BUCKET_NAME = os.environ.get('MAPPROXY_BUCKET_NAME', None)
WMTS_BASE_URL = os.environ.get('WMTS_BASE_URL', DEFAULT_WMTS_BASE_URL)

if MAPPROXY_BUCKET_NAME:
    try:
        from mapproxy.cache import s3
    except ImportError:
        USE_S3_CACHE = False
    else:
        USE_S3_CACHE = True


dict_to_obj = lambda x: (type('JsonObject', (), {k: dict_to_obj(v) for k, v in x.items()})
                         if isinstance(x, dict) else x)


def getTopics(service_url=DEFAULT_SERVICE_URL):
    h = httplib2.Http()
    url = service_url + '/rest/services'
    (resp, content) = h.request(url, "GET",
                                headers={'cache-control': 'no-cache'})

    topics = []
    js = json.loads(content)
    try:
        topics = [t.get('id') for t in js.get('topics')]
        topics.extend(baseTopics)
    except Exception as e:
        print e

    return topics


def getLayersConfigs(service_url=DEFAULT_SERVICE_URL, topics=topics):
    layers = []
    timestamps = 0
    h = httplib2.Http()
    url = service_url + '/rest/services/all/MapServer/layersConfig'
    (resp, content) = h.request(url, "GET", headers={'cache-control': 'no-cache'})

    js = json.loads(content)
    layer_list = []

    for k in sorted(list(set(js.keys()))):
        cfg = js[k]

        try:
            layerTopics = cfg.get('topics').split(',')
        except:
            layerTopics = []

        has_topic = set(topics).intersection(set(layerTopics))
        is_wmts = cfg.get('type', '') == 'wmts'

        if len(has_topic) > 0 and is_wmts:
            if USE_SERVERNAME_AS_BODID:
                cfg['bodLayerId'] = cfg.get('serverLayerName', k)
            else:
                cfg['bodLayerId'] = k
            cfg['maps'] = cfg['topics']
            if not 'timestamps' in cfg:
                cfg['timestamps'] = None
            else:
                timestamps += len(cfg['timestamps'])

            if USE_SERVERNAME_AS_BODID and cfg['bodLayerId'] not in layer_list:
                layer = dict_to_obj(cfg)
                layers.append(layer)
                layer_list.append(cfg['bodLayerId'])
        else:
            del js[k]
    return (len(layers), timestamps, layers)


def get_mapproxy_template_config(services):
    try:
        with open(os.path.abspath('mapproxy/templates/mapproxy.tpl')) as f:
            mapproxy_config = yaml.load(f.read())
    except EnvironmentError:
        print 'Critical error. Unable to open/read the mapproxy template file. Exit.'
        sys.exit(1)

    for service in mapproxy_config['services'].keys():
        if service not in services:
            del mapproxy_config['services'][service]

    for part in ['caches', 'sources']:
        if mapproxy_config[part] is None:
            mapproxy_config[part] = {}
    if mapproxy_config['layers'] is None:
        mapproxy_config['layers'] = []

    for source in mapproxy_config['sources']:
        try:
            if mapproxy_config['sources'][source]['type'] == 'tile':
                url = mapproxy_config['sources'][source]['url']
                url = url.replace(DEFAULT_WMTS_BASE_URL, WMTS_BASE_URL)
                mapproxy_config['sources'][source]['url'] = url
        except KeyError:
            pass

    return mapproxy_config


def create_grids(rng=[19, 20, 21, 22, 23, 24, 25, 26, 28]):
    grids = {}
    tpl = {"res": [],
           "bbox": [420000, 30000, 900000, 350000],
           "bbox_srs": "EPSG:21781",
           "srs": "EPSG:21781",
           "origin": "nw",
           "stretch_factor": 1.0
           }

    for i in rng:
        if i <= len(EPSG_21781_RESOlUTIONS):
            g = dict(tpl)
            g["res"] = EPSG_21781_RESOlUTIONS[:i]
            grids["epsg_21781_%s" % i] = g

    return grids


def create_wmts_source(server_layer_name, timestamp):
    # original source (one for all projection)
    wmts_url = WMTS_BASE_URL + "/1.0.0/" + server_layer_name + "/default/" + timestamp + "/21781/%(z)d/%(y)d/%(x)d.%(format)s"

    wmts_source = {"url": wmts_url,
                   "type": "tile",
                   "grid": "swisstopo-pixelkarte",
                   "transparent": True,
                   "on_error": {
                       204: {
                           "response": "transparent",
                           "cache": True
                       },
                       403: {
                           "response": "transparent",
                           "cache": True
                       },
                       404: {
                           "response": "transparent",
                           "cache": True
                       }
                   },
                   "http": {
                       "headers": {
                           "Referer": "http://mapproxy.geo.admin.ch"
                       }
                   },
                   "coverage": {"bbox": [0, 40, 20, 50], "bbox_srs": "EPSG:4326"}}

    return wmts_source


def generate_mapproxy_config(layersConfigs, services=DEFAULT_SERVICES):

    mapproxy_config = get_mapproxy_template_config(services)

    grids = create_grids()

    mapproxy_config['grids'].update(grids)

    if USE_S3_CACHE:
        mapproxy_config['globals']['cache']['bucket_name'] = MAPPROXY_BUCKET_NAME
        mapproxy_config['globals']['cache']['tile_lock_dir'] = '/tmp/mapproxy/locks'
    if MAPPROXY_PROFILE_NAME:
        mapproxy_config['globals']['cache']['s3_profile_name'] = MAPPROXY_PROFILE_NAME

    grid_names = []

    for matrix in EPSG_CODES:
        grid_name = "epsg_%s" % matrix
        grid_names.append(grid_name)

    for idx, layersConfig in enumerate(layersConfigs):
        if layersConfig and layersConfig.maps is not None:
            logger.debug("maps=%s" % layersConfig.maps)
            if layersConfig.timestamps is not None:
                bod_layer_id = layersConfig.bodLayerId
                server_layer_name = layersConfig.serverLayerName
                logger.info("Layer: %d - %s" % (idx + 1, bod_layer_id))

                if hasattr(layersConfig, 'resolutions'):
                    max_level = len(layersConfig.resolutions)
                else:
                    max_level = DEFAULT_EPSG_21781_ZOOM_LEVELS

                timestamps = layersConfig.timestamps
                current_timestamp = timestamps[0]
                if bod_layer_id == 'ch.swisstopo.zeitreihen':
                    image_format = 'png'
                    image_format_out = 'jpeg'
                else:
                    image_format = layersConfig.format
                    image_format_out = image_format

                current_timestamps[bod_layer_id] = current_timestamp

                title = bod_layer_id

                for timestamp in timestamps:
                    wmts_source_name = "%s_%s_source" % (bod_layer_id, timestamp)
                    wmts_cache_name = "%s_%s_cache" % (bod_layer_id, timestamp)
                    #layer_source_name = "%s_%s_source" % (bod_layer_id, timestamp)

                    dimensions = {'Time': {'default': timestamp, 'values': [timestamp]}}

                    # original source (one for all projection)
                    wmts_source = create_wmts_source(server_layer_name, timestamp)
                    wmts_source_grid = "epsg_21781_%s" % (max_level)

                    wmts_cache = {"sources": [wmts_source_name], "format": "image/%s" % image_format, "grids": [wmts_source_grid], "disable_storage": True}

                    if '.swissimage' in wmts_cache_name:
                        wmts_source["grid"] = "swisstopo-swissimage"
                        wmts_cache["grids"] = ["swisstopo-swissimage"]

                    for epsg_code in EPSG_CODES:
                        grid_name = "epsg_%s" % epsg_code
                        cache_out_name = "%s_%s_%s_cache_out" % (bod_layer_id, timestamp, grid_name)
                        layer_name = "%s_%s_%s" % (bod_layer_id, timestamp, grid_name)
                        # layer config: cache_out
                        #layer = {'name': layer_name, 'title': "%s (%s)" % (title, timestamp), 'dimensions': dimensions, 'sources': [cache_out_name]}
                        layer = {'name': layer_name, 'title': "%s (%s)" % (title, timestamp), 'sources': [cache_out_name]}
                        cache = {"sources": [wmts_cache_name], "format": "image/%s" % image_format_out, "grids": [grid_name], "disable_storage": True, "meta_size": [1, 1], "meta_buffer": 0}
                        if USE_S3_CACHE:
                            cache['disable_storage'] = False

                            cache_dir = '/1.0.0/%s/default/%s/%s/' % (server_layer_name, timestamp, epsg_code)
                            s3_cache = {"cache_dir": cache_dir, "type": "s3", "directory_layout": "tms"}
                            cache['cache'] = s3_cache

                        if '.swissimage' in wmts_cache_name:
                            cache["image"] = {"resampling_method": "bilinear"}
                        elif '.swisstlm3d-karte' in wmts_cache_name:
                            cache["image"] = {"resampling_method": "nearest"}

                        mapproxy_config['layers'].append(layer)
                        mapproxy_config['caches'][cache_out_name] = cache

                        layer_title = "%s (%s, source)" % (title, timestamp)
                        ## wmts_layer = {'name': wmts_source_name, 'title': layer_title, 'dimensions': dimensions, 'sources': [wmts_cache_name]}
                        wmts_layer = {'name': wmts_source_name, 'title': layer_title, 'sources': [wmts_cache_name]}
                        #wmts_layer_current = {'name': wmts_source_name, 'title': "%s ('alias')" % title, 'dimensions': dimensions, 'sources': [wmts_cache_name]}

                        if timestamp == current_timestamp:
                            #layer_current = {'name': bod_layer_id, 'title': "%s ('current')" % title, 'dimensions': dimensions, 'sources': [wmts_cache_name]}
                            layer_current = {'name': bod_layer_id, 'title': "%s ('current')" % title, 'sources': [wmts_cache_name]}
                            mapproxy_config['layers'].append(layer_current)

                        if DEBUG:
                            logger.info(json.dumps(layer, indent=4, sort_keys=True))

                        mapproxy_config['layers'].append(wmts_layer)
                        mapproxy_config['caches'][wmts_cache_name] = wmts_cache

                    # source is always unique
                    mapproxy_config['sources'][wmts_source_name] = wmts_source

    logger.info("Configuration done")

    return mapproxy_config


def main(service_url=DEFAULT_SERVICE_URL, topics=None, services=DEFAULT_SERVICES):

    if topics is None:
        topics = getTopics(service_url=service_url)

    layers_nb, timestamps_nb, layersConfig = getLayersConfigs(topics=topics)

    mapproxy_config = generate_mapproxy_config(layersConfig, services=services)

    if DEBUG:
        print json.dumps(layersConfig, sort_keys=False, indent=4)

    # generate the mapproxy.yaml config file
    logger.info("Writing mapproxy.yaml")
    with open('mapproxy/mapproxy.yaml', 'w') as o:
        o.write("# This is a generated file. Do not edit.\n\n")
        o.write(yaml.safe_dump(mapproxy_config, canonical=False, explicit_start=False, default_flow_style=False, encoding=None))

    print
    print "Service url: %s" % service_url
    print "Topics: %s" % ",".join(topics)
    print "Layers: %d, timestamps: %d" % (layers_nb, timestamps_nb)
    if USE_S3_CACHE:
        print "Using S3 cache: bucket=%s" % MAPPROXY_BUCKET_NAME
    if MAPPROXY_PROFILE_NAME:
        print "profile_name=%s" % MAPPROXY_PROFILE_NAME
    print "WMTS tile source: ", WMTS_BASE_URL


if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Generate a MapProxy configuration file from map.geo.admin.ch topics and layersConfig services',
                                     epilog="Usage:\nmapproxify.py  http://mf-chsdi3.dev.bgdi.ch --topics api gewiss")
    parser.add_argument('url', nargs='?', default=DEFAULT_SERVICE_URL, help="Service url to use. Default to 'api3.geo.admin.ch'")
    parser.add_argument('-t', '--topics', nargs='+', help='Use layers from these topics. Default to use all topics from map.geo.admin.ch', required=False)
    parser.add_argument('-s', '--services', nargs='+', default=DEFAULT_SERVICES, help='Activate services from MapProxy. Default to \'demo,wms,wmts\'', required=False)

    results = parser.parse_args()

    main(service_url=results.url, topics=results.topics, services=results.services)
