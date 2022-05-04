# Copyright (c) 2011 Adi Roiban.
# See LICENSE for details.
import os
import sys
import platform
import subprocess

script_helper = './get_binaries_deps.sh'
platform_system = platform.system().lower()

try:
    CHEVAH_OS = os.environ.get('OS')
    CHEVAH_ARCH = os.environ.get('ARCH')
except:
    print('Could not get $OS/$ARCH Chevah env vars.')
    sys.exit(120)

BUILD_LIBEDIT = os.environ.get('BUILD_LIBEDIT', 'no').lower() == 'yes'


def get_allowed_deps():
    """
    Return a hardcoded list of allowed deps for the current OS.
    """
    allowed_deps = []
    if platform_system == 'linux':
        if 'lnx' in CHEVAH_OS:
            # Deps without paths for generic Linux builds.
            # Only glibc 2.x libs are allowed.
            # Tested on SLES 11 with glibc 2.11.3 and CentOS 5 with glibc 2.5.
            allowed_deps=[
                'libc.so.6',
                'libcrypt.so.1',
                'libdl.so.2',
                'libm.so.6',
                'libpthread.so.0',
                'librt.so.1',
                'libutil.so.1',
                ]
            if 'arm64' in CHEVAH_ARCH:
                # Additional deps without paths for arm64 generic Linux builds.
                # From Ubuntu 16.04 w/ glibc 2.23 (on Pine A64+ and X-Gene 3).
                allowed_deps.extend([
                    'libgcc_s.so.1',
                    ])
        elif 'rhel' in CHEVAH_OS:
            # Common deps for supported RHEL with full paths (x86_64 only).
            allowed_deps = [
                '/lib64/libcom_err.so.2',
                '/lib64/libcrypt.so.1',
                '/lib64/libc.so.6',
                '/lib64/libdl.so.2',
                '/lib64/libfreebl3.so',
                '/lib64/libgssapi_krb5.so.2',
                '/lib64/libk5crypto.so.3',
                '/lib64/libkeyutils.so.1',
                '/lib64/libkrb5.so.3',
                '/lib64/libkrb5support.so.0',
                '/lib64/liblzma.so.5',
                '/lib64/libm.so.6',
                '/lib64/libnsl.so.1',
                '/lib64/libpthread.so.0',
                '/lib64/libresolv.so.2',
                '/lib64/librt.so.1',
                '/lib64/libselinux.so.1',
                '/lib64/libutil.so.1',
                '/lib64/libz.so.1',
                ]
            rhel_version = CHEVAH_OS[4:]
            if rhel_version.startswith("8"):
                allowed_deps.extend([
                    '/lib64/libcrypto.so.1.1',
                    '/lib64/libffi.so.6',
                    '/lib64/libncursesw.so.6',
                    '/lib64/libssl.so.1.1',
                    '/lib64/libtinfo.so.6',
                    ])
        elif 'ubuntu' in CHEVAH_OS:
            ubuntu_version = CHEVAH_OS[6:]
            # Common deps for supported Ubuntu LTS with full paths (x86_64).
            allowed_deps=[
                '/lib/x86_64-linux-gnu/libc.so.6',
                '/lib/x86_64-linux-gnu/libcrypt.so.1',
                '/lib/x86_64-linux-gnu/libdl.so.2',
                '/lib/x86_64-linux-gnu/liblzma.so.5',
                '/lib/x86_64-linux-gnu/libm.so.6',
                '/lib/x86_64-linux-gnu/libpthread.so.0',
                '/lib/x86_64-linux-gnu/librt.so.1',
                '/lib/x86_64-linux-gnu/libutil.so.1',
                '/lib/x86_64-linux-gnu/libz.so.1',
                ]
            if ubuntu_version == "1804":
                allowed_deps.extend([
                    '/lib/x86_64-linux-gnu/libtinfo.so.5',
                    '/usr/lib/x86_64-linux-gnu/libcrypto.so.1.1',
                    '/usr/lib/x86_64-linux-gnu/libffi.so.6',
                    '/usr/lib/x86_64-linux-gnu/libssl.so.1.1',
                ])
            else:
                # Tested on 20.04, might cover future releases as well.
                allowed_deps.extend([
                    '/lib/x86_64-linux-gnu/libcrypto.so.1.1',
                    '/lib/x86_64-linux-gnu/libffi.so.7',
                    '/lib/x86_64-linux-gnu/libssl.so.1.1',
                    '/lib/x86_64-linux-gnu/libtinfo.so.6',
                ])
        elif 'alpine' in CHEVAH_OS:
            # Full deps with paths, but no minor versions, for Alpine 3.12+.
            allowed_deps=[
                '/lib/ld-musl-x86_64.so.1',
                '/lib/libc.musl-x86_64.so.1',
                '/lib/libcrypto.so.1.1',
                '/lib/libssl.so.1.1',
                '/lib/libz.so.1',
                ]
    elif platform_system == 'sunos':
        # This is the list of deps for Solaris 11 64bit builds.
        allowed_deps = [
            '/lib/64/libc.so.1',
            '/lib/64/libcrypto.so.1.0.0',
            '/lib/64/libdl.so.1',
            '/lib/64/libelf.so.1',
            '/lib/64/libm.so.2',
            '/lib/64/libnsl.so.1',
            '/lib/64/libsocket.so.1',
            '/lib/64/libssl.so.1.0.0',
            '/lib/64/libz.so.1',
            '/usr/lib/64/libbz2.so.1',
            '/usr/lib/64/libcrypt.so.1',
            '/usr/lib/64/libkstat.so.1',
            '/usr/lib/64/libncursesw.so.5',
            '/usr/lib/64/libpthread.so.1',
            '/usr/lib/64/libsqlite3.so.0',
            '/usr/lib/amd64/libc.so.1',
            ]
    elif platform_system == 'darwin':
        # Deps for macOS 10.13, with full path.
        allowed_deps = [
            '/System/Library/Frameworks/ApplicationServices.framework/Versions/A/ApplicationServices',
            '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon',
            '/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation',
            '/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics',
            '/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices',
            '/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit',
            '/System/Library/Frameworks/Security.framework/Versions/A/Security',
            '/System/Library/Frameworks/SystemConfiguration.framework/Versions/A/SystemConfiguration',
            '/usr/lib/libbz2.1.0.dylib',
            '/usr/lib/libffi.dylib',
            '/usr/lib/libncurses.5.4.dylib',
            '/usr/lib/libSystem.B.dylib',
            '/usr/lib/libz.1.dylib',
            ]
    elif platform_system == 'freebsd':
        # Deps for FreeBSD 12, with full path.
        allowed_deps = [
            '/lib/libc.so.7',
            '/lib/libcrypt.so.5',
            '/lib/libcrypto.so.111',
            '/lib/libdevstat.so.7',
            '/lib/libelf.so.2',
            '/lib/libkvm.so.7',
            '/lib/libm.so.5',
            '/lib/libncurses.so.8',
            '/lib/libncursesw.so.8',
            '/lib/libthr.so.3',
            '/lib/libutil.so.9',
            '/lib/libz.so.6',
            '/usr/lib/libbz2.so.4',
            '/usr/lib/libdl.so.1',
            '/usr/lib/libssl.so.111',
         ]
    elif platform_system == 'openbsd':
        # Deps for OpenBSD 6.7+, sans versions, these guys love to break ABIs.
        allowed_deps = [
            '/usr/lib/libc.so',
            '/usr/lib/libcrypto.so',
            '/usr/lib/libcurses.so',
            '/usr/lib/libkvm.so',
            '/usr/lib/libm.so',
            '/usr/lib/libpthread.so',
            '/usr/lib/libssl.so',
            '/usr/lib/libutil.so',
            '/usr/lib/libz.so',
            '/usr/libexec/ld.so',
            ]
    return allowed_deps


