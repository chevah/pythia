Pythia - a Python Portable Package
==================================

Build system for a portable Python distribution. 
A derivative of https://github.com/chevah/python-package/.

Building steps::

* ``./brink.sh detect_os``
* ``./chevah_build build``

Testing steps::

* ``./chevah_build test``
* ``./chevah_build test_compat``

Use ``./chevah_build help`` to discover all available commands.


Patching upstream code
----------------------

This repository contains some patches for upstream code:
Python, OpenSSL, SQLite, gmp, libffi, etc.

For local changes to upstream projects, there are patches to be applied
at build time. Those patches are kept in:

* ``src/$PROJECT/*.patch``

New patches that respect the above scheme above will be picked up automatically
by the build system.

An example for creating a patch for src/python/Python/Lib/site.py::

    cd build/Python-2.7.18/
    cp Lib/site.py Lib/site.py.orig
    # Edit Lib/site.py as needed, then create the diff:
    diff -ur Lib/site.py.orig Lib/site.py
    # Save the diff into a file such as:
    src/Python/site_fix.patch
