# Changelog

## 13.0.21-3

* **First-class Traefik support** for the Ingress layer.
  `ingress.ingressClassName` is now a required, validated field; allowed
  values:
  - `nginx` — served by ingress-nginx (legacy path). nginx-style
    annotations interpreted natively.
  - `nginx-traefik` — served by Traefik's `kubernetesIngressNGINX`
    bridge provider. Same `kind:Ingress` manifest, the bridge translates
    most nginx-style annotations (proxy-body-size,
    whitelist-source-range, auth-url, …) into Traefik's internal
    middleware chain. Useful as a transition class.
  - `traefik` — served by Traefik's native `kubernetesIngress` provider.
    nginx-style annotations on the primary Ingress are silently ignored
    AND stripped by the chart's `seafile.ingress.primaryAnnotations`
    helper so the live Ingress isn't cluttered with dead annotations.

* **WebSocket sub-Ingress: shared base annotations + per-class
  timeout auto-injection.** The WS Ingress (notification + seadoc
  internal paths) now inherits `ingress.annotations` automatically —
  no more remembering to duplicate intent annotations like
  `ioanalytica.com/exposure` into a separate block.
  `cert-manager.io/*` keys are stripped from the WS Ingress so only
  the primary Ingress drives ingress-shim cert issuance for the shared
  TLS secret.

  A single new knob `ingress.websocket.idleTimeout` (default `300s`)
  controls how long an idle WS backend connection lives. The chart
  enforces it per class:
  - `nginx` / `nginx-traefik`: auto-injects
    `nginx.ingress.kubernetes.io/proxy-read-timeout` and
    `proxy-send-timeout` on the WS Ingress.
  - `nginx-traefik` / `traefik`: emits a Traefik `ServersTransport`
    CRD with `responseHeaderTimeout` + `idleConnTimeout` = the same
    value, and auto-annotates the WS Ingress with
    `traefik.ingress.kubernetes.io/router.serverstransport` pointing at
    the CRD.

  Default lowered from 3600s (legacy paranoia) to 300s: any
  well-behaved WebSocket client ping/pongs every 30-60s, which keeps
  the TCP connection visibly "warm" at the L7 proxy. 5 minutes is
  plenty; bump it via `ingress.websocket.idleTimeout` if a client
  needs sparser keep-alives.

* `ingress.websocketAnnotations` is still accepted as an optional
  extra-on-top of `ingress.annotations` for WS-only overrides — but
  defaults empty. Users who previously had to put
  `ioanalytica.com/exposure` etc. there can remove it.

## 13.0.21-2

* (prior releases — no CHANGELOG entries kept; see git log)
