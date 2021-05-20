Pythia - a portable Python package
==================================

Build system for a portable Python package.
A derivative of https://github.com/chevah/python-package/.

Building:

* ``./pythia build``

Testing:

* ``./pythia test``
* ``./pythia compat``

Use ``./pythia help`` to discover all available commands.

Note that compat tests are currently only working with the ``python2.7`` branch.


Supported platforms
-------------------

* Windows Server 2012 R2 and newer (x86 and x64)
* macOS 10.13 and newer.
* all glibc-based Linux distributions (glibc 2.5+)

Platforms on which the system OpenSSL is used:

* Red Hat Linux Enterprise 8 and newer (including derivatives such as CentOS)
* Amazon Linux 2
* Ubuntu Server 18.04 and 20.04
* Alpine Linux 3.12

Platforms that should work, but are not regularly tested:

* FreeBSD 12
* OpenBSD 6.7 and newer
* Solaris 11.4.

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
