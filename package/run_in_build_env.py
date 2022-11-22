import sys
assert sys.version_info[:2] >= (
    3, 6
), "we can't live without f-string, so please install python>=3.6 (you may try 'future_fstrings')"

import os
import argparse
from pprint import pprint
from typing import Union, Set, Dict, List, Any, Tuple, Optional
from copy import deepcopy
import json

try:
    from loguru import logger
except ImportError:
    import logging as logger
    logger.basicConfig(level=logger.INFO)
    import atexit
    atexit.register(lambda: print(
        '\nTip:\n\tinstall loguru for better experience: "python3 -m pip install loguru"\n\n'
    ))

PWD = os.path.abspath(os.path.dirname(__file__))


def docker_tag_id(docker_tag: str):
    if 0 != os.system(
            f'docker inspect --type=image {docker_tag} >/dev/null 2>&1'):
        cmd = f'docker pull {docker_tag}'
        assert 0 == os.system(cmd), f'failed at {cmd}'
    cmd = 'docker inspect --format="{{index .Id}}" ' + docker_tag
    return os.popen(cmd).read().strip().split(':')[1][:8]


def load_build_envs(path: Optional[str] = None) -> List[Dict]:
    if not path:
        path = f'{PWD}/build_envs.json'
        logger.info(f'using bundled build_envs.json: {path}')
    else:
        path = os.path.abspath(path)
        logger.info(f'using provided build_envs.json: {path}')
    with open(path) as f:
        return json.load(f)


def select_build_env(text) -> Dict:
    """
        with
            text = build_envs.json@u16
            build_envs.json = [
                {
                    "id": "u16",
                    "docker_tag": "..."
                    ...
                },
                ...
            ]
        will return
            {
                "id": "u16",
                "docker_tag": "..."
                ...
            }
    """
    try:
        build_env_path, build_env_id = text.split('@')
        build_envs = load_build_envs(build_env_path)
        logger.info(
            f'candidate build envs: {[be.get("id") for be in build_envs]}')
        for be in build_envs:
            if build_env_id != be.get('id'):
                continue
            logger.info(f'build env: {text}')
            logger.info(json.dumps(be, indent=4, ensure_ascii=False))
            return be
    except Exception as e:
        logger.error(repr(e))
        raise Exception(f'invalid build env: {text}')


