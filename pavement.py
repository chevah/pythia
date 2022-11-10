# Copyright (c) 2010-2013 Adi Roiban.
# See LICENSE for details.
"""
Build script for Python binary distribution.
"""
import os

from brink.pavement_commons import (
    actions_try,
    default,
    github,
    help,
    pave,
    SETUP,
    )
from paver.easy import task

# Make pylint shut up.
actions_try
default
github
help

SETUP['product']['name'] = 'python'
SETUP['folders']['source'] = u'src'
SETUP['repository']['name'] = u'pythia'
SETUP['test']['package'] = None

SETUP['pypi']['index_url'] = os.environ['PIP_INDEX_URL']

SETUP['repository']['name'] = u'pythia'
SETUP['repository']['github'] = 'https://github.com/chevah/pythia'

RUN_PACKAGES = [
    'requests~=2.24',
    'python-dateutil==2.8.1',
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
