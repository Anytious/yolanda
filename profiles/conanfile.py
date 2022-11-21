from conans import ConanFile, tools
import os


class PackageConan(ConanFile):
  name = os.environ.get('PACKAGE_NAME')
  version = os.environ.get('PACKAGE_VERSION')
  # it's header-only!
  settings = 'os', 'compiler', 'build_type', 'arch'
  description = '提供一套通用的多线程框架，以解决传统多线程编程中信号量，同步锁编写困难的问题'
  url = 'https://devops.momenta.works/Momenta/mf/_git/mtaskflow'
  license = 'Momenta Limited, Inc'
  topics = None
  generators = 'cmake'
  requires = (
    'mf_mosadaptor/v1.0.2-2-g6430bf3@momenta/stable'
  )

  build_requires = (
    'mf_mjson/v2.1.0-3-g67d70f2@momenta/stable',  # header-only, no need to expose
    'google_test/2021.05.19@momenta/stable'
  )

  def package(self):
    source_dir = os.environ.get('PACKAGE_SOURCE_DIR')
    build_dir = os.environ.get('PACKAGE_BUILD_DIR')
    install_dir = os.environ.get('PACKAGE_INSTALL_DIR')
    self.copy('*', dst='include', src='{}/include'.format(source_dir), symlinks=True)
    self.copy('*', dst='include', src='{}/src/core/common/include'.format(source_dir), symlinks=True)
    self.copy('*.h', dst='include', src='{}/src/core/common/src'.format(source_dir), symlinks=True)
    self.copy('*', dst='lib', src='{}/lib'.format(install_dir), symlinks=True)
    self.copy('*', dst='bin', src='{}/bin'.format(install_dir), symlinks=True)

  def imports(self):
    source_dir = os.environ.get('PACKAGE_SOURCE_DIR')
    build_dir = os.environ.get('PACKAGE_BUILD_DIR')
    install_dir = os.environ.get('PACKAGE_INSTALL_DIR')

    self.copy("*.so", dst='require_lib', src='lib')


  def package_info(self):
    self.cpp_info.libs = tools.collect_libs(self)
