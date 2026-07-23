{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "mail.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mail.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "mail.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mail.labels" -}}
helm.sh/chart: {{ include "mail.chart" . }}
{{ include "mail.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mail.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mail.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mail.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mail.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Define checksum annotations
*/}}
{{- define "mail.checksums" -}}
# Reload the Statefulset when any mounted config/secret changes on deployment.
# Templates whose guard condition is false render empty, so their checksum is
# stable and only changes once the resource actually starts being emitted.
# NOTE: secret-cert.yaml is intentionally excluded: it uses genSignedCert, which
# regenerates on every render and would force a pod restart on every upgrade.
checksum/configmap: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
checksum/configmap-metrics: {{ include (print $.Template.BasePath "/configmap-metrics.yaml") . | sha256sum }}
checksum/secret-mount: {{ include (print $.Template.BasePath "/secret-mount.yaml") . | sha256sum }}
{{- end -}}

{{- define "mail.reloader" -}}
{{- $fullName := include "mail.fullname" . -}}
{{- $configmaps := list $fullName -}}
{{- if .Values.metrics.enabled -}}
{{- $configmaps = append $configmaps (printf "%s-metrics" $fullName) -}}
{{- $configmaps = append $configmaps (printf "%s-scripts" $fullName) -}}
{{- end -}}
{{- $secrets := list -}}
{{- if .Values.secret -}}
{{- $secrets = append $secrets $fullName -}}
{{- end -}}
{{- if .Values.mountSecret.enabled -}}
{{- $secrets = append $secrets (printf "%s-mount" $fullName) -}}
{{- end }}
# Auto-reload postfix if somebody changes a mounted config map or secret directly
# in Kubernetes. Uses: https://github.com/stakater/Reloader
# NOTE: only resources actually rendered are listed, and the cert secret is
# intentionally excluded (see the note in "mail.checksums" above): it uses
# genSignedCert and would force a reload on every upgrade.
configmap.reloader.stakater.com/reload: {{ join "," $configmaps | quote }}
{{- if $secrets }}
secret.reloader.stakater.com/reload: {{ join "," $secrets | quote }}
{{- end }}
{{- end -}}

{{/*
Return the secret containing HTTPS/TLS certificates
*/}}
{{- define "tls.secretName" -}}
{{- $secretName := .Values.certs.existingSecret -}}
{{- if $secretName -}}
    {{- printf "%s" (tpl $secretName .) -}}
{{- else -}}
    {{- printf "%s-certs" (include "mail.fullname" .) -}}
{{- end -}}
{{- end -}}