def get_actual_deps(script_helper):
    """
    Return a list of unique dependencies for the newly-built binaries.
    script_helper is a shell script that uses ldd (or equivalents) to examine
    dependencies for all binaries in the current sub-directory.
    """
    # OpenBSD's ldd output is special, both the name of the examined files and
    # the needed libs are in the 7th colon, which also includes a colon header.
    openbsd_ignored_strings = ( 'Name', os.getcwd(), './', )
    # On Linux with glibc, ignore ld-linux*, virtual deps, and other special
    # libs and messages, to only get deps of regular libs with full paths.
    linux_ignored_strings = (
                            'linux-gate.so',
                            'linux-vdso.so',
                            'ld-linux.so',
                            'ld-linux-x86-64.so',
                            'ld-linux-aarch64.so',
                            'ld-linux-armhf.so',
                            'arm-linux-gnueabihf/libcofi_rpi.so',
                            'arm-linux-gnueabihf/libarmmem.so',
                            'statically linked',
                            )

    try:
        raw_deps = subprocess.check_output(script_helper).decode().splitlines()
    except:
        sys.stderr.write('Could not get the deps for the new binaries.\n')
        sys.exit(121)
    else:
        libs_deps = []
        for line in raw_deps:
            if line.startswith('./') or not line:
                # On some OS'es (e.g. macOS), the output includes
                # the examined binaries, and those lines start with "./".
                # It's safe to ignore them because they point to paths in
                # the current hierarchy of directories.
                continue
            if platform_system == 'darwin':
                # When ignoring lines from the above conditions, ldd's output
                # lists the libs with full path in the 1st colon on these OS'es.
                dep = line.split()[0]
            elif platform_system == 'openbsd':
                dep = line.split()[6]
                if dep.startswith(openbsd_ignored_strings):
                    continue
            elif platform_system == 'linux':
                # On Alpine, lddtree is used, the output is different.
                if 'alpine' in CHEVAH_OS:
                    dep = line.split()[0]
                else:
                    if any(string in line for string in linux_ignored_strings):
                        continue
                    dep = line.split()[2]
            else:
                # For other OS'es, the third field in each line is needed.
                dep = line.split()[2]
            libs_deps.append(dep)
    return list(set(libs_deps))


