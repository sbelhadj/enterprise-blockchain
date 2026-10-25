#!/usr/bin/env python3
"""
Author's capture harness, not a reader step.

Runs the services of a Docker Compose project as local processes, for a machine with the Docker
CLI but no Docker daemon. The Compose files stay the single source of truth: the project is
resolved with `docker compose config --format json`, and each service starts with the environment,
command and ports that file gives it. Container paths are translated to host paths:

  - bind mounts map to their source folders
  - named volumes map to folders under the harness data directory (deleted by `down -v`)
  - paths the Fabric images provide map to the matching folders of a fabric-samples installation:
      /etc/hyperledger/fabric        -> fabric-samples/config (core.yaml, orderer.yaml)
      /opt/hyperledger/ccaas_builder -> fabric-samples/builders/ccaas
      /bin/prometheus                -> the Prometheus binary named by PROMETHEUS_BIN
  - the working directory of a service built from a local context maps to that context
    (the chaincode must be built there first with npm ci and npm run build)
  - a bind mount at /var/hyperledger/snapshots, whose paths clients pass to a peer, is also
    linked at that path on the host, so the same path works in both worlds

Every container name is mapped to 127.0.0.1 in /etc/hosts, which works because the Compose files
give every service its own listening ports. Usage mirrors the docker compose subcommands the
chapter scripts use:

  compose-native.py [-f FILE]... [--env-file FILE] up -d [SERVICE]...
  compose-native.py [-f FILE]... [--env-file FILE] stop|start|logs|ps [SERVICE]...
  compose-native.py [-f FILE]... [--env-file FILE] down [-v]
"""
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAMPLES = os.environ.get('SAMPLES', os.path.expanduser('~/fabric-samples'))
IMAGE_PATHS = {
    '/etc/hyperledger/fabric': os.path.join(SAMPLES, 'config'),
    '/opt/hyperledger/ccaas_builder': os.path.join(SAMPLES, 'builders', 'ccaas'),
    '/bin/prometheus': os.environ.get('PROMETHEUS_BIN', '/usr/local/bin/prometheus'),
}


SHARED_PREFIX = '/var/hyperledger/snapshots'
DEFAULT_PATHS = {
    'hyperledger/fabric-peer': {
        'CORE_PEER_FILESYSTEMPATH': '/var/hyperledger/production',
        'CORE_LEDGER_SNAPSHOTS_ROOTDIR': '/var/hyperledger/production/snapshots',
        # core.yaml's builder entry, so its path can be translated like the others
        'CORE_CHAINCODE_EXTERNALBUILDERS': '[{name: ccaas_builder, path: /opt/hyperledger/'
                                           'ccaas_builder, propagateEnvironment: '
                                           '[CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG]}]',
    },
    'hyperledger/fabric-orderer': {
        'ORDERER_FILELEDGER_LOCATION': '/var/hyperledger/production/orderer',
        'ORDERER_CONSENSUS_WALDIR': '/var/hyperledger/production/orderer/etcdraft/wal',
        'ORDERER_CONSENSUS_SNAPDIR': '/var/hyperledger/production/orderer/etcdraft/snapshot',
    },
}


def parse(argv):
    files, env_file, rest = [], None, []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '-f':
            files.append(argv[i + 1]); i += 2
        elif a == '--env-file':
            env_file = argv[i + 1]; i += 2
        else:
            rest.append(a); i += 1
    return files, env_file, rest


def resolve(files, env_file):
    cmd = ['docker', 'compose']
    if env_file:
        cmd += ['--env-file', env_file]
    for f in files:
        cmd += ['-f', f]
    out = subprocess.run(cmd + ['config', '--format', 'json'], check=True,
                         capture_output=True, text=True).stdout
    return json.loads(out)


def unescape(s):
    return s.replace('$$', '$')


def mapping(project, name, svc, data):
    m = dict(IMAGE_PATHS)
    for v in svc.get('volumes', []):
        if v['type'] == 'bind':
            m[v['target']] = v['source']
        elif v['type'] == 'volume':
            m[v['target']] = os.path.join(data, 'volumes', v['source'])
    if 'build' in svc and svc.get('working_dir'):
        m[svc['working_dir']] = svc['build']['context']
    return m


def translate(value, m):
    # replace the longest matching container path prefix in every path-like token
    for target in sorted(m, key=len, reverse=True):
        value = re.sub(r'(?<![\w/.-])' + re.escape(target) + r'(?=/|$|[^\w.-])', m[target], value)
    return value


