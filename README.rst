Pythia - a portable Python package
==================================

.. image:: https://img.shields.io/badge/License-MIT-yellow.svg
  :target: https://opensource.org/licenses/MIT

.. image:: https://github.com/chevah/pythia/workflows/ci/badge.svg
  :target: https://github.com/chevah/pythia/actions

.. image:: https://img.shields.io/github/issues/chevah/pythia.svg
  :target: https://github.com/chevah/pythia/issues


Build system for a portable Python package.

It is based on `astral-sh/python-build-standalone <https://github.com/astral-sh/python-build-standalone>`_

It builds on top of `python-build-standalone` by allowing you to create a local Python virtual environment without the need to use `uv`

The `pythia.sh` script can automatically download and create the Python venv.

It is designed to be used for self-contained applications that are distributed together with Python.

It is also designed for applications that are packaged only Linux GLIBC,
with Linux MUSL, macOS and Windows installation packages also generated on Linux.

It comes with a few pre-installed packages, depending on the OS.
This is done to simplify building the final distributable package on Linux,
regardless of the target OS.
Example on Windows, pywin32 is preinstalled.


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
* all musl-based Linux distributions (musl 1.1.24+).

Where not noted, supported architecture is x64 (also known as X86-64 or AMD64).


Usage
-----

Copy `pythia.sh` script into your repo.
Copy `pythia.conf` file into your repo and configure your mirrors and targeted Python version.

It is designed to create the Python virtual environment and automatically call paver inside the newly created environment.
`pythia.conf` contains a set of Python packages that needs to be installed to bootstrap the `paver` usage.

TK is removed to save space and since this is designed for server-side apps.


Development
-----------

It is designed to download the Python .tar.gz from `python-build-standalone` GitHub release page, convert it into a format usable by `pythia.sh`
and upload the resulting tar.gz into a download/mirror server.

Update the values from `build.conf`.
You can see the available `python-build-standalone` releases at
https://github.com/astral-sh/python-build-standalone/releases

It has support for uploading into testing vs production.

Building:

* `./astral-to-pythia.sh TARGET_ARCH`

TARGET_ARCH needs to match the local arch.

Testing:

* `./test_pythia.sh TARGET_ARCH`
* `./test_compat.sh`
