# RamenDR Starter Kit — Pattern Flow Diagram

## High-Level Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           USER WORKSTATION                                   │
│                                                                              │
│  values-secret.yaml ──► make install ──► pattern.sh (podman) ──►            │
│                           │                                                  │
│                           ├─► rhvp.cluster_utils.install (Ansible)           │
│                           └─► rhvp.cluster_utils.load_secrets (Ansible)      │
└──────────────────────────────┬───────────────────────────┬───────────────────┘
                               │                           │
                               ▼                           ▼
┌──────────────────────────────────────────┐  ┌────────────────────────────────┐
│       PATTERN OPERATOR / CLUSTERGROUP    │  │        HASHICORP VAULT         │
│                                          │  │                                │
│  Creates ArgoCD Applications:            │  │  secret/hub/privatekey         │
│    • acm              (no wave)          │  │  secret/hub/openshiftPullSecret│
│    • vault            (no wave)          │  │  secret/hub/aws                │
│    • golang-external-secrets (no wave)   │  │  secret/data/global/vm-ssh     │
│    • odf              (no wave)          │  │  secret/data/global/cloud-init │
│    • opp-policy       (wave 5)           │  └───────────────┬────────────────┘
│    • rdr              (wave 10)          │                  │
└──────────────────────┬───────────────────┘                  │
                       │                                      │
                       ▼                                      │
            ┌──────────────────┐                              │
            │  ArgoCD syncs    │◄─────────────────────────────┘
            │  applications    │     (ExternalSecrets read from Vault)
            └──────┬───────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
   OPP-POLICY              RDR CHART
   (wave 5)                (wave 10)
```

---

## Phase 1: Prerequisites & Operators (No Wave / Pre-Deploy)

```
make install
    │
    ├─► Install pattern operator & clustergroup chart
    │
    ├─► ArgoCD Applications created:
    │
    │   ┌──────────────────────────────────────────────────┐
    │   │  acm (open-cluster-management)                   │
    │   │  └─► Advanced Cluster Management operator        │
    │   │                                                  │
    │   │  vault (vault namespace)                         │
    │   │  └─► HashiCorp Vault                             │
    │   │                                                  │
    │   │  golang-external-secrets                         │
    │   │  └─► External Secrets Operator                   │
    │   │  └─► ClusterSecretStore: vault-backend           │
    │   │                                                  │
    │   │  odf (openshift-storage)                         │
    │   │  └─► OpenShift Data Foundation operator          │
    │   └──────────────────────────────────────────────────┘
    │
    └─► make load-secrets
        └─► values-secret.yaml ──► Vault
```

---

## Phase 2: OPP-Policy Chart (ArgoCD App, Wave 5)

All sync waves below are **within** the opp-policy ArgoCD application.

```
WAVE 0
  │
  ├─► ObjectBucketClaim (obc-observability)
  ├─► ConfigMap (argocd-ignore-dynamic-objects)
  ├─► RBAC: argocd-health-monitor (SA + ClusterRole + ClusterRoleBinding)
  └─► Job: argocd-health-monitor
      └─► argocd-health-monitor.sh (MONITOR_MODE=job)
          Waits up to 90 min for managed clusters,
          checks ArgoCD health, force-syncs if wedged
  │
WAVE 1
  │
  ├─► CronJob: argocd-health-monitor (every 15 min)
  │   └─► argocd-health-monitor.sh (MONITOR_MODE=cron)
  │       Periodic check, force-sync + ArgoCD CLI refresh
  │
  ├─► RBAC: odf-ssl-extractor
  └─► Job: odf-ssl-certificate-extractor
      └─► odf-ssl-certificate-extraction.sh
          Extracts CAs from hub + managed clusters,
          creates combined CA bundle, patches
          ramen-hub-operator-config s3StoreProfiles,
          restarts DR and Velero pods
  │
WAVE 2
  │
  ├─► RBAC: odf-ssl-certificate-precheck
  ├─► Job: odf-ssl-certificate-precheck
  │   └─► odf-ssl-precheck.sh
  │       Verifies cert distribution, retries extraction
  │
  ├─► PlacementRule: placement-openshift-plus-hub
  ├─► PlacementRule: placement-openshift-plus-managed
  ├─► PlacementBinding: binding-openshift-plus-hub
  ├─► PlacementBinding: binding-openshift-plus-managed
  ├─► Policy: policy-ocm-observability
  └─► Policy: policy-observability-storage
  │
WAVE 3
  │
  └─► Policy: policy-odf-ssl-certificate-management
      └─► Creates cluster-proxy-ca-bundle ConfigMap on hub
      └─► Patches Proxy/cluster with trustedCA
  │
