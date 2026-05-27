{{/*
Expand the name of the chart.
*/}}
{{- define "seafile.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "seafile.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "seafile.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "seafile.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "seafile.selectorLabels" -}}
app.kubernetes.io/name: {{ include "seafile.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Container image
Docker Hub names: seafileltd/seafile-mc (CE), seafileltd/seafile-pro-mc (Pro)
*/}}
{{- define "seafile.image" -}}
{{- $tag := .Values.seafile.image.tag | default .Chart.AppVersion -}}
{{- if .Values.seafile.image.repository -}}
  {{- printf "%s:%s" .Values.seafile.image.repository $tag }}
{{- else if eq .Values.seafile.edition "pro" -}}
  {{- printf "seafileltd/seafile-pro-mc:%s" $tag }}
{{- else -}}
  {{- printf "seafileltd/seafile-mc:%s" $tag }}
{{- end }}
{{- end }}

{{/*
Return the secret name
*/}}
{{- define "seafile.secretName" -}}
{{- if .Values.seafile.existingSecret }}
{{- .Values.seafile.existingSecret }}
{{- else }}
{{- include "seafile.fullname" . }}-secret
{{- end }}
{{- end }}

{{/*
Cluster: frontend selector labels
*/}}
{{- define "seafile.frontendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "seafile.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Cluster: backend selector labels
*/}}
{{- define "seafile.backendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "seafile.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Cluster init mode: follows seafile.initMode unless overridden
*/}}
{{- define "seafile.cluster.initMode" -}}
{{- if ne (.Values.seafile.cluster.initMode | toString) "" -}}
{{- .Values.seafile.cluster.initMode -}}
{{- else -}}
{{- .Values.seafile.initMode -}}
{{- end -}}
{{- end }}

{{/*
Cluster: frontend replica count (0 during init, configured value after)
*/}}
{{- define "seafile.cluster.frontendReplicas" -}}
{{- if eq (include "seafile.cluster.initMode" .) "true" -}}
0
{{- else -}}
{{- .Values.seafile.cluster.frontend.replicas | default 2 -}}
{{- end -}}
{{- end }}

{{/*
PVC access mode: forced to ReadWriteMany in cluster mode
*/}}
{{- define "seafile.persistence.accessMode" -}}
{{- if .Values.seafile.cluster.enabled -}}
ReadWriteMany
{{- else -}}
{{- .Values.seafile.persistence.accessMode -}}
{{- end -}}
{{- end }}

{{/*
Database host: internal service name or user-provided
*/}}
{{- define "seafile.database.host" -}}
{{- if eq .Values.seafile.database.mode "internal" -}}
{{- include "seafile.fullname" . }}-mariadb
{{- else -}}
{{- .Values.seafile.database.host -}}
{{- end -}}
{{- end }}

{{/*
Database port
*/}}
{{- define "seafile.database.port" -}}
{{- if eq .Values.seafile.database.mode "internal" -}}
3306
{{- else -}}
{{- .Values.seafile.database.port -}}
{{- end -}}
{{- end }}

{{/*
Cache host: internal service name or user-provided
*/}}
{{- define "seafile.cache.host" -}}
{{- if eq .Values.seafile.cache.mode "internal" -}}
{{- include "seafile.fullname" . }}-redis
{{- else if eq .Values.seafile.cache.provider "redis" -}}
{{- .Values.seafile.cache.redis.host -}}
{{- else -}}
{{- .Values.seafile.cache.memcached.host -}}
{{- end -}}
{{- end }}

{{/*
Cache port
*/}}
{{- define "seafile.cache.port" -}}
{{- if eq .Values.seafile.cache.mode "internal" -}}
6379
{{- else if eq .Values.seafile.cache.provider "redis" -}}
{{- .Values.seafile.cache.redis.port -}}
{{- else -}}
{{- .Values.seafile.cache.memcached.port -}}
{{- end -}}
{{- end }}

{{/*
Elasticsearch host: internal service name or user-provided
*/}}
{{- define "seafile.elasticsearch.host" -}}
{{- if eq .Values.seafile.elasticsearch.mode "internal" -}}
{{- include "seafile.fullname" . }}-elasticsearch
{{- else -}}
{{- .Values.seafile.elasticsearch.host -}}
{{- end -}}
{{- end }}

