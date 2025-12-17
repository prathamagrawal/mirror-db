{{/*
Expand the name of the chart.
*/}}
{{- define "mirror-db.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mirror-db.fullname" -}}
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
{{- define "mirror-db.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Namespace to use for all resources
*/}}
{{- define "mirror-db.namespace" -}}
{{- if .Values.global.namespace }}
{{- .Values.global.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mirror-db.labels" -}}
helm.sh/chart: {{ include "mirror-db.chart" . }}
{{ include "mirror-db.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: postgres-cluster
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mirror-db.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mirror-db.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (printf "%s-service-account" (include "mirror-db.fullname" .)) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret containing credentials
*/}}
{{- define "mirror-db.secretName" -}}
{{- if .Values.credentials.existingSecret }}
{{- .Values.credentials.existingSecret }}
{{- else }}
{{- printf "%s-creds" (include "mirror-db.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Monitor hostname
*/}}
{{- define "mirror-db.monitorHost" -}}
{{- printf "postgres-monitor.%s.svc.cluster.local" (include "mirror-db.namespace" .) }}
{{- end }}

{{/*
Primary service hostname
*/}}
{{- define "mirror-db.primaryHost" -}}
{{- printf "postgres-primary.%s.svc.cluster.local" (include "mirror-db.namespace" .) }}
{{- end }}

{{/*
Replicas service hostname
*/}}
{{- define "mirror-db.replicasHost" -}}
{{- printf "postgres-replicas.%s.svc.cluster.local" (include "mirror-db.namespace" .) }}
{{- end }}

{{/*
Nodes service hostname
*/}}
{{- define "mirror-db.nodesHost" -}}
{{- printf "postgres-nodes.%s.svc.cluster.local" (include "mirror-db.namespace" .) }}
{{- end }}

{{/*
Monitor URI for pg_auto_failover
*/}}
{{- define "mirror-db.monitorUri" -}}
{{- printf "postgres://autoctl_node@%s:%d/pg_auto_failover" (include "mirror-db.monitorHost" .) (int .Values.postgresql.monitorPort) }}
{{- end }}

{{/*
PostgreSQL image
*/}}
{{- define "mirror-db.postgresqlImage" -}}
{{- printf "%s:%s" .Values.postgresql.image.repository .Values.postgresql.image.tag }}
{{- end }}

{{/*
PgBouncer image
*/}}
{{- define "mirror-db.pgbouncerImage" -}}
{{- printf "%s:%s" .Values.pgbouncer.image.repository .Values.pgbouncer.image.tag }}
{{- end }}

{{/*
Pod labeler image
*/}}
{{- define "mirror-db.podLabelerImage" -}}
{{- printf "%s:%s" .Values.podLabeler.image.repository .Values.podLabeler.image.tag }}
{{- end }}

{{/*
Busybox image for init containers
*/}}
{{- define "mirror-db.busyboxImage" -}}
{{- printf "%s:%s" .Values.pgbouncer.busybox.image .Values.pgbouncer.busybox.tag }}
{{- end }}