WAVE 4
  │
  ├─► PlacementRule: placement-odf-ssl-certificates
  ├─► PlacementBinding: binding-odf-ssl-certificates
  └─► Policy: policy-odf-managed-cluster-ssl (disabled by default)
      └─► Distributes CA bundle to managed clusters
```

---

## Phase 3: RDR Chart (ArgoCD App, Wave 10)

All sync waves below are **within** the rdr ArgoCD application.

```
WAVE -1
  │
  └─► ManagedClusterSet: resilient
      └─► Namespace: resilient-submariner-broker (auto)
  │
WAVE 0
  │
  └─► ExternalSecrets (3 per cluster × 2 clusters = 6 total):
      │
      ├─► {cluster}-cluster-private-key    ◄── Vault: secret/hub/privatekey
      ├─► {cluster}-cluster-pull-secret    ◄── Vault: secret/hub/openshiftPullSecret
      └─► {cluster}-cluster-aws-creds      ◄── Vault: secret/hub/aws
  │
WAVE 1
  │
  └─► Per cluster (primary + secondary):
      │
      ├─► Namespace: {cluster-name}
      ├─► Secret: {cluster}-cluster-install-config
      ├─► ClusterDeployment ──────────────────────────────────┐
      │   └─► imageSetRef: img{version}-multi-appsub          │
      │   └─► platform.aws.region (from values)               │
      │   └─► References: install-config, private-key,        │
      │       pull-secret, aws-creds secrets                   │
      │                                                        │
      ├─► ManagedCluster                                       │
      │   └─► labels: purpose=regionalDR, clusterset=resilient │
      │                                                        │
      └─► KlusterletAddonConfig                               │
          └─► Enables: applicationManager, policyController,  │
              searchCollector, certPolicyController,           │
              iamPolicyController                              │
                                                               │
          ┌────────────────────────────────────────────────────┘
          ▼
  ════════════════════════════════════════════════
  ║  HIVE PROVISIONS AWS CLUSTERS (30-45 min)   ║
  ║  VPCs, EC2 instances, DNS, load balancers   ║
  ║  Clusters join ACM as managed clusters      ║
  ════════════════════════════════════════════════
          │
          ▼
  ACM deploys resilient clusterGroup apps:
    • ODF (openshift-storage)
    • CNV (openshift-cnv)
    • OADP / Velero (openshift-adp)
    • External Secrets
    • External DNS
    • Node Health Check
    • Console Plugins
  │
WAVE 3
  │
  └─► Namespace: resilient-broker
  │
WAVE 5
  │
  └─► Job: odf-dr-prerequisites-checker
      └─► odf-dr-prerequisites-check.sh
          Waits for ODF readiness on both clusters,
          verifies StorageCluster, S3 endpoints
  │
WAVE 6
  │
  ├─► Broker (Submariner)
  │   └─► In namespace: resilient-broker
  │
  └─► Per cluster:
      ├─► ManagedClusterAddOn: submariner
      └─► SubmarinerConfig
          └─► credentialsSecret: {cluster}-cluster-aws-creds
  │
WAVE 7
  │
  └─► Job: submariner-prerequisites-checker
      └─► submariner-prerequisites-check.sh
          Verifies Submariner gateway, connectivity
  │
WAVE 8
  │
  ├─► Placement: gitops-vm-protection-placement-1
  │   └─► clusterSets: [resilient]
  │   └─► predicates: purpose=regionalDR
  │
  ├─► DRPolicy: 2m-vm
  │   └─► schedulingInterval: 2m
  │   └─► replicationClassSelector (flatten-mode: force)
  │
  ├─► DRPolicy: 2m-novm (if defined)
  │
  ├─► MirrorPeer
  │   └─► items: primary + secondary
  │   └─► storageClusterRef: ocs-storagecluster
  │   └─► manageS3: true, type: async
  │
  ├─► Job: submariner-sg-tagger
  │   └─► submariner-sg-tag.sh
  │       Tags AWS security groups for Submariner ports
  │
  └─► Job(s): drcluster-validation (per DRPolicy)
      └─► drcluster-validation.sh
          Validates DRClusters, S3 profiles, fencing
  │
WAVE 9
  │
  └─► DRPlacementControl: gitops-vm-protection
      ├─► drPolicyRef: 2m-vm
      ├─► placementRef: gitops-vm-protection-placement-1
      ├─► protectedNamespaces: [gitops-vms]
      ├─► preferredCluster: {primary-cluster}
      ├─► pvcSelector: app.kubernetes.io/component=storage
      └─► kubeObjectProtection:
          └─► captureInterval: 2m
          └─► matchExpressions: drprotection=true
  │
