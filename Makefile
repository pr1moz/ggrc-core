# Copyright (C) 2013 Google Inc., authors, and contributors <see AUTHORS file>
# Licensed under http://www.apache.org/licenses/LICENSE-2.0 <see LICENSE file>
# Created By: dan@reciprocitylabs.com
# Maintained By: dan@reciprocitylabs.com

SHELL := /bin/bash

PREFIX := $(shell pwd)

DEV_PREFIX ?= $(PREFIX)
DEV_PREFIX := $(shell cd $(DEV_PREFIX); pwd)

APPENGINE_VERSION=1.9.35
APPENGINE_ZIP_NAME=google_appengine_$(APPENGINE_VERSION).zip
APPENGINE_ZIP_HREF=https://commondatastorage.googleapis.com/appengine-sdks/featured/$(APPENGINE_ZIP_NAME)
APPENGINE_ZIP_PATH=$(DEV_PREFIX)/opt/$(APPENGINE_ZIP_NAME)
APPENGINE_SDK_PATH=$(DEV_PREFIX)/opt/google_appengine
APPENGINE_SQLITE_PATCH_PATH=$(PREFIX)/extras/google_appengine__enable_sqlite3.diff
APPENGINE_NOAUTH_PATCH_PATH=$(PREFIX)/extras/google_appengine__force_noauth_local_webserver.diff

APPENGINE_PACKAGES_ZIP=$(PREFIX)/src/packages.zip
APPENGINE_PACKAGES_TEMP_ZIP=$(DEV_PREFIX)/opt/packages.zip
APPENGINE_PACKAGES_DIR=$(DEV_PREFIX)/opt/gae_packages

APPENGINE_ENV_DIR=$(DEV_PREFIX)/opt/gae_virtualenv
APPENGINE_REQUIREMENTS_TXT=$(PREFIX)/src/requirements.txt

FLASH_PATH=$(PREFIX)/src/ggrc/static/flash
STATIC_PATH=$(PREFIX)/src/ggrc/static
BOWER_PATH=$(PREFIX)/bower_components
DEV_BOWER_PATH=$(DEV_PREFIX)/bower_components
BOWER_BIN_PATH=/vagrant-dev/node_modules/bower/bin/bower
NODE_MODULES_PATH=$(DEV_PREFIX)/node_modules

$(APPENGINE_SDK_PATH) : $(APPENGINE_ZIP_PATH)
	@echo $( dirname $(APPENGINE_ZIP_PATH) )
	cd `dirname $(APPENGINE_SDK_PATH)`; \
		unzip -o $(APPENGINE_ZIP_PATH)
	touch $(APPENGINE_SDK_PATH)
	cd $(APPENGINE_SDK_PATH); \
		patch -p1 < $(APPENGINE_SQLITE_PATCH_PATH); \
		patch -p1 < $(APPENGINE_NOAUTH_PATCH_PATH)

appengine_sdk : $(APPENGINE_SDK_PATH)

clean_appengine_sdk :
	rm -rf -- "$(APPENGINE_SDK_PATH)"
	rm -f "$(APPENGINE_ZIP_PATH)"

$(APPENGINE_ZIP_PATH) :
	mkdir -p `dirname $(APPENGINE_ZIP_PATH)`
	wget "$(APPENGINE_ZIP_HREF)" -O "$(APPENGINE_ZIP_PATH).tmp"
	mv "$(APPENGINE_ZIP_PATH).tmp" "$(APPENGINE_ZIP_PATH)"

clean_appengine_packages :
	rm -f -- "$(APPENGINE_PACKAGES_ZIP)"
	rm -f -- "$(APPENGINE_PACKAGES_TEMP_ZIP)"
	rm -rf -- "$(APPENGINE_PACKAGES_DIR)"
	rm -rf -- "$(APPENGINE_ENV_DIR)"

$(APPENGINE_ENV_DIR) :
	mkdir -p `dirname $(APPENGINE_ENV_DIR)`
	virtualenv "$(APPENGINE_ENV_DIR)"
	source "$(APPENGINE_ENV_DIR)/bin/activate"; \
		pip install -U pip==7.1.2; \

appengine_virtualenv : $(APPENGINE_ENV_DIR)

$(APPENGINE_PACKAGES_DIR) : $(APPENGINE_ENV_DIR)
	mkdir -p $(APPENGINE_PACKAGES_DIR)
	source "$(APPENGINE_ENV_DIR)/bin/activate"; \
		pip install --no-deps -r "$(APPENGINE_REQUIREMENTS_TXT)" --target "$(APPENGINE_PACKAGES_DIR)"
	cd "$(APPENGINE_PACKAGES_DIR)/webassets"; \
		patch -p3 < "${PREFIX}/extras/webassets__fix_builtin_filter_loading.diff"

appengine_packages : $(APPENGINE_PACKAGES_DIR)

