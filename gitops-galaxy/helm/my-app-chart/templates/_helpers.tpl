{{/*
Expand the name of the chart.
*/}}
{{- define "my-app-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-app-chart.fullname" -}}
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
{{- define "my-app-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-app-chart.labels" -}}
helm.sh/chart: {{ include "my-app-chart.chart" . }}
{{ include "my-app-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment | default "dev" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-app-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "my-app-chart.serviceAccountName" -}}
{{- $serviceAccount := .Values.serviceAccount | default dict -}}
{{- if $serviceAccount.create }}
{{- default (include "my-app-chart.fullname" .) $serviceAccount.name }}
{{- else }}
{{- default "default" $serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create config map name
*/}}
{{- define "my-app-chart.configmapName" -}}
{{- printf "%s-config" (include "my-app-chart.fullname" .) }}
{{- end }}

{{/*
Create secret name
*/}}
{{- define "my-app-chart.secretName" -}}
{{- if .Values.externalSecrets.enabled }}
{{- printf "%s-external-secret" (include "my-app-chart.fullname" .) }}
{{- else }}
{{- printf "%s-secret" (include "my-app-chart.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create PostgreSQL secret name
*/}}
{{- define "my-app-chart.postgresSecretName" -}}
{{- $postgresql := .Values.postgresql | default dict -}}
{{- $auth := $postgresql.auth | default dict -}}
{{- $auth.existingSecret | default (printf "%s-postgres" (include "my-app-chart.fullname" .)) }}
{{- end }}