WAVE 10
  │
  ├─► ConfigMap: edge-gitops-vms-values
  │   └─► values-egv-dr.yaml (VM configuration)
  │
  └─► Job: edge-gitops-vms-deploy
      └─► edge-gitops-vms-deploy.sh
          ├─► Downloads kubeconfigs for primary/secondary
          ├─► Determines target from DRPC Placement
          ├─► Runs: helm template edge-gitops-vms
          │   └─► VMs: edgenode × N (drprotection: true)
          │   └─► ExternalSecrets: vm-ssh, cloud-init
          │   └─► StorageClass: ocs-storagecluster-ceph-rbd-virtualization
          └─► Applies to target cluster
  │
WAVE 11
  │
  └─► Job: drpc-health-check-argocd-sync-disable
      └─► drpc-health-check-argocd-sync-disable.sh
          Waits for DRPC to be healthy,
          optionally disables ArgoCD auto-sync
          to prevent conflicts with Ramen
```

---

## Phase 4: Steady State

```
┌─────────────────────────────────────────────────────────────────────┐
│                         STEADY STATE                                 │
│                                                                      │
│  Hub Cluster                                                         │
│  ├─► ArgoCD manages all hub applications                             │
│  ├─► CronJob: argocd-health-monitor (every 15 min)                  │
│  ├─► Vault serves secrets via ExternalSecrets                        │
│  ├─► ACM manages spoke clusters                                     │
│  └─► Ramen hub operator manages DR                                  │
│                                                                      │
│  Primary Cluster                    Secondary Cluster                │
│  ├─► ODF (storage)                  ├─► ODF (storage)                │
│  ├─► CNV (virtualization)           ├─► CNV (virtualization)         │
│  ├─► OADP / Velero                  ├─► OADP / Velero               │
│  ├─► Submariner (networking)        ├─► Submariner (networking)      │
│  ├─► Edge GitOps VMs                ├─► (standby for failover)       │
│  │   └─► edgenode VMs               │                                │
│  │       (drprotection: true)        │                                │
│  └─► Ramen DR agent                 └─► Ramen DR agent              │
│                                                                      │
│  ODF Async Replication ◄─────────────────► (via MirrorPeer)         │
│  Submariner Tunnel     ◄─────────────────► (cross-cluster network)  │
│  Ramen DRPC            ◄─────────────────► (VM + PVC protection)    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Secrets Flow

```
~/values-secret.yaml
    │
    ▼
make load-secrets
    │
    ▼
Ansible: rhvp.cluster_utils.load_secrets
    │
    ▼
┌────────────────────────────────────┐
│          HASHICORP VAULT           │
│                                    │
│  secret/hub/privatekey             │──► ExternalSecret ──► {cluster}-cluster-private-key
│  secret/hub/openshiftPullSecret    │──► ExternalSecret ──► {cluster}-cluster-pull-secret
│  secret/hub/aws                    │──► ExternalSecret ──► {cluster}-cluster-aws-creds
│  secret/data/global/vm-ssh         │──► ExternalSecret ──► vm-ssh (on spoke)
│  secret/data/global/cloud-init     │──► ExternalSecret ──► cloud-init (on spoke)
└────────────────────────────────────┘
```

---

## Disaster Recovery Flow

```
NORMAL OPERATION
  ├─► VMs run on preferredCluster (primary)
  ├─► ODF async replication: primary ──► secondary (every 2 min)
  ├─► Ramen captures kube objects (every 2 min)
  └─► PVCs replicated via MirrorPeer

FAILOVER (manual or automatic)
  │
  ├─► DRPC action: Failover
  │   └─► Ramen moves Placement to secondary
  │   └─► VMs start on secondary from replicated data
  │   └─► PVCs restored from last replication
  │   └─► Kube objects restored from S3 backup
  │
  └─► VMs now running on secondary cluster

FAILBACK (manual)
  │
  ├─► DRPC action: Relocate
  │   └─► Ramen moves Placement back to primary
  │   └─► VMs migrate back to primary
  │   └─► Replication resumes primary ──► secondary
  │
  └─► Back to normal operation
```

---

## Values Override Hierarchy

```
Chart defaults (charts/hub/rdr/values.yaml)
    │
    ▼
Shared value files (values-{clusterPlatform}.yaml)
    │
    ▼
Extra value files per app:
    ├─► rdr: overrides/values-cluster-names.yaml
    ├─► opp-policy: overrides/values-cluster-names.yaml
    ├─► odf: overrides/values-odf-chart.yaml
    ├─► console-plugins (hub): overrides/values-console-plugins-hub.yaml
    └─► console-plugins (spoke): overrides/values-console-plugins-spokes.yaml
    │
    ▼
User overrides (applied at install time)
```