{{/*
Elasticsearch port
*/}}
{{- define "seafile.elasticsearch.port" -}}
{{- if eq .Values.seafile.elasticsearch.mode "internal" -}}
9200
{{- else -}}
{{- .Values.seafile.elasticsearch.port -}}
{{- end -}}
{{- end }}

{{/*
Metadata server host: internal service name or user-provided
*/}}
{{- define "seafile.metadata.host" -}}
{{- if eq .Values.seafile.metadata.mode "internal" -}}
{{- printf "%s-metadata.%s.svc.cluster.local" (include "seafile.fullname" .) .Release.Namespace -}}
{{- else -}}
{{- .Values.seafile.metadata.host -}}
{{- end -}}
{{- end }}

{{/*
Metadata server port
*/}}
{{- define "seafile.metadata.port" -}}
{{- if eq .Values.seafile.metadata.mode "internal" -}}
8084
{{- else -}}
{{- .Values.seafile.metadata.port -}}
{{- end -}}
{{- end }}

{{/*
Notification server internal host (used in seafile.conf and INNER_NOTIFICATION_SERVER_URL)
*/}}
{{- define "seafile.notification.host" -}}
{{- if and .Values.seafile.notification.enabled (eq .Values.seafile.notification.mode "internal") -}}
{{- printf "%s-notification.%s.svc.cluster.local" (include "seafile.fullname" .) .Release.Namespace -}}
{{- else -}}
127.0.0.1
{{- end -}}
{{- end }}

{{/*
Notification server inner URL (used by Seahub to reach the notification server)
*/}}
{{- define "seafile.notification.innerUrl" -}}
{{- if and .Values.seafile.notification.enabled (eq .Values.seafile.notification.mode "internal") -}}
{{- printf "http://%s-notification.%s.svc.cluster.local:8083" (include "seafile.fullname" .) .Release.Namespace -}}
{{- else -}}
http://127.0.0.1:8083
{{- end -}}
{{- end }}

{{/*
Notification server URL: auto-derived from server hostname/protocol; override via notification.url
*/}}
{{- define "seafile.notification.url" -}}
{{- if .Values.seafile.notification.url -}}
{{- .Values.seafile.notification.url -}}
{{- else -}}
{{- printf "%s://%s/notification" .Values.seafile.server.protocol .Values.seafile.server.hostname -}}
{{- end -}}
{{- end }}

{{/*
SeaDoc server URL: auto-derived for internal mode, user-provided for external
*/}}
{{- define "seafile.seadoc.url" -}}
{{- if and .Values.seafile.seadoc.enabled (eq .Values.seafile.seadoc.mode "internal") -}}
{{- printf "%s://%s/sdoc-server" .Values.seafile.server.protocol .Values.seafile.server.hostname -}}
{{- else -}}
{{- .Values.seafile.seadoc.url -}}
{{- end -}}
{{- end }}

{{/*
Validate ingress.ingressClassName when ingress.enabled. Must be one of:
nginx, nginx-traefik, traefik. Empty fails.

Class semantics for the optional WebSocket sub-Ingress (notification +
seadoc):
  - nginx:
      nginx-* timeout annotations work natively against rke2-ingress-nginx.
  - nginx-traefik:
      Bridge provider translates nginx-* timeout annotations into its
      internal middleware. We additionally emit a ServersTransport CRD
      and reference it from the WS Ingress so behaviour is deterministic
      across both serving paths.
  - traefik:
      nginx-* annotations are silently ignored. WebSocket connections
      would close at the default backend idle timeout (~90s). The
      chart-emitted ServersTransport CRD lifts that to
      websocket.serversTransport.idleConnTimeout (default 3600s).

Usage: {{ include "seafile.ingress.validateClass" . }}
*/}}
{{- define "seafile.ingress.validateClass" -}}
{{- $allowed := list "nginx" "nginx-traefik" "traefik" -}}
{{- $cls := .Values.seafile.ingress.ingressClassName | default "" -}}
{{- if not (has $cls $allowed) -}}
{{- fail (printf "seafile.ingress.ingressClassName is required and must be one of %v; got %q" $allowed $cls) -}}
{{- end -}}
{{- end -}}

