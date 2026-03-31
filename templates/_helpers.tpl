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
{{- include "seafile.fullname" . }}-metadata
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
{{- include "seafile.fullname" . }}-notification
{{- else -}}
127.0.0.1
{{- end -}}
{{- end }}

{{/*
Notification server inner URL (used by Seahub to reach the notification server)
*/}}
{{- define "seafile.notification.innerUrl" -}}
{{- if and .Values.seafile.notification.enabled (eq .Values.seafile.notification.mode "internal") -}}
{{- printf "http://%s-notification:8083" (include "seafile.fullname" .) -}}
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
