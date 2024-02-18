{{/*
Expand the name of the chart.
*/}}
{{- define "sre-tech-challenge-senior.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sre-tech-challenge-senior.fullname" -}}
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
{{- define "sre-tech-challenge-senior.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sre-tech-challenge-senior.labels" -}}
helm.sh/chart: {{ include "sre-tech-challenge-senior.chart" . }}
{{ include "sre-tech-challenge-senior.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sre-tech-challenge-senior.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sre-tech-challenge-senior.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sre-tech-challenge-senior.serviceAccountName" -}}
{{ printf "%s-%s" (include "sre-tech-challenge-senior.fullname" . ) "account" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sre-tech-challenge-senior.serviceName" -}}
{{ printf "%s" (include "sre-tech-challenge-senior.fullname" . ) }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "sre-tech-challenge-senior.secretName" -}}
{{ printf "%s-%s" (include "sre-tech-challenge-senior.fullname" . ) "secret" }}
{{- end }}

{{/*
Create the name of the secret key to use
*/}}
{{- define "sre-tech-challenge-senior.secretKey" -}}
{{ printf "%s-%s" (include "sre-tech-challenge-senior.fullname" . ) "secret" }}
{{- end }}

{{/*
Create the name of the pvc to use
*/}}
{{- define "sre-tech-challenge-senior.pvcName" -}}
{{ printf "%s-%s" (include "sre-tech-challenge-senior.fullname" . ) "pvc" }}
{{- end }}