def run_in_build_env(
        *,
        build_env: Dict,
        source_dir: Optional[str] = None,
        build_dir_root: Optional[str] = None,
        docker_tag: Optional[str] = None,
        env_id: Optional[str] = None,
        extra_args: Optional[str] = None,
        volumes: Optional[List[str]] = None,
        env_file: Optional[str] = None,
        cmd: Union[str, List[str]] = 'bash',
        dry_run: bool = False,
) -> str:
    os.umask(0)
    docker_tag = docker_tag or build_env['docker_tag']
    env_id = env_id or build_env['id']

    source_dir = os.path.abspath(source_dir or os.getcwd())
    logger.info(f'source dir: {source_dir}')
    build_dir_root = os.path.abspath(build_dir_root or
                                     f'{source_dir}/build/repo')
    host_build_dir = f'{build_dir_root}/{env_id}'
    os.makedirs(host_build_dir, exist_ok=True)
    logger.info(f'host build dir: {host_build_dir}')

    volumes = volumes or []
    volumes.extend(build_env.get('volumes', []))

    envs = [f'RUN_IN_BUILD_ENV=TRUE', f'DOCKER_TAG_ID={env_id}']
    envs.extend(build_env.get('envs', []))

    RAW_VOLUMES = deepcopy(volumes)
    volumes.append(f'{source_dir}:{source_dir}')
    volumes.append(f'{host_build_dir}:{source_dir}/build')

    WORKDIR = source_dir

    # dirty handle MPH QNX build env, you can skip MPH build env and use QNX momenta-cmake version
    if env_id == 'mph' or env_id == 'blackberry_qnx':
        mph_project_root = '/root/workspace/mpilot_product_uniform_platform'
        imag_source_dir = f'{mph_project_root}/modules/generic/repo'
        host_build_dir = f'{build_dir_root}/{env_id}'
        host_install_dir = f'{host_build_dir}/install'
        os.makedirs(host_build_dir, exist_ok=True)
        os.makedirs(host_install_dir, exist_ok=True)
        volumes = RAW_VOLUMES  # reset volumes
        volumes.extend([
            f'{source_dir}:{imag_source_dir}',
            f'{host_build_dir}:{imag_source_dir}/build',
            f'{host_install_dir}:{imag_source_dir}/build/install',
            f'{host_install_dir}:{mph_project_root}/output/generic/repo',
        ])
        WORKDIR = imag_source_dir
        envs.append('MMV_PLATFORM=QNX-aarch64-gcc5.4')

    host_conan_data = f'{host_build_dir}/conan_data'
    os.makedirs(host_conan_data, exist_ok=True)
    logger.info(f'host conan data dir: {host_conan_data}')
    volumes.append(f'{host_conan_data}:/root/.conan/data')

    env_file = env_file or build_env.get('env_file')
    if env_file:
        env_file = os.path.abspath(env_file)
        if not os.path.isfile(env_file):
            logger.warning(f'invalid envfile: {env_file}')
            env_file = None
        else:
            logger.info(f'using envfile: {env_file}')

    cmd = cmd if isinstance(cmd, str) else ' '.join(cmd or ['bash'])

    logger.info('volumes:')
    pprint(volumes)
    logger.info('envs:')
    pprint(envs)
    logger.info(f'workdir: {WORKDIR}')
    logger.info(f'docker_tag: {docker_tag}')
    logger.info(f'command to run in build env: {cmd}')

    docker_cmd = [
        f'docker run --rm',
        extra_args or '',
        *[f'-e {env}' for env in envs],
        *[f'-v {vol}' for vol in volumes],
        f'-w {WORKDIR}',
        f'--env-file {env_file}' if env_file else '',
        f'-it {docker_tag}',
    ]
    docker_cmd = ' '.join([c for c in docker_cmd if c])

    cmd = f'{docker_cmd} {cmd}'
    logger.info(f'$ {cmd}')
    if dry_run:
        logger.info('dry running, skip')
        return cmd
    print('=' * 80)
    assert 0 == os.system(cmd), f'failed at {cmd}'
    logger.info(
        f'\nNote that artifacts are written to your host_build_dir:\n\t{host_build_dir}\nTry: tree --du -h -L 2 {host_build_dir}'
    )
    return cmd


def run_in_all_build_envs(
        build_envs: List[str],
        *,
        cmd: Union[str, List[str]] = 'bash',
        includes: Optional[List[str]] = None,
        excludes: Optional[List[str]] = None,
        build_dir_root: Optional[str] = None,
        extra_args: Optional[str] = None,
        dry_run: bool = False,
        strict_mode: bool = False,
) -> int:
    assert isinstance(build_envs, list), f'invalid build envs: {build_envs}'
    succ_envs = []
    failed_envs = []
    skip_envs = []
    for be in build_envs:
        env_id = be['id']
        if includes and env_id not in includes:
            logger.info(
                f'skip build env: {env_id}, not in includes: {includes}')
            skip_envs.append(env_id)
            continue
        if excludes and env_id in excludes:
            logger.info(f'skip build env: {env_id}, in excludes: {excludes}')
            skip_envs.append(env_id)
            continue
        if not includes and not excludes and be.get('disabled', False):
            logger.info(f'skip build env: {env_id}, disabled')
            skip_envs.append(env_id)
            continue
        try:
            run_in_build_env(
                build_env=be,
                cmd=cmd,
                build_dir_root=build_dir_root,
                extra_args=extra_args,
                dry_run=dry_run,
            )
            succ_envs.append(env_id)
        except Exception as e:
            if strict_mode:
                raise e
            logger.exception(e)
            failed_envs.append(env_id)
    if skip_envs:
        logger.warning(f'skipped to run {cmd} in {skip_envs}')
    if failed_envs:
        logger.error(f'failed to run {cmd} in {failed_envs}')
    logger.info(f'finished running {cmd} in {succ_envs}')
    return len(failed_envs)


