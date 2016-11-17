SHELL = /bin/bash
USER_NAME ?= $(shell id -un)
PROFILE_NAME ?= $(USER_NAME)_aws_admin
APACHE_BASE_PATH ?= /$(USER_NAME)
APACHE_BASE_DIRECTORY ?= $(CURDIR)
MODWSGI_USER ?= $(shell id -un)
API_URL ?= http://api3.geo.admin.ch
PYTHONVENV ?= .build-artefacts/python-venv
PYTHONVENV_OPTS ?=
WMTS_BASE_URL ?= http://s3-eu-west-1.amazonaws.com/akiai4jxkwjqv5tgsaoq-wmts
MAPPROXY_CONFIG_BASE_PATH ?=swisstopo-internal-filesharing/config/mapproxy
RANDOM_MAPPROXY_FILE="mapproxy.$$rand.yaml"
export WMTS_BASE_URL


## Python interpreter can't have space in path name
## So prepend all python scripts with python cmd
## See: https://bugs.launchpad.net/virtualenv/+bug/241581/comments/11
PYTHON_CMD=$(PYTHONVENV)/bin/python
PIP_CMD := $(PYTHONVENV)/bin/pip

# Colors
RESET := $(shell tput sgr0)
RED := $(shell tput setaf 1)
GREEN := $(shell tput setaf 2)

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo
	@echo "Possible targets:"
	@echo
	@echo "- all              Install everything"
	@echo "- mapproxy         Install and configure mapproxy"
	@echo "- config           Configure mapproxy and create mapproxy.yaml (make config API_URL=http://mf-chsdi3.dev.bgdi.ch)"
	@echo "- devconfig        Configure mapproxy and create mapproxy.yaml **without** S3 cache"
	@echo "- apache           Configure Apache (restart required)"
	@echo "- uwsgi            Install uwsgi"
	@echo "- clean            Remove generated files"
	@echo "- diffdev          Display diff between local mapproxy.yaml and config on S3 dev"
	@echo "- diffint          Display diff between local mapproxy.yaml and config on S3 int"
	@echo "- diffprod         Display diff between local mapproxy.yamland config on S3 prod"
	@echo "- deploydev        Deploy local mapproxy.yaml to dev"
	@echo "- deployint        Deploy local mapproxy.yaml to int"
	@echo "- deployprod       Deploy local mapproxy.yaml to prod"
	@echo "- listconfig       List configs on STAGING (last 30 days)"
	@echo "- downloadconfig   Download config with version VERSION_ID, STAGING to OUTPUT."
	@echo "- help             Display this help"
	@echo
	@echo "Variables:"
	@echo
	@echo "- USER_NAME                         (current value: $(USER_NAME)"
	@echo "- APACHE_BASE_PATH Base path        (current value: $(APACHE_BASE_PATH))"
	@echo "- APACHE_BASE_DIRECTORY             (current value: $(APACHE_BASE_DIRECTORY))"
	@echo "- API_URL                           (current value: $(API_URL))"
	@echo "- PYTHONVENV                        (current value: $(PYTHONVENV)"
	@echo "- PYTHONVENV_OPTS                   (current value: $(PYTHONVENV_OPTS))"
	@echo "- WMTS_BASE_URL Source for tiles    (current value: $(WMTS_BASE_URL))"
	@echo "- MAPPROXY_BUCKET_NAME              (current value: $(MAPPROXY_BUCKET_NAME))"
	@echo "- MAPPROXY_CONFIG_BASE_PATH         (current value: $(MAPPROXY_CONFIG_BASE_PATH))"
	@echo
	@echo "Usage:"
	@echo 
	@echo "List all versions on int:"
	@echo "    make listconfig STAGING=int"
	@echo "Download a specific config from prod:"
	@echo "    make downloadconfig  STAGING=prod VERSION_ID=dG4swtkRSAvWtgZfkOWhL0M5.ariZQnb  OUTPUT=working.yaml"




.PHONY: all
all: $(PYTHONVENV)/requirements.timestamp mapproxy \
	apache \
	config

$(PYTHONVENV):
		@if [ ! -d $(PYTHONVENV) ]; \
		then \
				echo "${GREEN}Setting up python virtual env...${RESET}"; \
				virtualenv $@ --system-site-packages; \
		fi

