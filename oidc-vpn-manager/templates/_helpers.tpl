{{/*
Expand the name of the chart.
*/}}
{{- define "oidc-vpn-manager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "oidc-vpn-manager.fullname" -}}
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
{{- define "oidc-vpn-manager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "oidc-vpn-manager.labels" -}}
helm.sh/chart: {{ include "oidc-vpn-manager.chart" . }}
{{ include "oidc-vpn-manager.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "oidc-vpn-manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oidc-vpn-manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component selector labels
*/}}
{{- define "oidc-vpn-manager.componentSelectorLabels" -}}
{{ include "oidc-vpn-manager.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "oidc-vpn-manager.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "oidc-vpn-manager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Frontend component name
*/}}
{{- define "oidc-vpn-manager.frontend.fullname" -}}
{{- printf "%s-%s" (include "oidc-vpn-manager.fullname" .) "frontend" }}
{{- end }}

{{/*
Signing component name
*/}}
{{- define "oidc-vpn-manager.signing.fullname" -}}
{{- printf "%s-%s" (include "oidc-vpn-manager.fullname" .) "signing" }}
{{- end }}

{{/*
Certificate Transparency component name
*/}}
{{- define "oidc-vpn-manager.certtransparency.fullname" -}}
{{- printf "%s-%s" (include "oidc-vpn-manager.fullname" .) "certtransparency" }}
{{- end }}


{{/*
Image name helper
*/}}
{{- define "oidc-vpn-manager.image" -}}
{{- $registry := .registry | default .Values.image.registry -}}
{{- $repository := .repository | default .Values.image.repository -}}
{{- $tag := .tag | default .Values.image.tag | default "latest" -}}
{{- printf "%s/%s/%s:%s" $registry $repository .component $tag }}
{{- end }}

{{/*
Database URI helper for components
*/}}
{{- define "oidc-vpn-manager.databaseUri" -}}
{{- $host := .database.host -}}
{{- $port := .database.port | toString -}}
{{- $user := .database.user -}}
{{- $name := .database.name -}}
{{- printf "postgresql://%s:$(DATABASE_PASSWORD)@%s:%s/%s" $user $host $port $name }}
{{- end }}

{{/*
Database URI helper with actual password for testing
*/}}
{{- define "oidc-vpn-manager.databaseUriWithPassword" -}}
{{- $host := .config.database.host -}}
{{- $port := .config.database.port | toString -}}
{{- $user := .config.database.user -}}
{{- $name := .config.database.name -}}
{{- $password := .password -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" $user $password $host $port $name }}
{{- end }}
