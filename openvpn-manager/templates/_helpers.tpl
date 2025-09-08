{{/*
Expand the name of the chart.
*/}}
{{- define "openvpn-manager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openvpn-manager.fullname" -}}
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
{{- define "openvpn-manager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openvpn-manager.labels" -}}
helm.sh/chart: {{ include "openvpn-manager.chart" . }}
{{ include "openvpn-manager.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openvpn-manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openvpn-manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component selector labels
*/}}
{{- define "openvpn-manager.componentSelectorLabels" -}}
{{ include "openvpn-manager.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openvpn-manager.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openvpn-manager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Frontend component name
*/}}
{{- define "openvpn-manager.frontend.fullname" -}}
{{- printf "%s-%s" (include "openvpn-manager.fullname" .) "frontend" }}
{{- end }}

{{/*
Signing component name
*/}}
{{- define "openvpn-manager.signing.fullname" -}}
{{- printf "%s-%s" (include "openvpn-manager.fullname" .) "signing" }}
{{- end }}

{{/*
Certificate Transparency component name
*/}}
{{- define "openvpn-manager.certtransparency.fullname" -}}
{{- printf "%s-%s" (include "openvpn-manager.fullname" .) "certtransparency" }}
{{- end }}


{{/*
Image name helper
*/}}
{{- define "openvpn-manager.image" -}}
{{- $registry := .registry | default .Values.image.registry -}}
{{- $repository := .repository | default .Values.image.repository -}}
{{- $tag := .tag | default .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s/%s/%s:%s" $registry $repository .component $tag }}
{{- end }}

{{/*
Database URI helper for components
*/}}
{{- define "openvpn-manager.databaseUri" -}}
{{- $host := .database.host -}}
{{- $port := .database.port | toString -}}
{{- $user := .database.user -}}
{{- $name := .database.name -}}
{{- printf "postgresql://%s:$(DATABASE_PASSWORD)@%s:%s/%s" $user $host $port $name }}
{{- end }}

{{/*
Database URI helper with actual password for testing
*/}}
{{- define "openvpn-manager.databaseUriWithPassword" -}}
{{- $host := .config.database.host -}}
{{- $port := .config.database.port | toString -}}
{{- $user := .config.database.user -}}
{{- $name := .config.database.name -}}
{{- $password := .password -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" $user $password $host $port $name }}
{{- end }}
