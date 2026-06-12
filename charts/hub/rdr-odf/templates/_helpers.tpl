{{/* Primary cluster name: clusterOverrides.primary.name → regionalDR[0] → fallback */}}
{{- define "rdr-odf.primaryClusterName" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- index (index (.Values.clusterOverrides | default dict) "primary" | default dict) "name" | default $dr.clusters.primary.name -}}
{{- end -}}

{{/* Secondary cluster name */}}
{{- define "rdr-odf.secondaryClusterName" -}}
{{- $dr := index .Values.regionalDR 0 -}}
{{- index (index (.Values.clusterOverrides | default dict) "secondary" | default dict) "name" | default $dr.clusters.secondary.name -}}
{{- end -}}

{{/* ClusterSet name (regionalDR[0].name) */}}
{{- define "rdr-odf.clusterSetName" -}}
{{- (index .Values.regionalDR 0).name -}}
{{- end -}}

{{/* Submariner broker namespace = clusterSet + "-broker" */}}
{{- define "rdr-odf.submarinerBrokerNamespace" -}}
{{ include "rdr-odf.clusterSetName" . }}-broker
{{- end -}}

{{/* AWS platform check */}}
{{- define "rdr-odf.clusterPlatformAws" -}}
{{- $g := .Values.global | default dict -}}
{{- if eq "aws" (lower ($g.clusterPlatform | default "AWS" | toString)) -}}1{{- else -}}0{{- end -}}
{{- end -}}

{{/* Submariner SG tagger enabled: AWS + sgTagJobEnabled */}}
{{- define "rdr-odf.submarinerSgTagJobEnabled" -}}
{{- $sm := .Values.submariner | default dict -}}
{{- $aws := eq "1" (include "rdr-odf.clusterPlatformAws" . | trim) -}}
{{- $want := and (hasKey $sm "sgTagJobEnabled") (index $sm "sgTagJobEnabled") -}}
{{- if and $aws $want -}}1{{- else -}}0{{- end -}}
{{- end -}}
