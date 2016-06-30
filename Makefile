PACKAGE = pacman
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --sysconfdir=/etc --with-scriptlet-shell=/usr/bin/bash --localstatedir=/var
CONF_FLAGS = --disable-doc --with-gpgme
CFLAGS =

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBARCHIVE_VERSION = 3.2.0-2
LIBARCHIVE_URL = https://github.com/amylum/libarchive/releases/download/$(LIBARCHIVE_VERSION)/libarchive.tar.gz
LIBARCHIVE_TAR = /tmp/libarchive.tar.gz
LIBARCHIVE_DIR = /tmp/libarchive
LIBARCHIVE_PATH = -I$(LIBARCHIVE_DIR)/usr/include -L$(LIBARCHIVE_DIR)/usr/lib

CURL_VERSION = 7.49.1-12
CURL_URL = https://github.com/amylum/curl/releases/download/$(CURL_VERSION)/curl.tar.gz
CURL_TAR = /tmp/curl.tar.gz
CURL_DIR = /tmp/curl
CURL_PATH = -I$(CURL_DIR)/usr/include -L$(CURL_DIR)/usr/lib

OPENSSL_VERSION = 1.0.2h-7
OPENSSL_URL = https://github.com/amylum/openssl/releases/download/$(OPENSSL_VERSION)/openssl.tar.gz
OPENSSL_TAR = /tmp/openssl.tar.gz
OPENSSL_DIR = /tmp/openssl
OPENSSL_PATH = -I$(OPENSSL_DIR)/usr/include -L$(OPENSSL_DIR)/usr/lib
LIBSSL_LIBS = -lz

ZLIB_VERSION = 1.2.8-4
ZLIB_URL = https://github.com/amylum/zlib/releases/download/$(ZLIB_VERSION)/zlib.tar.gz
ZLIB_TAR = /tmp/zlib.tar.gz
ZLIB_DIR = /tmp/zlib
ZLIB_PATH = -I$(ZLIB_DIR)/usr/include -L$(ZLIB_DIR)/usr/lib

GPGME_VERSION = 1.6.0-3
GPGME_URL = https://github.com/amylum/gpgme/releases/download/$(GPGME_VERSION)/gpgme.tar.gz
GPGME_TAR = /tmp/gpgme.tar.gz
GPGME_DIR = /tmp/gpgme
GPGME_PATH = -I$(GPGME_DIR)/usr/include -L$(GPGME_DIR)/usr/lib

LIBGPG-ERROR_VERSION = 1.22-4
LIBGPG-ERROR_URL = https://github.com/amylum/libgpg-error/releases/download/$(LIBGPG-ERROR_VERSION)/libgpg-error.tar.gz
LIBGPG-ERROR_TAR = /tmp/libgpgerror.tar.gz
LIBGPG-ERROR_DIR = /tmp/libgpg-error
LIBGPG-ERROR_PATH = -I$(LIBGPG-ERROR_DIR)/usr/include -L$(LIBGPG-ERROR_DIR)/usr/lib

LIBASSUAN_VERSION = 2.4.2-4
LIBASSUAN_URL = https://github.com/amylum/libassuan/releases/download/$(LIBASSUAN_VERSION)/libassuan.tar.gz
LIBASSUAN_TAR = /tmp/libassuan.tar.gz
LIBASSUAN_DIR = /tmp/libassuan
LIBASSUAN_PATH = -I$(LIBASSUAN_DIR)/usr/include -L$(LIBASSUAN_DIR)/usr/lib

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
	rm -rf $(ZLIB_DIR) $(ZLIB_TAR)
	mkdir $(ZLIB_DIR)
	curl -sLo $(ZLIB_TAR) $(ZLIB_URL)
	tar -x -C $(ZLIB_DIR) -f $(ZLIB_TAR)
	rm -rf $(GPGME_DIR) $(GPGME_TAR)
	mkdir $(GPGME_DIR)
	curl -sLo $(GPGME_TAR) $(GPGME_URL)
	tar -x -C $(GPGME_DIR) -f $(GPGME_TAR)
	rm -rf $(LIBGPG-ERROR_DIR) $(LIBGPG-ERROR_TAR)
	mkdir $(LIBGPG-ERROR_DIR)
	curl -sLo $(LIBGPG-ERROR_TAR) $(LIBGPG-ERROR_URL)
	tar -x -C $(LIBGPG-ERROR_DIR) -f $(LIBGPG-ERROR_TAR)
	rm -rf $(LIBASSUAN_DIR) $(LIBASSUAN_TAR)
	mkdir $(LIBASSUAN_DIR)
	curl -sLo $(LIBASSUAN_TAR) $(LIBASSUAN_URL)
	tar -x -C $(LIBASSUAN_DIR) -f $(LIBASSUAN_TAR)
	rm -f /tmp/libassuan/usr/lib/libassuan.la

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && ./autogen.sh
	cd $(BUILD_DIR) && CC=musl-gcc LIBSSL_LIBS='$(LIBSSL_LIBS)' CFLAGS='$(CFLAGS) $(LIBARCHIVE_PATH) $(CURL_PATH) $(OPENSSL_PATH) $(ZLIB_PATH) $(GPGME_PATH) $(LIBGPG-ERROR_PATH) $(LIBASSUAN_PATH)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
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

