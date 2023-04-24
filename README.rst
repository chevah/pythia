Pythia - a portable Python package
==================================

Build system for a portable Python package.
A derivative of https://github.com/chevah/python-package/.

Building:

* ``./build.sh build``

Testing:

* ``./build.sh test``
* ``./build.sh compat``

Use ``./build.sh help`` to discover all available commands.

Note that compat tests are currently only working on the ``python2.7`` branch.


Supported platforms
-------------------

* Windows Server 2012 R2 and newer
* macOS 10.13 and newer (both Intel and Apple Silicon)
* Red Hat Enterprise Linux 8 and newer (including clones)
* Ubuntu 18.04 LTS and newer
* Amazon Linux 2 and newer
* Alpine Linux 3.12 and newer.

Platforms that should work, but are not regularly tested:

* all glibc-based Linux distributions (glibc 2.26+)
* all musl-based Linux distributions (musl 1.1.24+)
* FreeBSD 12 and newer
* OpenBSD 6.7 and newer
* Solaris 11.4 (x86 only).

Where not noted, supported architecture is x64 (also known as X86-64 or AMD64).

Note that https://github.com/chevah/python-package/ supported more platforms,
but only for Python 2.7.


Patching upstream code
----------------------

This repository contains some patches for upstream code, e.g. Python and bzip2.

These patches are applied at build time when added as:

* ``src/$PROJECT/*.patch``

An example for creating a patch for pristine Python 3.9.0 sources::

    # Make a copy of the sources to be patched:
    cp -r Python-3.9.0 Python-3.9.0.disabled_modules
    # Modify the sources as needed, then create the diff:
    diff -ur Python-3.9.0/ Python-3.9.0.disabled_modules/
    # Save the diff into a file such as:
    src/Python/disabled_modules.patch

Finally, edit the corresponding ``chevahbs`` script in ``/src`` to apply
the new patch on platforms that require it before building from sources.
When applying a patch on top of another patch, make sure you get the order
right, then save the diff to the sources patched with the preceding patch.

.. image:: https://img.shields.io/badge/License-MIT-yellow.svg
  :target: https://opensource.org/licenses/MIT

.. image:: https://github.com/chevah/pythia/workflows/GitHub-CI/badge.svg
  :target: https://github.com/chevah/pythia/actions

.. image:: https://img.shields.io/github/issues/chevah/pythia.svg
  :target: https://github.com/chevah/pythia/issues
