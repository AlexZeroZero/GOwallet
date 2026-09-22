# GOwallet Electrum WebSocket gateway

Chrome extensions cannot open Electrum TCP/TLS sockets. This small gateway accepts
WebSocket JSON-RPC and opens a certificate-validated TLS connection to ElectrumX.
It forwards JSON lines only; seed phrases, private keys and passwords never enter
the gateway. Run it behind an HTTPS/WSS reverse proxy on the same hostname used by
the extension (`/electrum/scash` and `/electrum/shic`).

The supplied production edge currently exposes Electrum TLS on ports 50002/50012,
but does not yet expose this WebSocket route. A deployment must add this service
over WireGuard and route WSS to it before the browser wallet can query balances.

```sh
PORT=8790 ALLOWED_ORIGINS=chrome-extension://<extension-id> node server.mjs
```

The process binds to loopback. Put a TLS reverse proxy in front, rate-limit by
source, cap message size, and keep origin allow-listing enabled. Do not expose the
loopback gateway directly to the Internet.
