# Copyright (c) 2010-2013 Adi Roiban.
# See LICENSE for details.
"""
Build script for Python binary distribution.
"""
import compileall
import os
import py_compile

from brink.pavement_commons import (
    buildbot_list,
    buildbot_try,
    default,
    github,
    harness,
    help,
    pave,
    SETUP,
    test_remote,
    test_review,
    )
from paver.easy import task

# Make pylint shut up.
buildbot_list
buildbot_try
default
github
harness
help
test_remote
test_review

SETUP['product']['name'] = 'python'
SETUP['folders']['source'] = u'src'
SETUP['repository']['name'] = u'pythia'
SETUP['test']['package'] = None

SETUP['pypi']['index_url'] = 'http://pypi.chevah.com/simple'

SETUP['repository']['name'] = u'pythia'
SETUP['repository']['github'] = 'https://github.com/chevah/pythia'
SETUP['buildbot']['builders_filter'] = u'pythia'
SETUP['buildbot']['server'] = 'buildbot.chevah.com'
SETUP['buildbot']['web_url'] = 'https://buildbot.chevah.com:10433'

RUN_PACKAGES = [
    'zope.interface==3.8.0',
    'twisted==15.5.0.chevah7',

    # Buildbot is used for try scheduler
    'buildbot==0.8.11.chevah11',

    # Required for some unicode handling.
    'unidecode',
    ]


def compile_file(fullname, ddir=None, force=0, rx=None, quiet=0):
    """
    <Byte-compile one file.

    Arguments (only fullname is required):

    fullname:  the file to byte-compile
    ddir:      if given, the directory name compiled in to the
               byte-code file.
    force:     if 1, force compilation, even if timestamps are up-to-date
    quiet:     if 1, be quiet during compilation
    """
    success = 1
    name = os.path.basename(fullname)
    if ddir is not None:
        dfile = os.path.join(ddir, name)
    else:
        dfile = None
    if rx is not None:
        mo = rx.search(fullname)
        if mo:
            return success
    if os.path.isfile(fullname):
        tail = name[-3:]
        if tail == '.py':
            if not force:
                try:
                    mtime = int(os.stat(fullname).st_mtime)
                    expect = struct.pack('<4sl', imp.get_magic(), mtime)
                    cfile = fullname + (__debug__ and 'c' or 'o')
                    with open(cfile, 'rb') as chandle:
                        actual = chandle.read(8)
                    if expect == actual:
                        return success
                except IOError:
                    pass
            if not quiet:
                if isinstance(fullname, unicode):
                    print_name = fullname.encode('utf-8')
                else:
                    print_name = fullname

                print ('Compiling', print_name, '...')
            try:
                ok = py_compile.compile(fullname, None, dfile, True)
            except py_compile.PyCompileError as err:
                if quiet:
                    if isinstance(fullname, unicode):
                        print_name = fullname.encode('utf-8')
                    else:
                        print_name = fullname
                    print('Compiling', print_name, '...')
                print(err.msg.encode('utf-8'))
                success = 0
            except IOError, e:
                print('Sorry', e)
                success = 0
            else:
                if ok == 0:
                    success = 0
    return success


# Path the upstream code.
compileall.compile_file = compile_file


@task
def deps():
    """
    Copy external dependencies.
    """
    print('Installing dependencies to %s...' % (pave.path.build))
    pave.pip(
        command='install',
        arguments=RUN_PACKAGES,
        )
