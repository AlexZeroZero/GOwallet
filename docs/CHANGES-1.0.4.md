# GOwallet 1.0.4

- Apply the user-selected mint-jade open uppercase G with a detached circular
  ring. A shared scalable geometry updates Android launcher/adaptive/monochrome
  icons, native splash, Flutter splash and in-app branding.
- Make the coin drawer more compact: reduced header/section spacing, 24px coin
  icons, smaller added-coin card padding and a single compact supported-coin row.
  Supported-coin tap targets remain at least 48 logical pixels high. Large-text
  labels wrap rather than being clipped.
- Explain in Chinese and English that GOwallet derives from the open-source
  Stack Wallet project, thank Stack Wallet / Cypher Stack, and link its source.
  Keep GPLv3 and the full provenance chain in NOTICE, linked from About.
- Enable BFX with two project-operated TLS Electrum endpoints, official coin
  artwork, BIP44 recovery and BCH signing. Harden BFX address validation.
  See [BFX.md](BFX.md).
- Upgrade bundled themes from 44 to 45 so existing installations also receive
  the new app and BFX artwork.

The Android package remains `org.gowallet.pow`; version is `1.0.4+13`.
No wallet storage format or key derivation for existing coins is changed.
No new independent security audit or malware-scan result is claimed for this build.
