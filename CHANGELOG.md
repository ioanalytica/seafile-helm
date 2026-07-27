# Changelog

## 13.0.25-3

* Bump internal `elasticsearch` image to `8.19.19`.

## 13.0.25-2

* Bump internal `elasticsearch` image to `8.19.18`.

## 13.0.25-1

* **Upgrade to Seafile 13.0.25.** `appVersion` bumped to `13.0.25`, which
  drives the `seafileltd/seafile-mc` / `seafileltd/seafile-pro-mc` image tag.

## 13.0.24-4

* Bump internal `elasticsearch` image to `8.19.17`.

## 13.0.24-3

* Bump internal `dragonfly` image to `v1.39.0`.

## 13.0.24-2

* **Bug fix: internal Elasticsearch could not start on block-storage PVs
  (Longhorn, most CSI drivers).** The ES pod ran without a pod
  `securityContext`, so freshly provisioned ext4 volumes were mounted
  root-owned (`755`) while the official elasticsearch image runs as uid 1000 —
  startup failed with `AccessDeniedException` on
  `/usr/share/elasticsearch/data/node.lock`. This went unnoticed on NFS,
  where provisioners typically create world-writable directories and
  `fsGroup` is ignored anyway.

  Fix: the ES deployment now sets `fsGroup: 1000` at pod level (the kubelet
  chowns the data volume on mount) and `runAsUser: 1000` /
  `runAsNonRoot: true` on the elasticsearch container. The privileged
  `set-vm-max-map-count` init container is unaffected and keeps running as
  root.

## 13.0.24-1

* **Upgrade to Seafile 13.0.24.** `appVersion` bumped to `13.0.24`, which
  drives the `seafileltd/seafile-mc` / `seafileltd/seafile-pro-mc` image tag.

## 13.0.23-1

* **Upgrade to Seafile 13.0.23.** `appVersion` bumped to `13.0.23`, which
  drives the `seafileltd/seafile-mc` / `seafileltd/seafile-pro-mc` image tag.
* Bump internal `mariadb` image to `12.3.2-noble`.

## 13.0.22-2

* Bump internal `elasticsearch` image to `8.19.16`.
* Bump internal `seafile-md-server` image to `13.0.22`.

## 13.0.22-1

* **Upgrade to Seafile 13.0.22.** `appVersion` bumped to `13.0.22`, which
  drives the `seafileltd/seafile-mc` / `seafileltd/seafile-pro-mc` image tag.
* Documented the Traefik ingress-class support (added in 13.0.21-3/-4) in the
  README Ingress reference, and synced the chart version strings in `README.md`
  and `examples/helmrelease.yaml`, which had lagged behind `Chart.yaml` since
  13.0.21-3.

## 13.0.21-4

* **Bug fix: invalid Traefik annotation on the WebSocket Ingress.**
  13.0.21-3 emitted
  `traefik.ingress.kubernetes.io/router.serverstransport: <name>@kubernetescrd`
  on the WS sub-Ingress to bind the chart-rendered ServersTransport
  CRD. That annotation is only valid on Traefik's own `IngressRoute`
  CRD; on a standard Kubernetes `Ingress` (which is what this chart
  emits), Traefik's kubernetesIngress provider logs
  `field not found, node: serverstransport` and **refuses to parse
  the entire Ingress** — leaving the WS host completely unrouted.

  Fix: the annotation is no longer emitted. The ServersTransport CRD
  itself is still rendered (for future re-binding via the supported
  Service-level annotation on the notification + seadoc Services) but
  currently unbound. WebSocket streams in Traefik are pass-through
  after the HTTP upgrade, so the default backend idle timeout (~90s)
  is not enforced on the upgraded stream and clients with regular
  ping/pong (notification + seadoc both ping every 30-60s) are
  unaffected.

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
