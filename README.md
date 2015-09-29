service-mapproxy
================

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


Testing:

    Running the local uWSGI server:

    $  .build-artefacts/python-venv/bin/uwsgi mapproxy.ini
