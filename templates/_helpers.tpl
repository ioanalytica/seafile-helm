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
*/}}
{{- define "seafile.image" -}}
{{- $tag := .Values.seafile.image.tag | default .Chart.AppVersion -}}
{{- $repo := .Values.seafile.image.repository | default (printf "seafileltd/seafile-%s-mc" .Values.seafile.edition) -}}
{{- printf "%s:%s" $repo $tag }}
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