{{/*
Annotation map for the primary Seafile Ingress.
  - className == "traefik": strip nginx.ingress.kubernetes.io/* (the
    native provider ignores them; leaving them is dead weight that
    misleads operators reading the live Ingress).
  - className == "nginx-traefik": keep nginx-* keys — the bridge
    provider translates recognised ones (proxy-body-size,
    whitelist-source-range, auth-url, …).
  - className == "nginx": keep nginx-* keys — interpreted natively.

Usage: {{ include "seafile.ingress.primaryAnnotations" . }}
*/}}
{{- define "seafile.ingress.primaryAnnotations" -}}
{{- $in := default (dict) .Values.seafile.ingress.annotations -}}
{{- $stripNginx := eq .Values.seafile.ingress.ingressClassName "traefik" -}}
{{- $out := dict -}}
{{- range $k, $v := $in -}}
{{-   if and $stripNginx (hasPrefix "nginx.ingress.kubernetes.io/" $k) -}}
{{-   else -}}
{{-     $_ := set $out $k $v -}}
{{-   end -}}
{{- end -}}
{{- $out | toYaml -}}
{{- end -}}

{{/*
Annotation map for the WebSocket sub-Ingress. Built from:
  1. `ingress.annotations` (the same base the primary Ingress uses, so
     intent annotations like ioanalytica.com/exposure or
     whitelist-source-range stay in sync without the user remembering to
     duplicate them).
  2. `ingress.websocketAnnotations` (optional WS-only overrides, merged
     on top — rarely needed).
  3. Per-class auto-injection of the WS-timeout enforcement annotation
     for nginx and nginx-traefik:
         nginx.ingress.kubernetes.io/proxy-read-timeout + proxy-send-timeout
         = ingress.websocket.idleTimeout (stripped of "s" suffix —
         nginx wants bare integer seconds).
  4. `cert-manager.io/*` is always stripped from the WS Ingress — only
     the primary Ingress should drive ingress-shim Cert creation; both
     Ingresses reference the same tls.secretName.
  5. nginx.ingress.kubernetes.io/* is stripped on className == "traefik"
     (silently ignored by the native provider).

Usage: {{ include "seafile.ingress.websocketAnnotations" . }}
*/}}
{{- define "seafile.ingress.websocketAnnotations" -}}
{{- $cls := .Values.seafile.ingress.ingressClassName | default "" -}}
{{- $base := default (dict) .Values.seafile.ingress.annotations -}}
{{- $extra := default (dict) .Values.seafile.ingress.websocketAnnotations -}}
{{- $merged := mergeOverwrite (deepCopy $base) $extra -}}
{{- $out := dict -}}
{{- $stripNginx := eq $cls "traefik" -}}
{{- range $k, $v := $merged -}}
{{-   if hasPrefix "cert-manager.io/" $k -}}
{{-   else if and $stripNginx (hasPrefix "nginx.ingress.kubernetes.io/" $k) -}}
{{-   else -}}
{{-     $_ := set $out $k $v -}}
{{-   end -}}
{{- end -}}
{{- if or (eq $cls "nginx") (eq $cls "nginx-traefik") -}}
{{-   $secs := trimSuffix "s" .Values.seafile.ingress.websocket.idleTimeout -}}
{{-   $_ := set $out "nginx.ingress.kubernetes.io/proxy-read-timeout" $secs -}}
{{-   $_ := set $out "nginx.ingress.kubernetes.io/proxy-send-timeout" $secs -}}
{{- end -}}
{{- $out | toYaml -}}
{{- end -}}

{{/*
Name of the chart-emitted Traefik ServersTransport for the WebSocket
sub-Ingress.
Usage: {{ include "seafile.ws.serversTransportName" . }}
*/}}
{{- define "seafile.ws.serversTransportName" -}}
{{- printf "%s-ws" (include "seafile.fullname" .) -}}
{{- end -}}
