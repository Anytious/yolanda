PROJECT_SOURCE_DIR ?= $(abspath ./)
BUILD_DIR ?= $(PROJECT_SOURCE_DIR)/build
INSTALL_DIR ?= $(BUILD_DIR)/install
CONAN_PKG_DIR ?= $(BUILD_DIR)/conan_package
DEPLOY_DIR ?= $(BUILD_DIR)/deploy
NUM_JOB ?= 8

REPO_COMMIT_HASH = $(shell cd $(PROJECT_SOURCE_DIR) && git log -1 --format=%h --abbrev=8)
PACKAGE_VERSION_SUFFIX ?=
PACKAGE_VERSION ?= $(shell cd $(PROJECT_SOURCE_DIR) && git log -1 --date=format:'%Y.%m.%d_%H.%M.%S' --format="%cd")_$(REPO_COMMIT_HASH)$(PACKAGE_VERSION_SUFFIX)
PACKAGE_ID ?= $(PACKAGE_NAME)/$(PACKAGE_VERSION)@momenta/stable

# same logic as in utils.cmake:extract_version_from_changelog
# Note that
#	should use "grep -m1 -E '^\# v[" (in Makefile)
#	instead of "grep -m1 -E '^# v["  (in shell)
#	in make. `#` needs to be escaped.
VERSION_FULL_RAW = $(shell grep -m1 -E '^\# v[0-9]+\.[0-9]+\.[0-9]+.*' CHANGELOG.md | cut -c 4-)
VERSION_FULL = $(or ${VERSION_FULL_RAW},${VERSION_FULL_RAW},0.0.1_invalid_version)

ifeq ($(USE_MOMENTA_CMAKE),TRUE)
	ARCH ?= $(shell conan profile show default | sed -n "s/^arch=//p")
	OS ?= $(shell conan profile show default | sed -n "s/^os=//p")
	COMPILER_VERSION ?= $(shell conan profile show default | sed -n "s/^compiler\\.version=//p")
	MOMENTA_CMAKE ?= momenta-cmake --gcc=$(COMPILER_VERSION) --target_arch=$(ARCH)
	ifdef CUDA_VERSION
		CMAKE ?= $(MOMENTA_CMAKE) --cuda=$(CUDA_VERSION)
	else
		CMAKE ?= $(MOMENTA_CMAKE)
	endif
else
	ifdef CMAKE_TOOLCHAIN_FILE
		CMAKE ?= cmake -DCMAKE_TOOLCHAIN_FILE=$(CMAKE_TOOLCHAIN_FILE)
	else
		CMAKE ?= cmake
	endif
endif
default_build:
ifndef MMV_PLATFORM
	mkdir -p $(BUILD_DIR) && cd $(BUILD_DIR) && \
	$(CMAKE) $(CMAKE_ARGS) $(PROJECT_SOURCE_DIR) && \
	make -j $(NUM_JOB) && make install
else
	bash /bin/mph_build.sh
endif
.PHONY: default_build

CONAN_PROFILE ?= default
default_package:
	PACKAGE_SOURCE_DIR=$(PROJECT_SOURCE_DIR) \
	PACKAGE_BUILD_DIR=$(BUILD_DIR) \
	PACKAGE_INSTALL_DIR=$(INSTALL_DIR) \
	PACKAGE_NAME=$(PACKAGE_NAME) \
	PACKAGE_VERSION=$(PACKAGE_VERSION) \
	conan export-pkg . $(PACKAGE_ID) -f --profile $(CONAN_PROFILE)
CONAN_REMOTE ?= conan-pl
default_upload:
ifneq ($(CONAN_REMOTE),conan-pl)
	make conan_login
endif
	conan upload --all -r=$(CONAN_REMOTE) $(PACKAGE_ID)
.PHONY: default_package default_upload

force_clean:
	docker run --rm -v `pwd`:`pwd` -w `pwd` -it alpine/make make clean

default_deploy:
	conan install $(PACKAGE_ID) --profile $(CONAN_PROFILE) -g deploy -if $(CONAN_PKG_DIR)
	@echo exported conan package to $(CONAN_PKG_DIR)/$(PACKAGE_NAME)
	@mkdir -p $(DEPLOY_DIR)/modules
	@cp -rf -a $(CONAN_PKG_DIR)/$(PACKAGE_NAME) $(DEPLOY_DIR)/modules
	@echo exported deploy dir to $(DEPLOY_DIR)
	tar cvzf $(DEPLOY_DIR).tar.gz \
		-C $(shell dirname $(DEPLOY_DIR)) \
		$(shell basename $(DEPLOY_DIR))
	@echo 'created "$(DEPLOY_DIR).tar.gz", ready to deploy!'

