# Third-party notices

The original Asspp source remains under the MIT license in LICENSE.

This fork links Unicorn's GPL-2.0 interpreter to perform SAP authentication without
JIT. Distribution of the combined app must comply with GPL-2.0, including supplying
the corresponding source and build scripts. Unicorn includes LGPL components;
license texts and author notices are in Resources/Licenses and are copied into the
app's SAPAssets resource directory. The exact Unicorn source revision, checksum,
download URL and build options are recorded in Resources/Scripts/prepare.sap.py.

The C++ SAP host and Mach-O loader are adapted from Sorvigolova/ipatool under MIT.
Their copyright and permission notice is in Resources/Licenses/ipatool.txt.

Apple SAP framework data is fetched directly from Apple's software-update server
and verified against the hashes used by official ipatool. Apple retains ownership
of that software. It is not part of this repository's MIT-licensed source.

See Resources/Document/SAP_AUTHENTICATION.md for source revisions and build details.