def main():
    prog = 'python3 run_in_build_env.py'
    description = ('mount source into build env, with some extra operations')

    parser = argparse.ArgumentParser(prog=prog, description=description)
    parser.add_argument(
        '--build-env',
        help=f'docker tag or build_env_label, e.g. "artifactory.momenta.works/docker-momenta/ubuntu1604-python37:v0.1.8" (explicit) or "build_envs.json@u16 (extract from configuration)"',
    )
    parser.add_argument(
        '--env-id',
        type=str,
        help=f'will fallback to docker image id (hash) if not provided',
    )
    parser.add_argument(
        '--extra-args',
        type=str,
        help=f'extra args for "docker run", e.g. "--network host"',
    )
    parser.add_argument(
        '--volume',
        nargs='*',
        type=str,
        help=f'manually specify volumes to mount, e.g.: --volume <host_dir>:<container_dir>',
    )
    parser.add_argument(
        '--env-file',
        type=str,
        help=f'docker envfile (for environment variables). will silently ignore if env file not found, docs: https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file',
    )
    parser.add_argument(
        '--includes',
        type=str,
        nargs='+',
        help=f'build envs to include',
    )
    parser.add_argument(
        '--excludes',
        type=str,
        nargs='+',
        help=f'build envs to exclude',
    )
    parser.add_argument(
        '--build-dir-root',
        type=str,
        help=f'root of build dir, will bind <build_dir_root>/<env_id> to <source_dir>/build, default to <source_dir>/build/repo',
    )
    parser.add_argument(
        '--dry-run',
        default=False,
        action='store_true',
        help='dry run? default: off (note that directories can be created even when dry running)',
    )
    parser.add_argument(
        '--strict',
        default=False,
        action='store_true',
        help='in strict mode, failure in build env will stop whole process. default: off',
    )
    args, cmd_to_run = parser.parse_known_args()
    build_env: str = args.build_env
    env_id: Optional[str] = args.env_id
    extra_args: Optional[str] = args.extra_args
    volumes: List[str] = args.volume or []
    env_file: Optional[str] = args.env_file
    includes: List[str] = args.includes or []
    excludes: List[str] = args.excludes or []
    build_dir_root: Optional[str] = args.build_dir_root
    dry_run: bool = args.dry_run
    strict: bool = args.strict
    args = None

    if isinstance(cmd_to_run,
                  list) and len(cmd_to_run) > 1 and cmd_to_run[0] == '--':
        cmd_to_run = cmd_to_run[1:]

    if not build_env or build_env.endswith('.json'):
        if not cmd_to_run:
            parser.print_help()
            logger.warnig('implicit "bash" disabled in batch mode')
            sys.exit(-1)
        build_envs = load_build_envs(build_env)
        sys.exit(
            run_in_all_build_envs(
                build_envs,
                cmd=cmd_to_run,
                includes=includes,
                excludes=excludes,
                build_dir_root=build_dir_root,
                extra_args=extra_args,
                dry_run=dry_run,
                strict_mode=strict,
            ))

    if '@' in build_env:
        build_env = select_build_env(build_env)
        docker_tag = build_env['docker_tag']
        env_id = build_env['id']
    else:
        docker_tag = build_env
        env_id = env_id or docker_tag_id(docker_tag)
        build_env = {
            'id': env_id,
            'docker_tag': docker_tag,
        }

    run_in_build_env(
        build_env=build_env,
        build_dir_root=build_dir_root,
        docker_tag=docker_tag,
        env_id=env_id,
        extra_args=extra_args,
        volumes=volumes,
        env_file=env_file,
        cmd=cmd_to_run,
        dry_run=dry_run,
    )


if __name__ == '__main__':
    main()