BUILD_ENVS_JSON ?= build_envs.json
RUN_IN_BUILD_ENV_PY ?= run_in_build_env.py
RUN_IN_BUILD_ENV_EXTRA_ARGS ?= --extra-args="--network host"
RUN_IN_BUILD_ENV_BATCH_ARGS ?=
# 可以限制 build/package/upload_all 使用的环境
# RUN_IN_BUILD_ENV_BATCH_ARGS := --includes u16 devcar orin --

PYTHON3_EXE ?= python3
PYTHON3_RUN_IN_BUILD_ENV = $(PYTHON3_EXE) $(RUN_IN_BUILD_ENV_PY) $(RUN_IN_BUILD_ENV_EXTRA_ARGS)
build_all:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON) $(RUN_IN_BUILD_ENV_BATCH_ARGS) make build
package_all:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON) $(RUN_IN_BUILD_ENV_BATCH_ARGS) make package
upload_all:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON) $(RUN_IN_BUILD_ENV_BATCH_ARGS) make upload
.PHONY: build_all package_all upload_all

test_in_ubuntu: test_in_ubuntu16
test_in_u16: test_in_ubuntu16
test_in_u18: test_in_ubuntu18
test_in_u20: test_in_ubuntu20
test_in_ubuntu16:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@u16 bash
test_in_ubuntu18:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@u18 bash
test_in_ubuntu20:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@u20 bash
test_in_win64: test_in_win
test_in_win:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@win bash
test_in_mdc:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@mdc bash
test_in_mdc_old:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@mdc_old bash
test_in_qnx:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@qnx bash
test_in_qnx_with_cuda:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@qnx_with_cuda bash
test_in_mph:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@mph bash
test_in_orin:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@orin bash
test_in_orin_with_cuda:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@orin_with_cuda bash
test_in_orin_old:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@orin_old bash
test_in_devcar:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@devcar bash
test_in_devcar_with_cuda:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@devcar_with_cuda bash
test_in_manylinux:
	$(PYTHON3_RUN_IN_BUILD_ENV) --build-env $(BUILD_ENVS_JSON)@manylinux bash
# should able to run
#			make build package upload
# in build env

reset_submodules:
	git submodule update --init --recursive

conan_login:
	conan user -p $${CONAN_PASSWORD} -r $(CONAN_REMOTE) $${CONAN_USERNAME}
graph: graph.svg graph.dot
graph.dot: conanfile.py
	conan info --graph $@ conanfile.py # sudo apt install graphviz
graph.svg: graph.dot
	dot -Tsvg -o $@ $<
table:
	conan search $(PACKAGE_ID) -r=all  --table table.html

check_dependencies:
	# make graph
	python3 -m run_in_build_env.cli.check_package_remotes \
		--output $(BUILD_DIR)/dependencies.json \
		.
check_release:
	python3 -m run_in_build_env.cli.check_package_versions \
		--output-html $(BUILD_DIR)/releases.html \
		$(PACKAGE_ID)
# https://devops.momenta.works/Momenta/public/_git/conan-packages-bundle
PACKAGE_COMPATIBILITY_LIST ?= sample_bundle/0.0.2@momenta/stable
check_compatibility:
	python3 -m run_in_build_env.cli.check_package_compatibility \
		--package $(PACKAGE_ID) $(PACKAGE_COMPATIBILITY_LIST)

# for QNX CI
azure_pipelines_deploy:
	echo $$MMV_PROJECT_ROOT | grep workspace
	mkdir -p /root/workspace/mpilot_product_uniform_platform/modules/generic
	cp -rf `pwd` /root/workspace/mpilot_product_uniform_platform/modules/generic/repo

update_packaging_scripts:
	@echo "you need to manually update 'run_in_build_env' first"
	@echo "\tpython3 -m pip install --extra-index-url https://artifactory.momenta.works/artifactory/api/pypi/pypi-momenta/simple run_in_build_env -U"
	python3 -m run_in_build_env.cli.install package -y
.PHONY: update_packaging_scripts

# https://stackoverflow.com/a/25817631
echo-%  : ; @echo -n $($*)
Echo-%  : ; @echo $($*)
ECHO-%  : ; @echo $* = $($*)
echo-Tab: ; @echo -n '    '
# usage:
#		$ make echo-PACKAGE_ID
#		pingpong/0.0.2_rc2@momenta/stable%
#		$ make Echo-PACKAGE_ID
#		pingpong/0.0.2_rc2@momenta/stable
#		$ make ECHO-PACKAGE_ID
#		PACKAGE_ID = pingpong/0.0.2_rc2@momenta/stable