def get_unwanted_deps(allowed_deps, actual_deps):
    """
    Return unwanted deps for the newly-built binaries.
    allowed_deps is a list of strings representing the allowed dependencies
    for binaries built for the current OS, hardcoded in get_allowed_deps().
    May include the major versioning, eg. "libssl.so" or "libssl.so.1".
    actual_deps is a list of strings representing the actual dependencies
    for the newly-built binaries as gathered through get_actual_deps().
    May include the path, eg. "libssl.so.1" or "/usr/lib/libssl.so.1".
    """
    unwanted_deps = []
    for single_actual_dep in actual_deps:
        for single_allowed_dep in allowed_deps:
            if single_allowed_dep in single_actual_dep:
                break
        else:
            unwanted_deps.append(single_actual_dep)
    return unwanted_deps


def test_dependencies():
    """
    Compare the list of allowed deps for the current OS with the list of
    actual deps for the newly-built binaries returned by the script helper.

    Return 0 on success, non zero on error.
    """
    if os.name == 'nt':
        # Not supported on Windows.
        return 0

    allowed_deps = get_allowed_deps()
    if not allowed_deps:
        sys.stderr.write('Got no allowed deps. Please check if {0} is a '
            'supported operating system.\n'.format(platform.system()))
        return 122

    actual_deps = get_actual_deps(script_helper)
    if not actual_deps:
        sys.stderr.write('Got no deps for the new binaries. Please check '
            'the "{0}" script in the "build/" dir.\n'.format(script_helper))
        return 123

    unwanted_deps = get_unwanted_deps(allowed_deps, actual_deps)
    sys.stdout.write('Complete list of dependencies:\n')
    for single_dep_to_print in sorted(actual_deps):
        sys.stdout.write('\t{0}\n'.format(single_dep_to_print))
    if unwanted_deps:
        sys.stderr.write('Got unwanted dependencies:\n')
        for single_dep_to_print in sorted(unwanted_deps):
            sys.stderr.write('\t{0}\n'.format(single_dep_to_print))
        return 124

    return 0


