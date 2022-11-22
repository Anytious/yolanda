from conans import ConanFile, tools
import os

class PackageConan(ConanFile):
    name = os.environ.get('PACKAGE_NAME')
    version = os.environ.get('PACKAGE_VERSION')
    settings = 'os', 'compiler', 'build_type', 'arch'
    description = ' mfr demo '
    url = ''
    license = 'mfr'
    topics = ()
    generators = 'cmake'
    requires = (
        'maf_interface/maf3.0.0_rc2@momenta/stable',
        'mf_mfruntime/v2.5.10_rc1@momenta/stable',
        'mf_mlog_core/v2.1.3-3-gc7ceec0@momenta/stable',
        'mf_mlog_publisher/v1.2.3@momenta/stable',
        'mf_mtime_core/v2.1.1-3-gec1f4f4@momenta/stable',
        'mf_mtime_customize_timeline/v1.1.4@momenta/stable',
        'mf_mjson/v2.1.0-4-g0a0c9d4@momenta/stable',
        'mf_mosadaptor/v1.0.2-2-g6430bf3@momenta/stable',
        'mf_mtaskflow/v1.0.7_for_maf3.0@momenta/stable',
    )
    build_requires = (
    )

    def package(self):
        source_dir = os.environ.get('PACKAGE_SOURCE_DIR')
        build_dir = os.environ.get('PACKAGE_BUILD_DIR')
        install_dir = os.environ.get('PACKAGE_INSTALL_DIR')
        assert self.copy('*.so', dst='lib',
                     src='{}/lib'.format(build_dir)), 'not any lib files'

        # deploy configs, scripts, etc
        self.copy('*',
              dst='launch',
              src='{}/launch'.format(source_dir))

        self.copy('*',
              dst='script',
              src='{}/script'.format(source_dir))


    def package_info(self):
        self.cpp_info.libs = tools.collect_libs(self)

    def imports(self):
        self.copy('*',
              dst='deploy/common/bin',
              src='bin',
              root_package='mf_mfruntime')
        self.copy('*',
              dst='deploy/common/bin',
              src='bin',
              root_package='jq')
        self.copy('*.so*', dst='deploy/common/lib', src='lib')
