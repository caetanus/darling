#!/usr/bin/env python3
"""OSXER PREFIX (regression): native prefix setup, no Darling or mounts.

Run via build-new-prefix.py in the workspace for the RAM guard/build lock.
The fixtures follow setupPrefix's writable layout and shellspawn.h's socket
contract, plus gallery/ref/prefix-compare.txt's incomplete-prefix observation.
All temporary files, compiler output and synthetic prefixes stay in this repo.
"""
import argparse
import errno
import os
from pathlib import Path
import shlex
import socket
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--launcher-source", type=Path,
                        default=repo / "src/startup/darling.c")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="prefix-native-", dir=repo) as temp:
        scratch = Path(temp)
        env = dict(os.environ, TMPDIR=temp, TMP=temp, TEMP=temp, CCACHE_DISABLE="1")
        (scratch / "darling-config.h").write_text(
            '#define INSTALL_PREFIX "/unused"\n'
            '#define SYSTEM_ROOT "/Volumes/SystemRoot"\n'
            '#define GIT_BRANCH "native-test"\n'
            '#define GIT_COMMIT_HASH "native-test"\n')
        compiler = shlex.split(os.environ.get("CC", "cc"))
        common = compiler + ["-std=gnu11", "-D_GNU_SOURCE", "-Wall", "-Wextra",
                             "-I", str(scratch), "-I", str(repo / "src/startup")]
        obj = scratch / "darling.o"
        subprocess.run(common + ["-Dmain=darling_launcher_main", "-c",
                                  str(args.launcher_source), "-o", str(obj)],
                       env=env, check=True)
        binary = scratch / "prefix-test"
        wrappers = ("geteuid", "setuid", "setgid", "seteuid", "setegid",
                    "getpwuid", "stat", "unshare")
        subprocess.run(common + [str(Path(__file__).with_suffix(".c")), str(obj),
                                  "-lutil", "-o", str(binary)] +
                       [f"-Wl,--wrap={name}" for name in wrappers], env=env, check=True)

        socket_denied = False

        def bind_socket(sock, directory, relative_path):
            nonlocal socket_denied
            previous = Path.cwd()
            try:
                os.chdir(directory)
                sock.bind(relative_path)
                return True
            except PermissionError as error:
                if error.errno != errno.EPERM:
                    raise
                if not socket_denied:
                    print("SKIP: socket bind denied by sandbox; writable parent still checked",
                          flush=True)
                    socket_denied = True
                return False
            finally:
                os.chdir(previous)

        def run(prefix, *, changed=True, error=None, wrong_owner=False):
            command = [str(binary), str(prefix)]
            if wrong_owner:
                command.append("wrong-owner")
            result = subprocess.run(command, env=env, capture_output=True, text=True,
                                    timeout=10)
            if error:
                assert result.returncode == 1, (prefix.name, result.stderr)
                assert error in result.stderr, (prefix.name, result.stderr)
            else:
                assert result.returncode == 0, (prefix.name, result.stderr)
                if changed is not None:
                    assert f"PREFIX_CHANGED={int(changed)}" in result.stdout, prefix.name

        def layout(prefix):
            for directory in ("Volumes", "Applications", "usr/local/share",
                              "private/var/log", "private/var/db", "private/etc",
                              "var/run", "var/tmp", "var/log"):
                assert (prefix / directory).is_dir(), f"{prefix.name}: missing {directory}"
            for name in ("passwd", "master.passwd", "group"):
                content = (prefix / "private/etc" / name).read_text()
                assert "prefix-test-user" in content, (prefix.name, name)
                assert content.count("_trustd:") == 1, (prefix.name, name)
                if name != "group":
                    assert "root:*:0:0:" in content, (prefix.name, name)
                    assert ":/Users/prefix-test-user:/bin/bash\n" in content
            # Host-visible socket path the launcher polls, with no overlay mount.
            path = prefix / "var/run/shellspawn.sock"
            # Pure filesystem check remains mandatory even in a socket sandbox.
            with path.open("xb") as probe:
                probe.write(b"native layout probe\n")
            assert path.read_bytes() == b"native layout probe\n"
            path.unlink()
            # AF_UNIX has a short path limit; bind relative to the scratch prefix.
            try:
                with socket.socket(socket.AF_UNIX) as sock:
                    if bind_socket(sock, prefix, "var/run/shellspawn.sock"):
                        assert path.exists()
            finally:
                path.unlink(missing_ok=True)

        def snapshot(prefix):
            return {p.relative_to(prefix): (p.read_bytes(), p.stat().st_mtime_ns)
                    for p in prefix.rglob("*") if p.is_file()}

        # Check the reported regression first, so the original launcher fails here.
        empty = scratch / "empty"
        empty.mkdir()
        run(empty, changed=None)
        layout(empty)
        print("PASS: existing empty prefix", flush=True)

        missing = scratch / "missing"
        run(missing)
        layout(missing)
        print("PASS: absent prefix", flush=True)

        partial = scratch / "partial"
        (partial / "Users/Shared").mkdir(parents=True)
        (partial / "Users/prefix-test-user").mkdir()
        (partial / ".init.pid").write_text("123456\n")
        with socket.socket(socket.AF_UNIX) as server:
            have_socket = bind_socket(server, partial, ".darlingserver.sock")
            run(partial)
            layout(partial)
            if have_socket:
                assert (partial / ".darlingserver.sock").exists()
            assert (partial / ".init.pid").read_text() == "123456\n"
        print("PASS: partial prefix matching supplied layout", flush=True)

        for mode in ("overlayfs", "fuse-overlayfs", "copy"):
            prefix = scratch / mode
            prefix.mkdir()
            (prefix / ".darling-fsmode").write_text(mode + "\n")
            run(prefix)
            layout(prefix)
            assert (prefix / ".darling-fsmode").read_text() == mode + "\n"
        print("PASS: filesystem-mode selection survives initialization", flush=True)

        for name in ("passwd", "master.passwd", "group"):
            with (empty / "private/etc" / name).open("a") as account:
                account.write("# existing user configuration\n")
        before = snapshot(empty)
        run(empty, changed=False)
        layout(empty)
        assert snapshot(empty) == before
        (empty / "var/run").rmdir()
        run(empty)
        layout(empty)
        assert snapshot(empty) == before
        (empty / "private/etc/group").unlink()
        run(empty)
        layout(empty)
        after = snapshot(empty)
        for name, data in before.items():
            if name.name != "group":
                assert after[name] == data
        print("PASS: repeat/repair preserves existing account files", flush=True)

        legacy = scratch / "legacy"
        run(legacy)
        targets = scratch / "synthetic-accounts"
        targets.mkdir()
        for name in ("passwd", "master.passwd", "group"):
            target = targets / name
            target.write_text("# synthetic legacy account database\n")
            path = legacy / "private/etc" / name
            path.unlink()
            path.symlink_to(target)
        before = snapshot(targets)
        (legacy / "var/run").rmdir()
        run(legacy)
        assert snapshot(targets) == before
        for name in ("passwd", "master.passwd", "group"):
            assert (legacy / "private/etc" / name).is_symlink()
        (targets / "passwd").unlink()
        run(legacy, changed=False)
        assert not (targets / "passwd").exists()  # dangling symlink stays intact
        print("PASS: legacy account symlinks are never followed for writes", flush=True)

        linked = scratch / "linked-var"
        (linked / "private/var").mkdir(parents=True)
        (linked / "var").symlink_to("private/var")
        run(linked)
        layout(linked)
        assert (linked / "var").is_symlink()
        run(linked, changed=False)
        print("PASS: existing relative var symlink", flush=True)

        bad = scratch / "not-a-directory"
        bad.write_text("preserve me\n")
        run(bad, error="is a file")
        assert bad.read_text() == "preserve me\n"
        conflict = scratch / "directory-conflict"
        conflict.mkdir()
        (conflict / "private").write_text("preserve me\n")
        run(conflict, error="is a file")
        assert (conflict / "private").read_text() == "preserve me\n"
        owner = scratch / "wrong-owner"
        owner.mkdir()
        run(owner, error="You do not own", wrong_owner=True)
        assert list(owner.iterdir()) == []
        denied = scratch / "read-only"
        denied.mkdir(mode=0o555)
        try:
            run(denied, error="Cannot create")
        finally:
            denied.chmod(0o755)
        print("PASS: type, ownership and permission errors stop initialization", flush=True)

    print("PASS: native prefix regression; scratch removed", flush=True)


if __name__ == "__main__":
    main()
