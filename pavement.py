# Copyright (c) 2010-2013 Adi Roiban.
# See LICENSE for details.
"""
Build script for Python binary distribution.
"""
import os

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