def launcher(project, name, svc, data):
    m = mapping(project, name, svc, data)
    for target, source in m.items():
        if target not in IMAGE_PATHS and not os.path.exists(source):
            os.makedirs(source)          # Docker creates a missing bind source as a folder
        # A client passes this path to the peer (peer channel joinbysnapshot), so it must
        # resolve on the host as it does in the container: link it to the bind source.
        if target.startswith(SHARED_PREFIX):
            if os.path.islink(target) and os.readlink(target) != source:
                os.remove(target)              # left behind by another project
            if not os.path.islink(target):
                os.makedirs(os.path.dirname(target), exist_ok=True)
                os.symlink(source, target)
    env = {k: translate(unescape(str(v)), m) for k, v in (svc.get('environment') or {}).items()}
    cmd = svc.get('command') or []
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    cmd = list(svc.get('entrypoint') or []) + cmd
    cmd = [translate(unescape(c), m) for c in cmd]
    if not cmd:
        raise SystemExit(f'{name}: no command in the Compose file')
    cwd = translate(svc.get('working_dir', ''), m) or os.path.join(data, name)
    os.makedirs(cwd, exist_ok=True)
    lines = ['#!/usr/bin/env bash', f'# {name} ({svc.get("container_name", name)})',
             f'cd {shlex.quote(cwd)}',
             f'export PATH={shlex.quote(os.path.join(SAMPLES, "bin"))}:$PATH']
    if 'FABRIC_CFG_PATH' not in env and svc.get('image', '').startswith('hyperledger/fabric-'):
        env['FABRIC_CFG_PATH'] = IMAGE_PATHS['/etc/hyperledger/fabric']
    # Paths that core.yaml and orderer.yaml set by default; in a container the volumes sit there.
    for prefix, defaults in DEFAULT_PATHS.items():
        if svc.get('image', '').startswith(prefix):
            for k, v in defaults.items():
                env.setdefault(k, translate(v, m))
    for k, v in sorted(env.items()):
        lines.append(f'export {k}={shlex.quote(v)}')
    lines.append('exec ' + ' '.join(shlex.quote(c) for c in cmd))
    path = os.path.join(data, name + '.sh')
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    return path


def hosts(cfg):
    names = sorted({s.get('container_name') for s in cfg['services'].values()} - {None})
    current = open('/etc/hosts').read()
    missing = [n for n in names if not re.search(r'\s' + re.escape(n) + r'(\s|$)', current)]
    if missing:
        with open('/etc/hosts', 'a') as f:
            f.write('127.0.0.1 ' + ' '.join(missing) + '\n')


def running(data, name):
    try:
        pid = int(open(os.path.join(data, name + '.pid')).read())
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError):
        return None


def start(data, name):
    if running(data, name):
        return
    log = open(os.path.join(data, name + '.log'), 'a')
    p = subprocess.Popen(['bash', os.path.join(data, name + '.sh')], stdout=log,
                         stderr=subprocess.STDOUT, start_new_session=True)
    open(os.path.join(data, name + '.pid'), 'w').write(str(p.pid))


def stop(data, name):
    pid = running(data, name)
    if pid:
        os.killpg(pid, signal.SIGTERM)
        for _ in range(50):
            if not running(data, name):
                break
            time.sleep(0.1)
        else:
            os.killpg(pid, signal.SIGKILL)
    try:
        os.remove(os.path.join(data, name + '.pid'))
    except FileNotFoundError:
        pass


def main():
    files, env_file, rest = parse(sys.argv[1:])
    cfg = resolve(files, env_file)
    project = cfg['name']
    data = os.environ.get('NATIVE_DATA', os.path.join(REPO, 'work', 'compose-native', project))
    os.makedirs(data, exist_ok=True)
    op, args = rest[0], [a for a in rest[1:] if not a.startswith('-')]
    services = args or sorted(cfg['services'])
    if op == 'up':
        hosts(cfg)
        for name in services:
            old = os.path.join(data, name + '.sh')
            before = open(old).read() if os.path.exists(old) else None
            launcher(project, name, cfg['services'][name], data)
            # like docker compose up: a running service whose configuration changed is
            # recreated, one whose configuration is the same is left alone
            if running(data, name) and before != open(old).read():
                stop(data, name)
            start(data, name)
            print(f' Container {cfg["services"][name].get("container_name", name)}  Started')
    elif op == 'start':
        for name in services:
            start(data, name)
    elif op == 'stop':
        for name in services:
            stop(data, name)
    elif op == 'logs':
        for name in services:
            sys.stdout.write(open(os.path.join(data, name + '.log')).read())
    elif op == 'ps':
        for name in services:
            print(name, 'running' if running(data, name) else 'stopped')
    elif op == 'down':
        # every service with a pid file, including ones from Compose files not named this
        # time, as docker compose down --remove-orphans removes the project's other containers
        started = {f[:-4] for f in os.listdir(data) if f.endswith('.pid')}
        for name in sorted(set(cfg['services']) | started):
            stop(data, name)
        if '-v' in rest:
            subprocess.run(['rm', '-rf', os.path.join(data, 'volumes')], check=True)
            if os.path.islink(SHARED_PREFIX):
                os.remove(SHARED_PREFIX)
        for f in os.listdir(data):
            if f.endswith(('.sh', '.pid', '.log')):
                os.remove(os.path.join(data, f))
    elif op == 'volume-rm':
        # stands in for docker volume rm PROJECT_NAME: deletes the volume's folder
        for name in args:
            vol = name[len(project) + 1:] if name.startswith(project + '_') else name
            subprocess.run(['rm', '-rf', os.path.join(data, 'volumes', vol)], check=True)
            print(name)
    else:
        raise SystemExit(f'unsupported command: {op}')


if __name__ == '__main__':
    main()