requirements.txt:
$(PYTHONVENV)/requirements.timestamp: requirements.txt $(PYTHONVENV)
	${PIP_CMD} install -U pip wheel setuptools;
	${PIP_CMD} install -r requirements.txt;
	touch $@

.PHONY: apache
apache: apache/app.conf

.PHONY: config
config: .build-artefacts/python-venv
	${PYTHON_CMD} mapproxy/scripts/mapproxify.py $(API_URL)
	touch $@

.PHONY: devconfig
devconfig: .build-artefacts/python-venv
	env - API_URL="$$API_URL" WMTS_BASE_URL="$$WMTS_BASE_URL" ${PYTHON_CMD}  mapproxy/scripts/mapproxify.py $(API_URL)
	touch $@

.PHONY: mapproxy
mapproxy: $(PYTHONVENV)/bin/mapproxy \
	.build-artefacts/python-venv/bin/mako-render \
	mapproxy/wsgi.py \
	mapproxy.ini

.PHONY: uwsgi
uwsgi: $(PYTHONVENV)/bin/uwsgi


.PHONY: serve
serve:
	$(PYTHONVENV)/bin/mapproxy-util serve-develop -b 0.0.0.0:9001 --debug mapproxy/mapproxy.yaml


.PHONY: diffdev
diffdev:
	if [ -z "$(MAPPROXY_CONFIG_BASE_PATH)" ] || [ -z "$(PROFILE_NAME)" ] ; \
		then echo 'Skipping upload to DEV cluster. Either MAPPROXY_CONFIG_BASE_PATH  or PROFILE_NAME is not defined'; \
	else rand=$$RANDOM  && $(PYTHONVENV)/bin/aws s3 cp --profile $(PROFILE_NAME)  s3://$(MAPPROXY_CONFIG_BASE_PATH)/dev/mapproxy.yaml  /tmp/$$rand  && \
		diff mapproxy/mapproxy.yaml /tmp/$$rand && echo "Files are identical" || echo "Differences between files" ;  \
	fi ;

.PHONY: diffint
diffint:
	if [ -z "$(MAPPROXY_CONFIG_BASE_PATH)" ] || [ -z "$(PROFILE_NAME)" ] ; \
		then echo 'Skipping upload to DEV cluster. Either MAPPROXY_CONFIG_BASE_PATH  or PROFILE_NAME is not defined'; \
	else rand=$$RANDOM  && $(PYTHONVENV)/bin/aws s3 cp --profile $(PROFILE_NAME)  s3://$(MAPPROXY_CONFIG_BASE_PATH)/int/mapproxy.yaml  /tmp/$$rand  && \
		diff mapproxy/mapproxy.yaml /tmp/$$rand && echo "Files are identical" || echo "Differences between files" ;  \
	fi ;

.PHONY: diffprod
diffprod:
	if [ -z "$(MAPPROXY_CONFIG_BASE_PATH)" ] || [ -z "$(PROFILE_NAME)" ] ; \
		then echo 'Skipping upload to PROD cluster. Either MAPPROXY_CONFIG_BASE_PATH  or PROFILE_NAME is not defined'; \
	else rand=$$RANDOM  && $(PYTHONVENV)/bin/aws s3 cp --profile $(PROFILE_NAME)  s3://$(MAPPROXY_CONFIG_BASE_PATH)/prod/mapproxy.yaml  /tmp/$$rand  && \
		diff mapproxy/mapproxy.yaml /tmp/$$rand && echo "Files are identical" || echo "Differences between files" ;  \
	fi ;

