# run in build env

`run_in_build_env` 是一个 python pip 包。安装后可以让你快速地在编译镜像[^1] 中

-   编译（使用 cmake 或 momenta-cmake） 、
-   发版（使用 conan）

自己的 c++ 模块。

[^1]: 预设或自提供，概念见 [conan 新手入门：以 tb-core 模块为例](https://momenta.feishu.cn/wiki/wikcna17fI8Gr9aHCx45ntL2qWe#CChFth) 【什么是 build env】小节。

## 使用方法

安装线上最新版本（建议 >= 0.3.8）：

```
# pip 安装
$ python3 -m pip install --extra-index-url https://artifactory.momenta.works/artifactory/api/pypi/pypi-momenta/simple run_in_build_env -U

# 查看版本
$ python3 -c 'import run_in_build_env; print(run_in_build_env.__version__)'
```

安装 pip 包后，有两种使用方法：

1. 使用 pip 【全局】安装的 run_in_build_env，直接进入编译镜像编译、打包、发版
2. 【固化】当前版本的 run_in_build_env 到自己的代码仓库，整合到自己仓库的使用流程中

建议参考 [tb-core](https://momenta.feishu.cn/wiki/wikcna17fI8Gr9aHCx45ntL2qWe) 工程固化使用。

### 方法 1：全局安装、直接使用

直接挂载当前文件夹（源码目录）到编译镜像中：

```
python3 -m run_in_build_env --build-env @u16                            # 使用预设编译镜像（从默认配置文件选择）
python3 -m run_in_build_env --build-env <docker-tag>                    # 使用自己提供的镜像
python3 -m run_in_build_env --build-env path/to/build_envs.json@qnx     # 从自己的配置文件中选择镜像
```

以 tb-core 工程为例，clone 代码后，运行 `python3 -m run_in_build_env --build-env @orin` 进入编译镜像，
使用 `make build` 就可以在 Orin 交叉编译环境下编译这个模块。

这种非侵入式方法适合快速交叉编译测试。

### 方法 2：固化并整合到代码仓库

固化安装：

```
# 首先进入源码目录
python3 -m run_in_build_env.cli.install package --yes                   # 安装到 package 文件夹
# 如果已经固化过，可以运行
make update_packaging_scripts
```

安装需要确认 `package/version.py` 中的版本和预期的一致。

整合流程：

安装后需要修改自己的 Makefile，把编译、打包、发版流程整合到当前模块的研发周期中。
具体可以参考 tb-core 模块，这里标注一些要点：

```
# 常规配置的一些变量
PROJECT_SOURCE_DIR ?= $(abspath ./)
BUILD_DIR ?= $(PROJECT_SOURCE_DIR)/build
INSTALL_DIR ?= $(BUILD_DIR)/install
CONAN_PKG_DIR ?= $(BUILD_DIR)/conan_package
DEPLOY_DIR ?= $(BUILD_DIR)/deploy
NUM_JOB ?= 8

# 默认上传到 conan-pl
# 如果要上传到 conan-momenta 的话，需要参考 <http://topbind.hdmap.momenta.works/conan_intro/#artifactory> 配置环境变量
# 并把下面的行解注释
# CONAN_REMOTE := conan-momenta

# 引入 run_in_build_env 提供的逻辑。我们安装位置为 package 文件夹，所以如此引入：
include package/utils.mk
# 使用的配置文件和 python 脚本
BUILD_ENVS_JSON := package/build_envs.json
RUN_IN_BUILD_ENV_PY := package/run_in_build_env.py

all:
    @echo nothing special
clean:
    rm -rf $(BUILD_DIR)
force_clean:
    docker run --rm -v `pwd`:`pwd` -w `pwd` -it alpine/make make clean

PACKAGE_NAME := tb_core
# 三种 package id 逻辑，把相应的代码解注释来激活你的选择
# 1.    默认：                                          tb_core/2022.01.12_11.00.37_bb36ef95@momenta/stable
# 2.    加上后缀，第三方库推荐这种                          tb_core/2022.01.12_11.00.37_bb36ef95_v0.0.1@momenta/stable
#       需要打开下面这一行
#               PACKAGE_VERSION_SUFFIX := _v0.0.1
# 3.    使用 CHANGELOG.md 中的版本，算法模块推荐这种        tb_core/0.0.1@momenta/stable
#       需要打开下面这一行
#               PACKAGE_VERSION := $(VERSION_FULL)

# cmake 参数
CMAKE_ARGS := \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=RelWithDebugInfo \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR)
# 直接使用 package/utils.mk 中预设的编译、打包、上传逻辑
build:
    make default_build
package:
    make default_package
upload: package
    make default_upload
# 如果你没有部署逻辑，可以留空
deploy:
    @echo not implemented
.PHONY: build package upload deploy

# 如果你希望在 build_all, package_all, upload_all 时不要使用全部环境，
# 打开下面这一行提供过滤参考（详见 run_in_build_env.py --help）
# RUN_IN_BUILD_ENV_BATCH_ARGS := --includes u16 devcar orin --
# 然后 `make build_all` 就只在 u16/devcar/orin 环境下运行了

# 也可以定义自己的 build/package/upload_all 命令
# 临时只在这些环境下 build/package/upload
my_build_all:
    python3 $(RUN_IN_BUILD_ENV_PY) --build-env $(BUILD_ENVS_JSON) --includes u16 devcar orin -- make build
my_package_all:
    python3 $(RUN_IN_BUILD_ENV_PY) --build-env $(BUILD_ENVS_JSON) --includes u16 devcar orin -- make package
my_upload_all:
    python3 $(RUN_IN_BUILD_ENV_PY) --build-env $(BUILD_ENVS_JSON) --includes u16 devcar orin -- make upload
```

配置好 Makefile 后，可以通过 `make test_in_orin` 进入 orin 交叉编译环境进行 `make build package` 编译、打包等操作。
更多编译镜像可以通过 `make test_in_<TAB>` 补全的方式查看。也可以直接查看 `package/utils.mk`、`package/build_envs.json` 等固化到仓库的文件。

固化使用 run_in_build_env，编译镜像和编译脚本都锁定了，模块研发人员对编译工具链的控制力更强。
下次更新 run_in_build_env 再次固化的时候，也更明确此次更新的改动项。

>   注意：
>   -   如果你需要使用 cuda，编译镜像可能需要使用 `with_cuda` 的版本（`make test_in_orin` 改成 `make test_in_orin_with_cuda`）
>   -   更新固化版本后需要检查是否有自己的配置被覆盖了

## 样例工程

-   [tb-core](https://devops.momenta.works/Momenta/public/_git/topbind-tb-core)
    -   [CI](https://devops.momenta.works/Momenta/public/_build?definitionId=1796)
    -   [文档：conan 新手入门：以 tb-core 模块为例](https://momenta.feishu.cn/wiki/wikcna17fI8Gr9aHCx45ntL2qWe)
-   [sample-pingpong](https://devops.momenta.works/Momenta/public/_git/sample-pingpong)
    -   [CI](https://devops.momenta.works/Momenta/public/_build?definitionId=1870)
    -   [算法模块的开发、发版与部署：以 sample-pingpong 为例](https://momenta.feishu.cn/wiki/wikcnG9UqX28VCZttDzoTf1Nk0c)

## MISC

-   各编译镜像来源：<http://topbind.hdmap.momenta.works/docker/#build_envs>
-   飞书文档：<https://momenta.feishu.cn/wiki/wikcnqcj1SnVmEfBVm074NFS06A> （会定期合并回本 README）
