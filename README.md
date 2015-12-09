service-mapproxy

Mapproxy configuration and service for 'geo.admin.ch'!


# Getting started

Checkout the source code:

    git clone https://github.com/geoadmin/service-mapproxy.git

or when you're using ssh key (see https://help.github.com/articles/generating-ssh-keys):

    git clone git@github.com:geoadmin/service-mapproxy.git

Build:

    $ make all

    Use `make help` to know about the possible `make` targets and the currently set variables:

    $ make help


Using S3 cache:

    Define two environmental variables: MAPPROXY_PROJECT_NAME and MAPPROXY_BUCKET_NAME holding the 
    information where to store to cached tiles. Then gnerate the `mapproxy.yaml` config with:

    $ make config

    If these variable are not defined and mapproxy does not support S3 caching, a normal `mapproxy.yaml`
    will be generated.

Testing:

    Running the local uWSGI server:

    $ .build-artefacts/python-venv/bin/uwsgi mapproxy.ini

Serve MapProxy:

    http://mapproxy.org/docs/nightly/mapproxy_util.html#serve-develop

# Update config cycle

    Make sure the variable MAPPROXY_CONFIG_BASE_PATH and your personal aws credentials are set.
    Then use the following command to generate the mapproxy config:

    $ make config

    Upload the mapproxy.yaml to S3. This action will cause MapProxy to restart

    $ make deploydev
