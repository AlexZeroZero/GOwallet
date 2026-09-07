# Source provenance and licensing

GOwallet 1.0.0 is a GPLv3 derivative of BitFinite Wallet v2.3.0:

- Upstream: https://github.com/bitfinitechain/bitfinite-wallet
- Base commit: `f95d233394f5e5acad98724a97c4c165ebd6fa04`
- Earlier upstream work: Stack Wallet / Cypher Stack. Original copyright notices are retained in source files.
- GOwallet pre-publication development snapshot: `391c618` plus the 1.0 release preparation changes represented in this public repository. Private operational/development history is not included.

The GOwallet Android flavor, branding, SCASH/SHIC/PEP integration, custom compatible coin/network configuration, Chinese localization, and security hardening are modifications. Upstream brand assets and package names may remain in build templates/source for compatibility; they are not a claim of affiliation. No upstream security review certifies GOwallet modifications.

See LICENSE for the application GPLv3 terms. Dependencies and vendored components retain their own licenses and copyright notices; see `pubspec.lock`, dependency repositories and `vendor/`. The app also exposes third-party license information through Flutter's license facilities. A clean source checkout plus the referenced dependencies/build tools is required to build; this repository is not a self-contained offline SDK distribution.

Optional inherited submodules (not enabled in the GOwallet Android flavor) retain their upstream revisions:

- flutter_libepiccash: `f4a55aa9e5b6066428402291ed228aa0dd921534`
- flutter_libmwc: `c8db22aed2c50aa1e95dfc532abb0a4961c543d7`
- frostdart: `395765297a52c5f867ae6256636cf51e0ad20876`

Official release signing keys are intentionally not distributed. Building with your own key produces a separate signing identity and cannot overwrite an official installation. Independent bit-for-bit reproducibility of the APK has not been established.

GOwallet 1.0.1 additionally vendors flutter_secure_storage 8.1.0 (upstream BSD
license) for Android storage failure/migration hardening, and sqlite3_flutter_libs
0.5.25 (upstream MIT license) for rebuilding the same public-domain SQLite 3.46.1
source with Android compiler hardening. Their original licenses and precise patch
notes are retained in each vendor directory. This does not imply upstream endorsement.