$(APPENGINE_PACKAGES_TEMP_ZIP) : $(APPENGINE_PACKAGES_DIR)
	cd "$(APPENGINE_PACKAGES_DIR)"; \
		find . -name "*.pyc" -delete; \
		find . -name "*.egg-info" | xargs rm -rf; \
		zip -9rv "$(APPENGINE_PACKAGES_TEMP_ZIP)" .; \
		touch "$(APPENGINE_PACKAGES_TEMP_ZIP)"

$(APPENGINE_PACKAGES_ZIP) : $(APPENGINE_PACKAGES_TEMP_ZIP)
	cp "$(APPENGINE_PACKAGES_TEMP_ZIP)" "$(APPENGINE_PACKAGES_ZIP)"

appengine_packages_zip : $(APPENGINE_PACKAGES_ZIP)

appengine : appengine_sdk appengine_packages appengine_packages_zip

clean_appengine : clean_appengine_sdk clean_appengine_packages


## Local environment


$(DEV_PREFIX)/opt/dev_virtualenv :
	mkdir -p $(DEV_PREFIX)/opt/dev_virtualenv
	virtualenv $(DEV_PREFIX)/opt/dev_virtualenv

dev_virtualenv : $(DEV_PREFIX)/opt/dev_virtualenv

dev_virtualenv_packages : dev_virtualenv src/dev-requirements.txt src/requirements.txt
	source "$(PREFIX)/bin/init_env"; \
		pip install -U pip==7.1.2; \
		pip install --no-deps -r src/requirements.txt; \
		pip install -r src/dev-requirements.txt

git_submodules :
	git submodule update --init

linked_packages : dev_virtualenv_packages
	mkdir -p $(DEV_PREFIX)/opt/linked_packages
	source bin/init_env; \
		setup_linked_packages.py $(DEV_PREFIX)/opt/linked_packages

setup_dev : dev_virtualenv_packages linked_packages


## Deployment!

src/ggrc/assets/stylesheets/dashboard.css : src/ggrc/assets/stylesheets/*.scss
	bin/build_css -p

src/ggrc/assets/assets.manifest : src/ggrc/assets/stylesheets/dashboard.css src/ggrc/assets
	source "bin/init_env"; \
		GGRC_SETTINGS_MODULE="$(SETTINGS_MODULE)" bin/build_assets

src/app.yaml : src/app.yaml.dist
	bin/build_app_yaml src/app.yaml.dist src/app.yaml \
		APPENGINE_INSTANCE="$(APPENGINE_INSTANCE)" \
		SETTINGS_MODULE="$(SETTINGS_MODULE)" \
		DATABASE_URI="$(DATABASE_URI)" \
		SECRET_KEY="$(SECRET_KEY)" \
		GOOGLE_ANALYTICS_ID="${GOOGLE_ANALYTICS_ID}" \
		GOOGLE_ANALYTICS_DOMAIN="${GOOGLE_ANALYTICS_DOMAIN}" \
		GAPI_KEY="$(GAPI_KEY)" \
		GAPI_CLIENT_ID="$(GAPI_CLIENT_ID)" \
		GAPI_CLIENT_SECRET="$(GAPI_CLIENT_SECRET)" \
		GAPI_ADMIN_GROUP="$(GAPI_ADMIN_GROUP)" \
		BOOTSTRAP_ADMIN_USERS="$(BOOTSTRAP_ADMIN_USERS)" \
		RISK_ASSESSMENT_URL="$(RISK_ASSESSMENT_URL)"\
		APPENGINE_EMAIL="$(APPENGINE_EMAIL)" \
		CUSTOM_URL_ROOT="$(CUSTOM_URL_ROOT)" \
		INSTANCE_CLASS="$(INSTANCE_CLASS)" \
		MAX_INSTANCES="$(MAX_INSTANCES)" \
		AUTHORIZED_DOMAINS="$(AUTHORIZED_DOMAINS)"

bower_components : bower.json
	mkdir -p $(FLASH_PATH)
	mkdir -p $(DEV_BOWER_PATH)
	ln -s $(DEV_BOWER_PATH) $(BOWER_PATH)
	$(BOWER_BIN_PATH) install --allow-root
	cp $(BOWER_PATH)/zeroclipboard/dist/ZeroClipboard.swf $(FLASH_PATH)/ZeroClipboard.swf
	cp -r $(NODE_MODULES_PATH)/font-awesome/fonts $(STATIC_PATH)

clean_bower_components :
	rm -rf $(BOWER_PATH) $(FLASH_PATH) $(STATIC_PATH)/fonts

deploy : appengine_packages_zip bower_components src/ggrc/assets/assets.manifest src/app.yaml

clean_deploy :
	rm -f src/ggrc/assets/stylesheets/dashboard.css
	rm -f src/ggrc/static/dashboard-*.* src/ggrc/assets/assets.manifest
	rm -f src/app.yaml

clean : clean_deploy clean_bower_components
