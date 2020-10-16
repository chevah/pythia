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

* Windows Server 2012 R2 and newer
* Red Hat Linux Enterprise 7 and 8 (including derivatives such as CentOS)
* Amazon Linux 2
* Ubuntu Server 18.04 and 20.04
* any other Linux distribution with glibc 2.5 or newer
* Alpine Linux 3.12
* macOS 10.13 and newer
* FreeBSD 11
* OpenBSD 6.7
* Solaris 11.4 x86.

Note that https://github.com/chevah/python-package/ supported more platforms.


Patching upstream code
----------------------

This repository contains some patches for upstream code, e.g. Python and bzip2.

These patches are applied at build time when added as:

* ``src/$PROJECT/*.patch``

An example for creating a patch for src/python/Python/Lib/site.py::

    cd build/Python-2.7.18/
    cp Lib/site.py Lib/site.py.orig
    # Modify Lib/site.py as needed, then create the diff:
    diff -ur Lib/site.py.orig Lib/site.py
    # Save the diff into a file such as:
    src/Python/site_fix.patch

Finnaly, edit the corresponding ``chevahbs`` script in ``/src`` to apply
the new patch on platforms that require it before building from sources.

.. image:: https://github.com/chevah/pythia/workflows/GitHub-CI/badge.svg
  :target: https://github.com/chevah/pythia/actions

.. image:: https://travis-ci.com/chevah/pythia.svg?branch=main
  :target: https://travis-ci.com/github/chevah/pythia
