PACKAGE = pacman
ORG = amylum

DEP_DIR = /tmp/dep-dir

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=$(RELEASE_DIR) --sbindir=$(RELEASE_DIR)/usr/bin --bindir=$(RELEASE_DIR)/usr/bin --mandir=$(RELEASE_DIR)/usr/share/man --libdir=$(RELEASE_DIR)/usr/lib --includedir=$(RELEASE_DIR)/usr/include --docdir=$(RELEASE_DIR)/usr/share/doc/$(PACKAGE) --sysconfdir=/etc --with-scriptlet-shell=/usr/bin/bash --localstatedir=/var
CFLAGS = -static -static-libgcc -Wl,-static -lc -I$(DEP_DIR)/usr/include

LIBARCHIVE_VERSION = 3.1.2
LIBARCHIVE_URL = http://libarchive.org/downloads/libarchive-$(LIBARCHIVE_VERSION).tar.gz
LIBARCHIVE_TAR = /tmp/libarchive.tar.gz
LIBARCHIVE_DIR = /tmp/libarchive
LIBARCHIVE_TARGET = $(DEP_DIR)

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

.PHONY : default submodule manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(LIBARCHIVE_DIR) $(LIBARCHIVE_TAR)
	mkdir -p $(LIBARCHIVE_DIR)

	curl -sLo $(LIBARCHIVE_TAR) $(LIBARCHIVE_URL)
	tar -x -C $(LIBARCHIVE_DIR) -f $(LIBARCHIVE_TAR) --strip-components=1
	cd $(LIBARCHIVE_DIR) && CC=musl-gcc ./configure && make DESTDIR=$(LIBARCHIVE_TARGET) install

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && ./autogen.sh
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' ./configure $(PATH_FLAGS)
	patch -p1 -d $(BUILD_DIR) < patches/ensure-matching-database-and-package-version.patch
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

