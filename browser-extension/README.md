# GOwallet Chrome extension wallet (0.1.2)

This is a Manifest V3 non-custodial extension using the GOwallet visual identity.
The 0.1.2 release adds the approved compact dual-theme interface: dark mode and
light mode, dense coin rows, a unified bottom navigation, and the official logo.
It supports SCASH, SHIC, PEP and DINGO address derivation, encrypted local seed
storage, WSS Electrum feature/genesis checks, balances and receive addresses.

The browser cannot connect to raw Electrum TCP/TLS. Deploy the included
`gateway/server.mjs` behind a WSS reverse proxy and change the WSS URLs in
`src/coins.ts` if your route differs. The gateway never receives seed phrases or
private keys. SCASH/SHIC defaults use the existing GoZero TLS relay; PEP/DINGO
defaults point at public project endpoints and can be changed in source before
deployment.

This browser build does not claim the mobile app's transaction serializer or
send flow. Do not import a funded wallet until the gateway and transaction signing
test suite have been reviewed. It is safe to use a new test mnemonic while testing.

```powershell
node C:\Users\ALIENWARE\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\pnpm\bin\pnpm.cjs install
node C:\Users\ALIENWARE\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\pnpm\bin\pnpm.cjs build
```

Run the build, then load `dist/` in `chrome://extensions` with Developer mode and “Load unpacked”.
