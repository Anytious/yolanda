PROJECT_SOURCE_DIR ?= $(abspath ./)
BUILD_DIR ?= $(PROJECT_SOURCE_DIR)/build
INSTALL_DIR ?= $(BUILD_DIR)/install
CONAN_PKG_DIR ?= $(BUILD_DIR)/conan_package
DEPLOY_DIR ?= $(BUILD_DIR)/deploy
NUM_JOB ?= 8
# CONAN_REMOTE ?= conan-momenta

include package/utils.mk
BUILD_ENVS_JSON := package/build_envs.json
RUN_IN_BUILD_ENV_PY := package/run_in_build_env.py

all:
	@echo nothing special
clean:
	rm -rf $(BUILD_DIR)

lint: lintcpp lintcmake
lintcpp:
	# https://momenta.feishu.cn/wiki/wikcnNYoJacPCUYThGaEwi9MiPg
	# python3 -m pip install --extra-index-url https://artifactory.momenta.works/artifactory/api/pypi/pypi-momenta/simple mdk_tools -U
	@echo no need to run "python3 -m mdk_tools.cli.cpp_lint ." in this project
lintcmake:
	python3 -m mdk_tools.cli.cmake_lint .
lintpy:
	python3 -m mdk_tools.cli.py_lint .

PACKAGE_NAME ?= mfr_node_demo
PACKAGE_VERSION = 1.0

CMAKE_ARGS ?= \
	-DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR) \
	-DBUILD_SHARED_LIBS=OFF
build:
	make default_build
package:
	make default_package
upload: package
	make default_upload
deploy: package
	make default_deploy
.PHONY: build package upload deploy
