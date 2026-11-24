'use strict';

const { shellQuote } = require('../../utils/shell');

// These operations never need hooks, fsmonitor, a pager, filters or textconv.
const GIT_FUNCTION = 'g() { GIT_PAGER=cat git --no-optional-locks -c core.fsmonitor=false -c core.hooksPath=/dev/null -c log.showSignature=false -c submodule.recurse=false -c core.quotepath=off "$@"; }';

// Build an index from raw bytes, rather than `git add`: add can execute arbitrary
// clean/process filters. ls-files includes tracked ignored files and new files.
// Directory descriptors refuse traversal through a changed parent symlink.
const SNAPSHOT = String.raw`
import os, stat, subprocess, tempfile, sys
base = ['git', '--no-optional-locks', '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null']
def git(*args, data=None, env=None):
    return subprocess.check_output(base + list(args), input=data, env=env)
root = git('rev-parse', '--show-toplevel').decode().strip()
# Callers read the root and the tree as separate lines.
if any(c in root for c in '\n\r'): raise RuntimeError('The repository path contains a line break.')
os.chdir(root)
root_fd = os.open('.', os.O_RDONLY | os.O_DIRECTORY)
tracked = {}
for record in git('ls-files', '--stage', '-z').split(b'\0'):
    if not record: continue
    entry, name = record.split(b'\t', 1)
    mode, oid, stage = entry.split()
    if stage != b'0': raise RuntimeError('Resolve merge conflicts before taking a snapshot.')
    tracked[name] = (mode, oid)
names = set(tracked) | set(git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0'))
entries = []
for name in sorted(names - {b''}):
    parts = name.split(b'/')
    if any(p in (b'', b'.', b'..') for p in parts): raise RuntimeError('Invalid repository path.')
    parent = os.dup(root_fd)
    try:
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
            os.close(parent)
            parent = child
        info = os.stat(parts[-1], dir_fd=parent, follow_symlinks=False)
        if stat.S_ISLNK(info.st_mode):
            data = os.fsencode(os.readlink(parts[-1], dir_fd=parent))
            mode = b'120000'
        elif stat.S_ISREG(info.st_mode):
            fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
            with os.fdopen(fd, 'rb') as source:
                if not stat.S_ISREG(os.fstat(source.fileno()).st_mode): raise RuntimeError('File type changed.')
                data = source.read()
            mode = b'100755' if info.st_mode & 0o111 else b'100644'
        elif name in tracked and tracked[name][0] == b'160000':
            mode, oid = tracked[name]
            entries.append(mode + b' ' + oid + b'\t' + name + b'\0')
            continue
        else:
            continue
        oid = git('hash-object', '-w', '--no-filters', '--stdin', data=data).strip()
        entries.append(mode + b' ' + oid + b'\t' + name + b'\0')
    except FileNotFoundError:
        continue
    finally:
        os.close(parent)
os.close(root_fd)
with tempfile.TemporaryDirectory(prefix='neoagent-snapshot-') as temporary:
    env = dict(os.environ, GIT_INDEX_FILE=os.path.join(temporary, 'index'))
    initial = b''.join(mode + b' ' + oid + b'\t' + name + b'\0' for name, (mode, oid) in tracked.items())
    git('update-index', '-z', '--index-info', data=initial, env=env)
    indexed = git('write-tree', env=env).decode().strip()
    os.unlink(env['GIT_INDEX_FILE'])
    git('update-index', '-z', '--index-info', data=b''.join(entries), env=env)
    tree = git('write-tree', env=env).decode().strip()
print(root)
print(tree)
if '--status' in sys.argv:
    def changes(left, right):
        data = git('diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--name-status', '-z', left, right).split(b'\0')
        return {data[i+1]: data[i].decode() for i in range(0, len(data)-1, 2)}
    head = subprocess.run(base + ['rev-parse', '--verify', 'HEAD'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    base_tree = head.stdout.decode().strip() if head.returncode == 0 else git('hash-object', '-t', 'tree', '--stdin', data=b'').decode().strip()
    staged = changes(base_tree, indexed)
    unstaged = changes(indexed, tree)
    for name in sorted(set(staged) | set(unstaged)):
        status = '??' if name not in tracked and name not in staged else staged.get(name, ' ') + unstaged.get(name, ' ')
        shown = os.fsdecode(name)
        if any(c in shown for c in '\n\r\t'): shown = repr(shown)
        print(status + ' ' + shown)
`;

function snapshotCommand({ status = false } = {}) {
  return `python3 -c ${shellQuote(SNAPSHOT)}${status ? ' --status' : ''}`;
}

// Common snapshot contract for repo_diff and checkpoint tracking.
function snapshotLines({ status = true } = {}) {
  return [
    'neo_tmp=$(mktemp -d) || exit 1',
    'trap \'rm -rf "$neo_tmp"\' EXIT',
    `${snapshotCommand({ status })} >"$neo_tmp/snapshot" 2>"$neo_tmp/err" || { printf '%s\\n' '@@neoagent:failed'; head -c 300 "$neo_tmp/err"; echo; exit 0; }`,
    "neo_now=$(sed -n '2p' \"$neo_tmp/snapshot\")",
    // The tree goes to git as a revision, so it must be an object id and nothing else.
    "case \"$neo_now\" in ''|*[!0-9a-f]*) printf '%s\\n' '@@neoagent:failed' 'The snapshot did not return a tree id.'; exit 0 ;; esac",
    'printf "%s\\n%s\\n" "@@neoagent:now" "$neo_now"',
    ...(status ? ["printf '%s\\n' '@@neoagent:porcelain'; tail -n +3 \"$neo_tmp/snapshot\""] : []),
  ];
}

module.exports = { GIT_FUNCTION, snapshotCommand, snapshotLines };