def egg_check(module):
    """
    Check that the tested module is in the current path.
    If not, it may be pulled from ~/.python-eggs and that's not good.

    Return 0 on success, non zero on error.
    """
    if not os.getcwd() in module.__file__:
        sys.stderr.write(
            "{0} module not in current path, ".format(module.__name__) +
                "is zip_safe set to True for it?\n"
            "\tcurrent path: {0}".format(os.getcwd()) + "\n"
            "\tmodule file: {0}".format(module.__file__) + "\n"
            )
        return 125

    return 0


def main():
    """
    Launch tests to check required modules and OS-specific dependencies.
    Exit with a relevant error code.
    """
    exit_code = 0
    import sys
    print('python %s' % (sys.version,))

    try:
        import zlib
    except:
        sys.stderr.write('"zlib" is missing.\n')
        exit_code = 131
    else:
        print('zlib %s' % (zlib.__version__,))

    try:
        from ssl import OPENSSL_VERSION
        import _hashlib
        exit_code = egg_check(_hashlib) | exit_code
    except:
        sys.stderr.write('standard "ssl" is missing.\n')
        exit_code = 132
    else:
        print('stdlib ssl - %s' % (OPENSSL_VERSION,))

    try:
        from cryptography.hazmat.backends.openssl.backend import backend
        import cryptography
        openssl_version = backend.openssl_version_text()
        if CHEVAH_OS in [ "win", "macos", "lnx", "rhel-8" ]:
            if CHEVAH_OS == "rhel-8":
                # On RHEL 8.3, OpenSSL got updated to 1.1.1g. To keep backward
                # compatibility, link to version 1.1.1c from CentOS 8.2.2004.
                expecting = u'OpenSSL 1.1.1c FIPS  28 May 2019'
            elif CHEVAH_OS == "win":
                # Latest cryptography not requiring Rust has older wheels.
                expecting = u'OpenSSL 1.1.1l  24 Aug 2021'
            else:
                # Use latest OpenSSL version when building it from source.
                expecting = u'OpenSSL 1.1.1n  15 Mar 2022'
            if openssl_version != expecting:
                sys.stderr.write('Expecting %s, got %s.\n' % (
                    expecting, openssl_version))
                exit_code = 133
    except Exception as error:
        sys.stderr.write('"cryptography" failure. %s\n' % (error,))
        exit_code = 134
    else:
        print('cryptography %s - %s' % (
            cryptography.__version__, openssl_version))

    try:
        from ctypes import CDLL
        import ctypes
        CDLL
    except:
        sys.stderr.write('"ctypes - CDLL" is missing. %s\n')
        exit_code = 138
    else:
        print('ctypes %s' % (ctypes.__version__,))

    try:
        from ctypes.util import find_library
        find_library
    except:
        sys.stderr.write('"ctypes.utils - find_library" is missing.\n')
        exit_code = 139

    try:
        import multiprocessing
        multiprocessing.current_process()
    except:
        sys.stderr.write('"multiprocessing" is missing or broken.\n')
        exit_code = 140

    try:
        import subprocess32 as subprocess
        dir_output = subprocess.check_output('ls')
    except:
        sys.stderr.write('"subprocess32" is missing or broken.\n')
        exit_code = 145
    else:
        print('"subprocess32" module is present.')

    try:
        import bcrypt
        password = b"super secret password"
        # Hash the password with a randomly-generated salt.
        hashed = bcrypt.hashpw(password, bcrypt.gensalt())
        # Check that an unhashed password matches hashed one.
        if bcrypt.checkpw(password, hashed):
            print('bcrypt %s' % (bcrypt.__version__,))
        else:
            sys.stderr.write('"bcrypt" is present, but broken.\n')
            exit_code = 146
    except:
        sys.stderr.write('"bcrypt" is missing.\n')
        exit_code = 147

    try:
        import bz2
        test_string = b"just a random string to quickly test bz2"
        test_string_bzipped = bz2.compress(test_string)
        if bz2.decompress(test_string_bzipped) == test_string:
            print('"bz2" module is present.')
        else:
            sys.stderr.write('"bzip" is present, but broken.\n')
            exit_code = 148
    except:
        sys.stderr.write('"bz2" is missing.\n')
        exit_code = 149

    try:
        import lzma
        test_string = b"just a random string to quickly test lzma"
        test_string_xzed = lzma.compress(test_string)
        if lzma.decompress(test_string_xzed) == test_string:
            print('"lzma" module is present.')
        else:
            sys.stderr.write('"lzma" is present, but broken.\n')
            exit_code = 152
    except:
        sys.stderr.write('"lzma" is missing.\n')
        exit_code = 151

    try:
        import setproctitle
        current_process_title = setproctitle.getproctitle()
    except:
        sys.stderr.write('"setproctitle" is missing or broken.\n')
        exit_code = 150
    else:
        print('setproctitle %s' % (setproctitle.__version__,))

    try:
        from sqlite3 import dbapi2 as sqlite
    except:
        sys.stderr.write('"sqlite3" is missing or broken.\n')
        exit_code = 153
    else:
        print('sqlite3 %s - sqlite %s' % (
                sqlite.version, sqlite.sqlite_version))

    try:
        import psutil
        cpu_percent = psutil.cpu_percent()
    except:
        sys.stderr.write('"psutil" is missing or broken.\n')
        exit_code = 160
    else:
        print('psutil %s' % (psutil.__version__,))

    try:
        import uuid
        uuid.uuid4()
    except:
        sys.stderr.write('"uuid" is missing or broken.\n')
        exit_code = 163
    else:
        print('"uuid" module is present.')

    if os.name == 'nt':
        # Windows specific modules.
        try:
            from ctypes import windll
            windll
        except:
            sys.stderr.write('"ctypes - windll" is missing.\n')
            exit_code = 152
        else:
            print('ctypes %s' % (ctypes.__version__,))

    else:
        # Linux / Unix stuff.
        try:
            import crypt
            crypt
        except:
            sys.stderr.write('"crypt" is missing.\n')
            exit_code = 155

        # Check for the git revision in Python's sys.version on Linux and Unix.
        try:
            git_rev_cmd = ['git', 'log', '-1', '--no-merges', '--format=%h']
            git_rev = subprocess.check_output(git_rev_cmd).strip().decode()
        except:
            sys.stderr.write("Couldn't get the git rev for the current tree.\n")
            exit_code = 157
        else:
            bin_ver = sys.version.split('(')[1].split(',')[0]
            if bin_ver != git_rev:
                sys.stderr.write("Python version doesn't match git revision!\n"
                                 "\tBin ver: {0}".format(bin_ver) + "\n"
                                 "\tGit rev: {0}".format(git_rev) + "\n")
                exit_code = 158

    if platform_system in [ 'linux', 'sunos' ]:
        try:
            import spwd
            spwd
        except:
            sys.stderr.write('"spwd" is missing, but it should be present.\n')
            exit_code = 161
        else:
            print('"spwd" module is present.')

    # The readline module is built using libedit only on selected platforms.
    if BUILD_LIBEDIT:
        try:
            import readline
            readline.get_history_length()
        except:
            sys.stderr.write('"readline" is missing or broken.\n')
            exit_code = 162
        else:
            print('"readline" module is present.')


    exit_code = test_dependencies() | exit_code


    sys.exit(exit_code)


if __name__ == '__main__':
    main()
