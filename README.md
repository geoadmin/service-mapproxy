#service-mapproxy

Mapproxy configuration and service for 'geo.admin.ch'!


## Getting started

###Checkout the source code:

    git clone https://github.com/geoadmin/service-mapproxy.git

or when you're using ssh key (see https://help.github.com/articles/generating-ssh-keys):

    git clone git@github.com:geoadmin/service-mapproxy.git

###Build:

We are using two variant of Mapproxy. A patch one with S3 cache support and the official without S3 cache support. Defined the `MAPPROXY_BUCKET_NAME`environmental variable as describe below if you want S3 cache support.

    $ make all

   Use `make help` to know about the possible `make` targets and the currently set variables:

    $ make help

### Sources for geodata

Mapproxy will by default configure all layers used by _map.geo.admin.ch_ not only those listed in the _geoadmin API_. The **topics** list is from `/rest/services` and the layers
list from _/rest/services/all/MapServer/layersConfig_ on the `API_URL` defined host, by default _http://api.geo.admin.ch_

    $ make config API_URL=http://mf-chsdi3.dev.bgdi.ch


### Other relevant environmental variables

- `MAPPROXY_BUCKET_NAME`defines the AWS S3 bucket where the tiles are cached. You should normaly used the value used in [internal BGDI documentation](https://doc.prod.bgdi.ch/wmts.html#modify-the-mapproxy-yaml-configuration).

- `WMTS_BASE_URL`is the URL to be used for the WMTS source. Again used the value given in the doc. In some case, you way want to use _http://wmts.geo.admin.ch_ , for instance if you test the project outside the BGDI VPCs. This is not recommanded, as it may overload the proxy.

- `MAPPROXY_CONFIG_BASE_PATH` is the path where to store the `mapproxy.yaml`file on the AWS S3 configuration bucket used by the mapproxy cluster. Again use the value stated in the documentation.


###Using S3 cache:

 Define two environmental variables: `MAPPROXY_PROJECT_NAME` and `MAPPROXY_BUCKET_NAME` holding the information if it will use AWS S3 as a cache and where to store to cached tiles (the values may be found in the [internal BGDI documentation](https://doc.prod.bgdi.ch/wmts.html#modify-the-mapproxy-yaml-configuration). Then generate the `mapproxy.yaml` config with:

    $ make config

   If these variable are not defined and mapproxy does not support S3 caching, a normal `mapproxy.yaml`
    will be generated (i.e. without caching)

Sometime, you don't want to cache anything, to test different setting:

    $ make devconfig

**WARNING** Never ever upload the resulting `mapproxy.yaml` to the production cluster.

###Testing:

Testing is a bit tricky since accessing the AWS S3 bucket is done with an **instance IAM** on the mapproxy cluster and through a **AWS profile** locally on mf0.dev.bgdi.ch. Both options are being mutually exclusive.

**Using a profile on the mapproxy cluster breaks everything. Do not try.**

There are **three** steps

1. Locally with not *cache*

To debug requests and mapproxy files, you may build it without S3 and serve it by Mapproxy tools:

    $ make devconfig

    $ mapproxy-util serve-develop --debug -b :9001 mapproxy/mapproxy.yaml


Nota: The same can be achieved by unseting MAPPROXY_BUCKET_NAME:

    $ unset MAPPROXY_BUCKET_NAME


2. Locally with AWS S3 writing

To test locally the writing to S3, you have to define an AWS profile name


    $ export MAPPROXY_PROFILE_NAME=$HOME_aws_admin

And serve it a before:

    $ mapproxy-util serve-develop --debug -b :9001 mapproxy/mapproxy.yaml


3. Testing with uWSGI

Install uWSGI:

    $ pip install uwsgi

Then, you may running the local uWSGI server:

    $ .build-artefacts/python-venv/bin/uwsgi mapproxy.ini

See [Serve MapProxy](http://mapproxy.org/docs/nightly/mapproxy_util.html#serve-develop) for more options.


## Making diff against version in (dev|int|prod) clusters

You may display the difference between the locally build `mapproxy.yaml`and the ones on the various clusters by:

Display diff between local mapproxy.yaml and config on S3 dev

      $ make diffdev

Display diff between local mapproxy.yaml and config on S3 int

     $ make diffint

Display diff between local mapproxy.yaml and config on S3 prod

    $ make diffprod


## Update config cycle

Make sure the variable `MAPPROXY_CONFIG_BASE_PATH` and your personal `$HOME/.aws/credentials` are set
to be able to upload to AWS S3.
Then use the following command to generate the mapproxy config:

    $ make config=http://mf-chsdi3.dev.bgdi.ch

Test the generated `mapproxy.yaml` against the one you inted to replace:

    $ make diffdev

    >     url: http://s3-eu-west-1.amazonaws.com/akiai4jxkwjqv5tgsaoq-wmts/1.0.0/ch.swisstopo.swissalti3d-reliefschattierung/default/20160101/21781/%(z)d/%(y)d/%(x)d.%(format)s
    97418a97890,97914
    >   ch.swisstopo.swisstlm3d-wanderwege_20160315_source:
    >     coverage:
    >       bbox:
    >       - 0
    >       - 40
    >       - 20
    >       - 50
    >       bbox_srs: EPSG:4326
    >     grid: swisstopo-pixelkarte
    >     http:
    >       headers:
    >         Referer: http://mapproxy.geo.admin.ch
    >     on_error:
    >       204:
    >         cache: true
    >         response: transparent
    >       403:
    >         cache: true
    >         response: transparent
    >       404:
    >         cache: true
    >         response: transparent


Upload the mapproxy.yaml to S3. This action will cause MapProxy to restart (wait about 60s)

    $ make deploydev

And test it, using the demo http://wmts20.dev.bgdi.ch/demo

Do the same for `int` and `prod`.

## Generate config from dev, int or prod env (default to prod)

    $ make config API_URL=http://mf-chsdi3.int.bgdi.ch

## Cleaning the cache

There are two levels of cache:

  * Generated tiles in MAPPROXY_BUCKET_NAME, which are never automatically deleted
  * AWS CloudFront CLOUDFRONT_PRODUCTION_DISTRO, with a lifespan of about a few hours to a week

To erase **all** tiles for EPSG=4326 code in MAPPROXY_BUCKET_NAME, do:

    $ EPSG=4326 make cleancache

To invalidate the AWS CloudFront, use `AWS CLI` tools, but **really** be sure to **fully** understand what you are doing:

    $(mypythonenv) aws cloudfront create-invalidation  --profile ${PROFILE_NAME}  --distribution-id ${CLOUDFRONT_PRODUCTION_DISTRO} --paths '/1.0.0/ch.swisstopo.pixelkarte-farbe/default/current/4326/*’
