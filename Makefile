APACHE_BASE_PATH ?= /$(shell id -un)
APACHE_BASE_DIRECTORY ?= $(CURDIR)
MODWSGI_USER ?= $(shell id -un)



## Python interpreter can't have space in path name
## So prepend all python scripts with python cmd
## See: https://bugs.launchpad.net/virtualenv/+bug/241581/comments/11
PYTHON_CMD=.build-artefacts/python-venv/bin/python


.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo
	@echo "Possible targets:"
	@echo
	@echo "- all              Install everything"
	@echo "- mapproxy         Install and configure mapproxy"
	@echo "- apache           Configure Apache (restart required)"
	@echo "- clean            Remove generated files"
	@echo "- help             Display this help"
	@echo
	@echo "Variables:"
	@echo
	@echo "- APACHE_BASE_PATH Base path  (current value: $(APACHE_BASE_PATH))"
	@echo "- APACHE_BASE_DIRECTORY       (current value: $(APACHE_BASE_DIRECTORY))"

	@echo


.PHONY: all
all: mapproxy \
	apache

.PHONY: apache
apache: apache/app.conf

.PHONY: mapproxy
mapproxy: .build-artefacts/python-venv/bin/mapproxy \
	.build-artefacts/python-venv/bin/mako-render \
	mapproxy/wsgi.py \
	mapproxy.ini

.build-artefacts/python-venv:
	mkdir -p .build-artefacts
	virtualenv --no-site-packages $@



.build-artefacts/python-venv/bin/mako-render: .build-artefacts/python-venv
	${PYTHON_CMD} .build-artefacts/python-venv/bin/pip install "Mako==1.0.0"
	touch $@
	@ if [[ ! -e .build-artefacts/python-venv/local ]]; then \
	    ln -s . .build-artefacts/python-venv/local; \
	fi
	cp scripts/cmd.py .build-artefacts/python-venv/local/lib/python2.7/site-packages/mako/cmd.py

.build-artefacts/python-venv/bin/mapproxy: .build-artefacts/python-venv
	${PYTHON_CMD} .build-artefacts/python-venv/bin/pip install "Mapproxy==1.7.0"
	${PYTHON_CMD} .build-artefacts/python-venv/bin/pip install "uwsgi==2.0.11"
	${PYTHON_CMD} .build-artefacts/python-venv/bin/pip install "webob"
	touch $@


apache/app.conf: apache/app.mako-dot-conf 
	${PYTHON_CMD} .build-artefacts/python-venv/bin/mako-render \
		--var "apache_base_directory=$(APACHE_BASE_DIRECTORY)" \
		--var "modwsgi_user=$(MODWSGI_USER)" \
	    --var "apache_base_path=$(APACHE_BASE_PATH)"  $< > $@

mapproxy/application.py:  mapproxy/application-dot-py
	${PYTHON_CMD} .build-artefacts/python-venv/bin/mako-render \
		--var "apache_base_directory=$(APACHE_BASE_DIRECTORY)" \
	    --var "apache_base_path=$(APACHE_BASE_PATH)"  $< > $@
mapproxy/wsgi.py: mapproxy/createWsgi.py
	  ${PYTHON_CMD} mapproxy/createWsgi.py 

mapproxy.ini:  mapproxy-dot-ini
	${PYTHON_CMD} .build-artefacts/python-venv/bin/mako-render \
		--var "apache_base_directory=$(APACHE_BASE_DIRECTORY)" \
	    --var "apache_base_path=$(APACHE_BASE_PATH)"  $< > $@

.PHONY: clean
clean: clean
	rm -rf .build-artefacts
	rm mapproxy.ini
	rm mapproxy/application.py
