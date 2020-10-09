To remove SxS manifests from the upstream Python binaries, `manifest-wiper.exe`
is used. More at https://bitbucket.org/alibotean/sxs-manifest-wiper.

Latest Visual Studio 2008 (VC++ 9.0) redistributable is instead bundled at
build time with the upstream Python binaries, so that there is no need to
install it separately on the systems running this Python distribution.

As Visual Studio 2008 reached end of support on April 10, 2018, online links
for downloading VC++ 9.0 redistributables may be removed in the future by
Microsoft, according to https://support.microsoft.com/en-us/kb/2977003.

More so, updated DLL files are installed with latest Windows Server versions.
As of September 2020:
    - 9.0.30729.8387 on Windows 2012
    - 9.0.30729.9247 on Windows 2016
    - 9.0.30729.9518 on Windows 2019.

Therefore, to update the version for this repo, search under MINGW/MSYS for
the Microsoft Visual C++ 2008 Redistributable DLLs on a Windows installation
running the latest Windows Server version:

    find /c/Windows/WinSxS -name 'msvc?90.dll'

Note the most recent version (currently `9.0.30729.9518`) and inspect its files:

    find /c/Windows/WinSxS -name 'msvc?90.dll' | grep 9.0.30729.9518

To automatically collect them, use the included `./get_latest_redist.sh` under
MINGW/MSYS, adjusting `REDISTRIBUTABLE_VERSION` (if needed) to be the most
recent redistributable version, as noted above.

End result should be:

    $ find 9.0.30729.9518/
    9.0.30729.9518/
    9.0.30729.9518/amd64
    9.0.30729.9518/amd64/msvcm90.dll
    9.0.30729.9518/amd64/msvcp90.dll
    9.0.30729.9518/amd64/msvcr90.dll
    9.0.30729.9518/x86
    9.0.30729.9518/x86/msvcm90.dll
    9.0.30729.9518/x86/msvcp90.dll
    9.0.30729.9518/x86/msvcr90.dll

Then, create (for both `x86` and `amd64` DLL sets) the assembly files named
`Microsoft.VC90.CRT.manifest` with the following content:

<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
    <noInheritable></noInheritable>
    <assemblyIdentity type="win32" name="Microsoft.VC90.CRT" version="$REDISTRIBUTABLE_VERSION" processorArchitecture="$ARCH" publicKeyToken="1fc8b3b9a1e18e3b"></assemblyIdentity>
    <file name="msvcr90.dll"></file>
    <file name="msvcp90.dll"></file>
    <file name="msvcm90.dll"></file>
</assembly>

Replace $REDISTRIBUTABLE_VERSION and $ARCH accordingly above, for example with
`9.0.30729.6161` and `x86` for the DLLs in the `x86/` sub-directory or
`9.0.30729.9518` and `amd64` for the DLLs in the `amd64/` sub-directory.

Also check if `publicKeyToken` has changed, by comparing it with the value in
the manifests on the system where the DLLs were collected, in files of the form
/c/Windows/WinSxS/Manifests/"$ARCH"_microsoft.vc90.crt_*"$REDISTRIBUTABLE_VERSION"*.manifest

The manifests in this repository are used to tie the upstream Python binary
files to the VC++ 9.0 DLLs we distribute alongside them.

When updating the redistributable version/revision, also update the value of
the REDISTRIBUTABLE_VERSION variable in `pythia.conf` accordingly.
