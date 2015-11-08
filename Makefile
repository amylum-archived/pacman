PACKAGE = pacman
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=$(RELEASE_DIR) --sbindir=$(RELEASE_DIR)/usr/bin --bindir=$(RELEASE_DIR)/usr/bin --mandir=$(RELEASE_DIR)/usr/share/man --libdir=$(RELEASE_DIR)/usr/lib --includedir=$(RELEASE_DIR)/usr/include --docdir=$(RELEASE_DIR)/usr/share/doc/$(PACKAGE) --sysconfdir=/etc --with-scriptlet-shell=/usr/bin/bash --localstatedir=/var
CFLAGS = -static -static-libgcc -Wl,-static -lc

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBARCHIVE_VERSION = 3.1.2-1
LIBARCHIVE_URL = https://github.com/amylum/libarchive/releases/download/$(LIBARCHIVE_VERSION)/libarchive.tar.gz
LIBARCHIVE_TAR = libarchive.tar.gz
LIBARCHIVE_DIR = /tmp/libarchive
LIBARCHIVE_PATH = -I$(LIBARCHIVE_DIR)/usr/include -L$(LIBARCHIVE_DIR)/usr/lib

CURL_VERSION = 7.45.0-1
CURL_URL = https://github.com/amylum/curl/releases/download/$(CURL_VERSION)/curl.tar.gz
CURL_TAR = curl.tar.gz
CURL_DIR = /tmp/curl
CURL_PATH = -I$(CURL_DIR)/usr/include -L$(CURL_DIR)/usr/lib

OPENSSL_VERSION = 7.45.0-1
OPENSSL_URL = https://github.com/amylum/openssl/releases/download/$(OPENSSL_VERSION)/openssl.tar.gz
OPENSSL_TAR = openssl.tar.gz
OPENSSL_DIR = /tmp/openssl
OPENSSL_PATH = -I$(OPENSSL_DIR)/usr/include -L$(OPENSSL_DIR)/usr/lib

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(LIBARCHIVE_DIR) $(LIBARCHIVE_TAR)
	mkdir $(LIBARCHIVE_DIR)
	curl -sLo $(LIBARCHIVE_TAR) $(LIBARCHIVE_URL)
	tar -x -C $(LIBARCHIVE_DIR) -f $(LIBARCHIVE_TAR)
	rm -rf $(CURL_DIR) $(CURL_TAR)
	mkdir $(CURL_DIR)
	curl -sLo $(CURL_TAR) $(CURL_URL)
	tar -x -C $(CURL_DIR) -f $(CURL_TAR)
	rm -rf $(OPENSSL_DIR) $(OPENSSL_TAR)
	mkdir $(OPENSSL_DIR)
	curl -sLo $(OPENSSL_TAR) $(OPENSSL_URL)
	tar -x -C $(OPENSSL_DIR) -f $(OPENSSL_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && ./autogen.sh
	patch -p1 -d $(BUILD_DIR) < patches/ensure-matching-database-and-package-version.patch
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBARCHIVE_PATH) $(CURL_PATH) $(OPENSSL_PATH)' ./configure $(PATH_FLAGS)
	cd $(BUILD_DIR) && make install
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

