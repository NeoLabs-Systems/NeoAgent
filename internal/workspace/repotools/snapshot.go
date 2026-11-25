package repotools

// snapshot builds a git tree of the working copy from raw bytes, never through
// `git add` (which can run clean and process filters); directory descriptors
// refuse traversal through a parent symlink that changed (git_snapshot.js).
const snapshotPython = `
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
`

func snapshotCommand(status bool) string {
	cmd := "python3 -c " + ShellQuote(snapshotPython)
	if status {
		cmd += " --status"
	}
	return cmd
}

// snapshotLines is the snapshot contract shared by repo_overview, repo_diff
// and checkpoint tracking: sections "now" (the tree id) and, with status,
// "porcelain".
func snapshotLines(status bool) []string {
	lines := []string{
		"neo_tmp=$(mktemp -d) || exit 1",
		`trap 'rm -rf "$neo_tmp"' EXIT`,
		snapshotCommand(status) + ` >"$neo_tmp/snapshot" 2>"$neo_tmp/err" || { printf '%s\n' '@@neoagent:failed'; head -c 300 "$neo_tmp/err"; echo; exit 0; }`,
		`neo_now=$(sed -n '2p' "$neo_tmp/snapshot")`,
		`case "$neo_now" in ''|*[!0-9a-f]*) printf '%s\n' '@@neoagent:failed' 'The snapshot did not return a tree id.'; exit 0 ;; esac`,
		`printf "%s\n%s\n" "@@neoagent:now" "$neo_now"`,
	}
	if status {
		lines = append(lines, `printf '%s\n' '@@neoagent:porcelain'; tail -n +3 "$neo_tmp/snapshot"`)
	}
	return lines
}

// SnapshotCommand prints the repository root and a tree of the working copy as
// it is now (checkpoint tracking).
func SnapshotCommand() string { return snapshotCommand(false) }
