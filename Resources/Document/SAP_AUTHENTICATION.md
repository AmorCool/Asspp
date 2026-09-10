# Signed App Store authentication

This fork replaces ApplePackage's unsigned login with the SAP-signed flow used by
ipatool 2.5. Authentication and account refresh both use the new implementation.
ApplePackage continues to provide account models, catalog, license and IPA operations.

## Runtime

The app obtains the current authentication endpoint and SAP setup configuration
from Apple's bag, completes the SAP handshake, and signs the exact serialized
login body. The same body is retained across pod redirects and transient retries.
Passwords, codes, signatures and cookies are never sent to an auxiliary server.

The x86 SAP implementation runs locally in Unicorn's TCI interpreter. It does not
allocate executable code buffers, require JIT, private Apple entitlements, or a
Mac helper. Each login has its own short-lived emulator and ephemeral cookie jar.
The app verifies all four Apple assets before loading them into the interpreter.

Foundation represents domain cookies with a leading dot; ApplePackage 1.2.7's
request matcher expects the bare domain. Login export normalizes that format,
and every store operation also normalizes previously saved account cookies.
Restoring cookies for SAP reauthentication preserves their subdomain scope.
License acquisition refreshes through the same signed authenticator.

Login requests follow only HTTPS redirects to the documented buy/pN-buy Apple
hosts and authentication path. Certificate validation remains enabled, including
Debug builds. Unstructured HTTP 204, 404 and 5xx responses get at most three
transport attempts. Credential errors, HTTP 403 and 429 do not trigger that retry.
Only Apple's explicit code challenge/rejection reveals the verification-code UI.

## Reproducible builds

Install CMake (`brew install cmake`) alongside Xcode. The existing workspace build
runs `Resources/Scripts/prepare.sap.py` before compiling the app. No Go runtime or
installed ipatool is needed.

The script fetches a pinned, SHA-256-checked Unicorn source archive, builds only the
x86 guest interpreter for the selected Apple platform/architectures, and downloads
the four SAP assets directly from Apple's software-update package. It verifies
the expected lengths and SHA-256 digests used by official ipatool. Inputs and
libraries are cached in Xcode's DerivedSources/SAP directory. The initial build
requires access to GitHub and Apple's download servers. Subsequent builds reuse
verified assets and the pinned source. Apple binaries are not committed here.

The app bundle includes approximately 38 MB of Apple SAP data, plus the interpreter.
The data files are interpreted; they are not loaded as native dynamic libraries.

GitHub Actions in this fork defaults to building this repository's main branch,
including scheduled runs. Select `source_kind=upstream` manually only when you
intend to build upstream without this patch.

## Regression checks

Run the pure protocol regression checks on macOS:

```sh
swiftc Asspp/Backend/AppStore/StoreAuthenticationProtocol.swift \
  Resources/Tests/AuthenticationProtocolChecks.swift -o /tmp/asspp-auth-checks
/tmp/asspp-auth-checks
```

These cover credential-redirect restrictions, XML/binary plist decoding, password
and code serialization, storefront parsing, cookie domain conversion and scope,
code challenges, and transient retry classification. They do not substitute for a real Apple account login test.

A successful public SAP handshake proves that the signing engine works. It does
not by itself establish that Apple will accept any particular account or network.
Empty/location-less Apple responses remain distinguishable from password and 2FA
errors; the app does not silently fall back to unsigned authentication.

## Download responses and diagnostics

`StoreDownloadService` uses `volumeStoreDownloadProduct` first. It tries the
redownload endpoint once for failure 5002, or a missing/empty songList with no
failure code, customer message, account dialog or action. Other rejections and
transport errors are surfaced without this fallback. Numeric failure codes and
`metrics.messageCode` are recognized, and Apple's customer messages are preserved
in the error UI. License-required responses still use the explicit acquisition UI.

Before an unversioned fallback, the catalog resolves the current external version
ID for the selected platform and account's storefront. This prevents redownload
from choosing another platform's build. Explicit historical version IDs are kept
on both endpoints, using their respective `externalVersionId` / `appExtVrsId` keys.
A catalog failure stops the fallback instead of sending an unpinned request.
Existing saved packages without a platform default to iOS; new search results
retain the selected iPhone, iPad or Apple TV platform.

Xcode and Settings > Logs show `Store download [request ID]` entries with app ID,
platform, storefront, requested/resolved version, endpoint, HTTP status, response
size, item count, numeric error/status codes, and the fallback reason. Cookie
presence and dialog/message presence are booleans. Headers, raw bodies, Apple
messages, emails, DSIDs, device identifiers, signatures and asset URLs are not
logged. ApplePackage verbose logging stays disabled.

```sh
swiftc Asspp/Backend/AppStore/StoreAuthenticationProtocol.swift \
  Asspp/Backend/AppStore/StoreDownloadProtocol.swift \
  Resources/Tests/DownloadProtocolChecks.swift -o /tmp/asspp-download-checks
/tmp/asspp-download-checks
```

These checks exercise primary success, a single empty/5002 fallback, pinned
history, failed catalog resolution, explicit errors and dialogs, response
redaction, endpoint-specific version keys, and credential redirect restrictions.
The same checks run before signed GitHub Actions builds. Real account downloads
remain necessary to verify Apple's current behavior for any particular app.

The empty volume response and platform selection behavior are tracked in
[ipatool issue 538](https://github.com/majd/ipatool/issues/538#issuecomment-5578405805).

## Sources and licenses

- Protocol: [majd/ipatool](https://github.com/majd/ipatool), commit
  `a9bd16c` (2.5-era implementation), MIT; see `Resources/Licenses/ipatool.txt`.
- C++ Mach-O loader and SAP host shims adapted from
  [Sorvigolova/ipatool](https://github.com/Sorvigolova/ipatool), commit
  `def04b943b9b7da11571fffcc46de79f07b94c01`, MIT. Asspp passes the same hardware ID
  to the SAP session and host shims and adds an Objective-C error/lifetime bridge.
- [Naville/unicorn, feature/tci](https://github.com/Naville/unicorn/tree/feature/tci),
  commit `53471ef9cf480fab094bf13db3e5d2f9e2c30dc5`, GPL-2.0; see
  `Resources/Licenses/Unicorn.txt`. Build scripts identify the complete source of
  the linked interpreter. Distribution of the combined binary must comply with
  its GPL terms; Asspp's original source retains its MIT notice.
- Apple framework assets remain Apple's software and are retrieved from Apple.
