# GOwallet 1.0

[Browse 8 Chinese/English screenshots](SCREENSHOTS.md) captured from the released Android APK using unfunded test wallets.

**Noncustodial wallet and node-service notice:** Nodes are independently deployed and operated by the relevant coin projects or third-party operators. Inclusion in GOwallet does not establish official project endorsement. Outages, attacks, synchronization delays, incorrect responses and service termination originating at the node are node-service issues, separate from the GOwallet client itself. GOwallet does not guarantee node uptime, response accuracy or timely broadcast. You can switch compatible nodes to check on-chain status; a node outage alone does not change ownership of on-chain funds. Defects in the app itself should still be reported to this project.

An open-source, noncustodial Android wallet for small PoW coins. Supports SCASH, SHIC and Pepecoin (PEP), compatible custom coin profiles, and configurable Electrum TCP/TLS servers. Includes Chinese/English UI, local signing, encrypted backups, PIN protection and configurable screenshot protection.

[Download v1.0.0](https://github.com/AlexZeroZero/GOwallet/releases/tag/v1.0.0) · [Build](BUILD.md) · [Verification](VERIFICATION.md) · [Security review](SECURITY-REVIEW.md) · [Electrum](ELECTRUM.md)

Seeds, private keys and transaction signing stay on your device in the normal wallet protocol. Neither developers nor Electrum operators can recover a lost seed. Keep an offline backup and never disclose it in support requests. Noncustodial does not mean anonymous or safe on a compromised operating system.

Core wallet operations need compatible Electrum services and their full nodes, not a proprietary application account backend. Optional fiat pricing may use separate APIs. TLS protects transport but cannot make a malicious server honest; plain TCP is unencrypted. This is **not a full SPV implementation**: block-header PoW, Merkle inclusion and chain selection are not fully verified. Raw previous transactions are authenticated before signing, but server availability, completeness and confirmation claims still require trust.

Android package: `org.gowallet.pow`, version `1.0.0+9`, minimum API 24, ARM64/x86_64. The existing GOwallet signing identity is retained for in-place upgrades. Back up first; do not uninstall to upgrade. No iOS or desktop binary is released here.

The release publishes actual malware-scan evidence, SHA-256 checksums, signature details, regression results and limits. These are not a guarantee of no malware/vulnerabilities and not an independent third-party security certification. The hosted Pub advisory scan does not cover Git/path dependencies, native libraries or SDKs.

Licensed under GPLv3; based on BitFinite Wallet v2.3.0 and earlier Stack Wallet / Cypher Stack work. See [NOTICE](../NOTICE.md) and [LICENSE](../LICENSE). GOwallet is an independent derivative.