.PHONY: deploydev
deploydev:
	(if [ -z "$(MAPPROXY_CONFIG_BASE_PATH)" ] || [ -z "$(PROFILE_NAME)" ] ; then echo 'Skipping upload to DEV cluster. Either MAPPROXY_CONFIG_BASE_PATH  or PROFILE_NAME is not defined'; \
  else $(PYTHONVENV)/bin/aws s3 cp --profile $(PROFILE_NAME) mapproxy/mapproxy.yaml s3://$(MAPPROXY_CONFIG_BASE_PATH)/dev/mapproxy.yaml ; fi ) ;

.PHONY: deployint
deployint:
	(if [[ -z "$(MAPPROXY_CONFIG_BASE_PATH)" || -z "$(PROFILE_NAME)" ]] ; then echo 'Skipping upload INT cluster. Either MAPPROXY_CONFIG_BASE_PATH or PROFILE_NAME is not defined'; \
  else $(PYTHONVENV)/bin/aws s3 cp --profile $(PROFILE_NAME) mapproxy/mapproxy.yaml s3://$(MAPPROXY_CONFIG_BASE_PATH)/int/mapproxy.yaml; fi );

.PHONY: deployprod
deployprod:
	(if [[ -z "$(MAPPROXY_CONFIG_BASE_PATH)" || -z "$(PROFILE_NAME)" ]] ; then echo 'Skipping upload PROD cluster. Either MAPPROXY_CONFIG_BASE_PATH or PROFILE_NAME is not defined'; \
  else $(PYTHONVENV)/bin/aws s3 cp --profile $(PROFILE_NAME) mapproxy/mapproxy.yaml s3://$(MAPPROXY_CONFIG_BASE_PATH)/prod/mapproxy.yaml; fi );

.PHONY: listconfig
listconfig:
	(if [[ -z "$(STAGING)" ]] ; then echo 'Skipping listing config, STAGING is not set'; \
  else $(PYTHONVENV)/bin/python mapproxy/scripts/versions.py --staging $(STAGING); fi );

.PHONY: downloadconfig
downloadconfig:
	(if [[ -z "$(STAGING)" || -z "$(VERSION_ID) || -z $(OUTPUT)" ]] ; then echo 'Skipping downloading mapproxy.yaml, STAGING, OUTPUT and/or VERSION_ID are not set'; \
  else $(PYTHONVENV)/bin/python mapproxy/scripts/versions.py --staging $(STAGING) --version_id $(VERSION_ID) --output $(OUTPUT); fi );

.build-artefacts/python-venv/bin/mako-render: .build-artefacts/python-venv
	${PYTHON_CMD} $(PYTHONVENV)/bin/pip install "Mako==1.0.0"
	touch $@
	@ if [[ ! -e $(PYTHONVENV)/local ]]; then \
	    ln -s . $(PYTHONVENV)/local; \
	fi
	cp scripts/cmd.py $(PYTHONVENV)/local/lib/python2.7/site-packages/mako/cmd.py

.build-artefacts/python-venv/bin/mapproxy: .build-artefacts/python-venv
ifndef MAPPROXY_BUCKET_NAME
	${PYTHON_CMD} $(PYTHONVENV)/bin/pip install mapproxy
else
	$(info Using bucket $(MAPPROXY_BUCKET_NAME))
	${PYTHON_CMD} $(PYTHONVENV)/bin/pip install  -e "git://github.com/procrastinatio/mapproxy.git@s3#egg=mapproxy"
endif
	${PYTHON_CMD} $(PYTHONVENV)/bin/pip install "webob"
	${PYTHON_CMD} $(PYTHONVENV)/bin/pip install "awscli"
	${PYTHON_CMD} $(PYTHONVENV)/bin/pip install "httplib2==0.9.2"
	touch $@

.build-artefacts/python-venv/bin/uwsgi: .build-artefacts/python-venv
	${PYTHON_CMD} $(PYTHONVENV)/bin/pip install "uwsgi==2.0.11"
	touch $@

apache/app.conf: apache/app.mako-dot-conf
	${PYTHON_CMD} $(PYTHONVENV)/bin/mako-render \
		--var "apache_base_directory=$(APACHE_BASE_DIRECTORY)" \
		--var "modwsgi_user=$(MODWSGI_USER)" \
	    --var "apache_base_path=$(APACHE_BASE_PATH)"  $< > $@

mapproxy/application.py:  mapproxy/application-dot-py
	${PYTHON_CMD} $(PYTHONVENV)/bin/mako-render \
		--var "apache_base_directory=$(APACHE_BASE_DIRECTORY)" \
	    --var "apache_base_path=$(APACHE_BASE_PATH)"  $< > $@

mapproxy/wsgi.py: mapproxy/createWsgi.py
	  ${PYTHON_CMD} mapproxy/createWsgi.py

mapproxy.ini:  mapproxy-dot-ini
	${PYTHON_CMD} $(PYTHONVENV)/bin/mako-render \
		--var "apache_base_directory=$(APACHE_BASE_DIRECTORY)" \
	    --var "apache_base_path=$(APACHE_BASE_PATH)"  $< > $@

.PHONY: clean
clean:
	rm -rf .build-artefacts
	rm mapproxy.ini
	rm apache/app.conf
	rm mapproxy/mapproxy.yaml
