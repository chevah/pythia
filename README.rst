Pythia - a Python Portable Package
==================================

Build system for a portable Python distribution. 
A derivative of https://github.com/chevah/python-package/.

Building steps:

* ``./brink.sh detect_os``
* ``./pythia build``

Testing steps:

* ``./pythia test``
* ``./pythia compat``

Use ``./pythia help`` to discover all available commands.


Supported platforms
-------------------

* Windows Server 2012 R2 and newer (x86 and x64)
* Red Hat Linux Enterprise 7 and 8 (including derivatives such as CentOS)
* Amazon Linux 2
* Ubuntu Server 18.04 and 20.04
* all glibc-based Linux distributions (glibc 2.5+ for x64, 2.23+ for arm64)
* Alpine Linux 3.12
* macOS 10.13 and newer
* FreeBSD 12
* OpenBSD 6.7 and newer
* Solaris 11.4.

Where not noted, supported architecture is x64 (also known as X86-64 or AMD64).

Note that https://github.com/chevah/python-package/ supported more platforms.


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

.. image:: https://github.com/chevah/pythia/workflows/GitHub-CI/badge.svg
  :target: https://github.com/chevah/pythia/actions

.. image:: https://travis-ci.com/chevah/pythia.svg?branch=main
  :target: https://travis-ci.com/github/chevah/pythia
