#!/usr/bin/env python3
"""Safely install the sole las-dsh-environment skill file."""
import argparse
import os
import secrets
import stat
import sys


def fail(message):
    raise RuntimeError(message)


def directory(parent_fd, name, uid, gid):
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    try:
        fd = os.open(name, flags, dir_fd=parent_fd)
    except FileNotFoundError:
        os.mkdir(name, 0o700, dir_fd=parent_fd)
        fd = os.open(name, flags, dir_fd=parent_fd)
    info = os.fstat(fd)
    if not stat.S_ISDIR(info.st_mode):
        os.close(fd)
        fail(f"unsafe skill path component: {name}")
    os.fchmod(fd, 0o700)
    os.fchown(fd, uid, gid)
    return fd


def existing_skill(bundle_fd):
    try:
        fd = os.open("SKILL.md", os.O_RDONLY | os.O_NOFOLLOW, dir_fd=bundle_fd)
    except FileNotFoundError:
        return None
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode):
        os.close(fd)
        fail("unsafe SKILL.md type")
    if info.st_nlink != 1:
        os.close(fd)
        fail("unsafe SKILL.md hardlink")
    return fd


def test_failure(point):
    if os.environ.get("DSH_SKILL_TEST_FAIL_AT") == point:
        raise OSError(f"injected {point} failure")


def write_all(fd, content):
    maximum = int(os.environ.get("DSH_SKILL_TEST_MAX_WRITE", "0"))
    if os.environ.get("DSH_SKILL_TEST_FAIL_AT") == "write-after-short":
        maximum = 1
    offset = 0
    while offset < len(content):
        chunk = content[offset:] if maximum <= 0 else content[offset:offset + maximum]
        written = os.write(fd, chunk)
        if written <= 0:
            fail("could not write skill candidate")
        offset += written
        if offset < len(content):
            test_failure("write-after-short")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill-file", required=True)
    args = parser.parse_args()
    dsh_home = os.environ.get("DSH_HOME", "/home/dsh/.dsh")
    account_home = os.environ.get("DSH_ACCOUNT_HOME", os.path.dirname(dsh_home))
    owner = os.environ.get("DSH_SKILL_OWNER", "dsh:dsh")
    try:
        uid_text, gid_text = owner.split(":", 1)
        uid, gid = int(uid_text), int(gid_text)
    except ValueError:
        import pwd
        import grp
        user, group = owner.split(":", 1)
        uid, gid = pwd.getpwnam(user).pw_uid, grp.getgrnam(group).gr_gid

    with open(args.skill_file, "rb") as source:
        desired = source.read()
    home_fd = os.open(account_home, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        agents_fd = directory(home_fd, ".agents", uid, gid)
        try:
            skills_fd = directory(agents_fd, "skills", uid, gid)
            try:
                bundle_fd = directory(skills_fd, "las-dsh-environment", uid, gid)
                try:
                    current_fd = existing_skill(bundle_fd)
                    if current_fd is not None:
                        try:
                            current = os.read(current_fd, os.fstat(current_fd).st_size)
                            os.fchmod(current_fd, 0o600)
                            os.fchown(current_fd, uid, gid)
                        finally:
                            os.close(current_fd)
                        if current == desired:
                            return
                    temporary = ".SKILL.md.tmp." + secrets.token_hex(16)
                    tmp_fd = None
                    try:
                        tmp_fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=bundle_fd)
                        write_all(tmp_fd, desired)
                        test_failure("fsync")
                        os.fsync(tmp_fd)
                        test_failure("fchmod")
                        os.fchmod(tmp_fd, 0o600)
                        test_failure("fchown")
                        os.fchown(tmp_fd, uid, gid)
                        os.close(tmp_fd)
                        tmp_fd = None
                        test_failure("replace")
                        os.replace(temporary, "SKILL.md", src_dir_fd=bundle_fd, dst_dir_fd=bundle_fd)
                        temporary = None
                    finally:
                        try:
                            if tmp_fd is not None:
                                os.close(tmp_fd)
                        finally:
                            if temporary is not None:
                                try:
                                    os.unlink(temporary, dir_fd=bundle_fd)
                                except FileNotFoundError:
                                    pass
                finally:
                    os.close(bundle_fd)
            finally:
                os.close(skills_fd)
        finally:
            os.close(agents_fd)
    finally:
        os.close(home_fd)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f"las-dsh-environment skill installation failed: {error}", file=sys.stderr)
        sys.exit(1)
