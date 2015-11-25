PACKAGE = p11-kit
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --infodir=/tmp/trash
CONF_FLAGS = --without-libffi
CFLAGS = -static -static-libgcc -Wl,-static -DHAVE_STRCONCAT

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags)
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBTASN1_VERSION = 4.7-2
LIBTASN1_URL = https://github.com/amylum/libtasn1/releases/download/$(LIBTASN1_VERSION)/libtasn1.tar.gz
LIBTASN1_TAR = /tmp/libtasn1.tar.gz
LIBTASN1_DIR = /tmp/libtasn1
LIBTASN1_PATH = -I$(LIBTASN1_DIR)/usr/include -L$(LIBTASN1_DIR)/usr/lib

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(LIBTASN1_DIR) $(LIBTASN1_TAR)
	mkdir $(LIBTASN1_DIR)
	curl -sLo $(LIBTASN1_TAR) $(LIBTASN1_URL)
	tar -x -C $(LIBTASN1_DIR) -f $(LIBTASN1_TAR)
	find $(LIBTASN1_DIR) -name '*.la' -delete

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && ./autogen.sh
	patch -d $(BUILD_DIR) -p1 < patches/libnssckbi-compat.patch
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBTASN1_PATH)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/tmp
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

