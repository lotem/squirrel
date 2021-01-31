.PHONY: all install deps release debug

all: release
install: install-release

# Change to `xcode/dist-with-icu` if boost is linked to icu libraries.
RIME_DIST_TARGET = xcode/dist

RIME_BIN_DIR = librime/dist/bin
RIME_LIB_DIR = librime/dist/lib

RIME_LIBRARY_FILE_NAME = librime.1.dylib
RIME_LIBRARY = lib/$(RIME_LIBRARY_FILE_NAME)

RIME_DEPS = librime/thirdparty/lib/libcapnp.a \
	librime/thirdparty/lib/libmarisa.a \
	librime/thirdparty/lib/libleveldb.a \
	librime/thirdparty/lib/libopencc.a \
	librime/thirdparty/lib/libyaml-cpp.a
PLUM_DATA = bin/rime-install \
	data/plum/default.yaml \
	data/plum/symbols.yaml \
	data/plum/essay.txt
OPENCC_DATA = data/opencc/TSCharacters.ocd2 \
	data/opencc/TSPhrases.ocd2 \
	data/opencc/t2s.json
SPARKLE_FRAMEWORK = Frameworks/Sparkle.framework
DEPS_CHECK = $(RIME_LIBRARY) $(PLUM_DATA) $(OPENCC_DATA) $(SPARKLE_FRAMEWORK)

OPENCC_DATA_OUTPUT = librime/thirdparty/share/opencc/*.*
PLUM_DATA_OUTPUT = plum/output/*.*
RIME_PACKAGE_INSTALLER = plum/rime-install

INSTALL_NAME_TOOL = $(shell xcrun -find install_name_tool)
INSTALL_NAME_TOOL_ARGS = -add_rpath @loader_path/../Frameworks

.PHONY: librime copy-rime-binaries

$(RIME_LIBRARY):
	$(MAKE) librime

$(RIME_DEPS):
	$(MAKE) -C librime xcode/thirdparty

librime: $(RIME_DEPS)
	$(MAKE) -C librime $(RIME_DIST_TARGET)
	$(MAKE) copy-rime-binaries

copy-rime-binaries:
	cp -L $(RIME_LIB_DIR)/$(RIME_LIBRARY_FILE_NAME) lib/
	cp $(RIME_BIN_DIR)/rime_deployer bin/
	cp $(RIME_BIN_DIR)/rime_dict_manager bin/
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/rime_deployer
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/rime_dict_manager

.PHONY: data plum-data opencc-data copy-plum-data copy-opencc-data

data: plum-data opencc-data

$(PLUM_DATA):
	$(MAKE) plum-data

$(OPENCC_DATA):
	$(MAKE) opencc-data

plum-data:
	$(MAKE) -C plum
	$(MAKE) copy-plum-data

opencc-data:
	$(MAKE) -C librime xcode/thirdparty/opencc
	$(MAKE) copy-opencc-data

copy-plum-data:
	mkdir -p data/plum
	cp $(PLUM_DATA_OUTPUT) data/plum/
	cp $(RIME_PACKAGE_INSTALLER) bin/

copy-opencc-data:
	mkdir -p data/opencc
	cp $(OPENCC_DATA_OUTPUT) data/opencc/

deps: librime data

ifdef ARCHS
BUILD_SETTINGS += ARCHS="$(ARCHS)"
BUILD_SETTINGS += ONLY_ACTIVE_ARCH=NO
endif

release: $(DEPS_CHECK)
	bash package/add_data_files
	xcodebuild -project Squirrel.xcodeproj -configuration Release $(BUILD_SETTINGS) build

debug: $(DEPS_CHECK)
	bash package/add_data_files
	xcodebuild -project Squirrel.xcodeproj -configuration Debug $(BUILD_SETTINGS) build

.PHONY: sparkle copy-sparkle-framework

$(SPARKLE_FRAMEWORK):
	$(MAKE) sparkle

sparkle:
	xcodebuild -project Sparkle/Sparkle.xcodeproj -configuration Release $(BUILD_SETTINGS) build
	$(MAKE) copy-sparkle-framework

copy-sparkle-framework:
	mkdir -p Frameworks
	cp -RP Sparkle/build/Release/Sparkle.framework Frameworks/

clean-sparkle:
	rm -rf Frameworks/* > /dev/null 2>&1 || true

.PHONY: package archive sign-archive

package: release
	bash package/make_package

archive: package
	bash package/make_archive

sign-archive:
	[ -n "${checksum}" ] || (echo >&2 'ERROR: $$checksum not specified.'; false)
	bash package/make_archive

DSTROOT = /Library/Input Methods
SQUIRREL_APP_ROOT = $(DSTROOT)/Squirrel.app

.PHONY: permission-check install-debug install-release

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(SQUIRREL_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: debug permission-check
	rm -rf "$(SQUIRREL_APP_ROOT)"
	cp -R build/Debug/Squirrel.app "$(DSTROOT)"
	DSTROOT="$(DSTROOT)" RIME_NO_PREBUILD=1 bash scripts/postinstall

install-release: release permission-check
	rm -rf "$(SQUIRREL_APP_ROOT)"
	cp -R build/Release/Squirrel.app "$(DSTROOT)"
	DSTROOT="$(DSTROOT)" bash scripts/postinstall

.PHONY: clean clean-deps

clean:
	rm -rf build > /dev/null 2>&1 || true
	rm build.log > /dev/null 2>&1 || true
	rm bin/* > /dev/null 2>&1 || true
	rm lib/* > /dev/null 2>&1 || true
	rm data/plum/* > /dev/null 2>&1 || true
	rm data/opencc/* > /dev/null 2>&1 || true

clean-deps:
	$(MAKE) -C plum clean
	$(MAKE) -C librime xcode/clean
	$(MAKE) -C clean-sparkle
