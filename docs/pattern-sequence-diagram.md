# RamenDR Starter Kit — Sequence Diagrams

## 1. Full Deployment Sequence

```mermaid
sequenceDiagram
    actor User
    participant WS as Workstation<br/>(pattern.sh / podman)
    participant Ansible as Ansible<br/>(rhvp.cluster_utils)
    participant Hub as Hub Cluster
    participant ArgoCD as ArgoCD
    participant Vault as HashiCorp Vault
    participant ESO as External Secrets<br/>Operator
    participant ACM as Advanced Cluster<br/>Management
    participant Hive as Hive
    participant Primary as Primary Cluster
    participant Secondary as Secondary Cluster

    Note over User,Secondary: Phase 1 — Install & Secret Loading

    User->>WS: make install
    WS->>Ansible: rhvp.cluster_utils.install
    Ansible->>Hub: Deploy pattern operator
    Ansible->>Hub: Deploy clustergroup chart
    Hub->>ArgoCD: Create Applications:<br/>acm, vault, golang-external-secrets,<br/>odf, opp-policy (wave 5), rdr (wave 10)

    WS->>Ansible: rhvp.cluster_utils.load_secrets
    Ansible->>Ansible: Parse ~/values-secret.yaml
    Ansible->>Vault: Write secret/hub/privatekey
    Ansible->>Vault: Write secret/hub/openshiftPullSecret
    Ansible->>Vault: Write secret/hub/aws
    Ansible->>Vault: Write secret/data/global/vm-ssh
    Ansible->>Vault: Write secret/data/global/cloud-init

    Note over User,Secondary: Phase 2 — Operator Installation (no wave)

    ArgoCD->>Hub: Sync: acm
    Hub->>ACM: Install ACM operator
    ArgoCD->>Hub: Sync: vault
    Hub->>Vault: Deploy Vault
    ArgoCD->>Hub: Sync: golang-external-secrets
    Hub->>ESO: Deploy ESO + ClusterSecretStore (vault-backend)
    ArgoCD->>Hub: Sync: odf
    Hub->>Hub: Install ODF operator
```

## 2. OPP-Policy Chart Sequence (Wave 5)

```mermaid
sequenceDiagram
    participant ArgoCD as ArgoCD
    participant Hub as Hub Cluster
    participant JobHM as Job:<br/>argocd-health-monitor
    participant CronHM as CronJob:<br/>argocd-health-monitor
    participant JobSSL as Job:<br/>odf-ssl-extractor
    participant JobPre as Job:<br/>odf-ssl-precheck
    participant Primary as Primary Cluster
    participant Secondary as Secondary Cluster

    Note over ArgoCD,Secondary: OPP-Policy Application Sync (ArgoCD app wave 5)

    rect rgb(240, 248, 255)
    Note right of ArgoCD: Wave 0
    ArgoCD->>Hub: Create ObjectBucketClaim (obc-observability)
    ArgoCD->>Hub: Create ConfigMap (argocd-ignore-dynamic-objects)
    ArgoCD->>Hub: Create RBAC (argocd-health-monitor)
    ArgoCD->>JobHM: Launch Job (MONITOR_MODE=job)
    JobHM->>Hub: Wait for managed clusters to appear
    JobHM->>Primary: Download kubeconfig
    JobHM->>Secondary: Download kubeconfig
    loop Up to 90 min (180 × 30s)
        JobHM->>Primary: Check ArgoCD pods healthy?
        JobHM->>Secondary: Check ArgoCD pods healthy?
        alt Cluster wedged
            JobHM->>Primary: Force-sync Namespace resource
        end
    end
    JobHM->>JobHM: Exit 0 (all healthy)
    end

    rect rgb(245, 245, 220)
    Note right of ArgoCD: Wave 1
    ArgoCD->>CronHM: Create CronJob (every 15 min, MONITOR_MODE=cron)
    ArgoCD->>Hub: Create RBAC (odf-ssl-extractor)
    ArgoCD->>JobSSL: Launch Job: odf-ssl-certificate-extractor
    JobSSL->>Hub: Extract hub cluster CA
    JobSSL->>Primary: Extract ingress CA (via kubeconfig)
    JobSSL->>Secondary: Extract ingress CA (via kubeconfig)
    JobSSL->>JobSSL: Create combined CA bundle (base64)
    JobSSL->>Hub: Patch ramen-hub-operator-config<br/>(add caCertificates to s3StoreProfiles)
    JobSSL->>Hub: Create cluster-proxy-ca-bundle ConfigMap
    JobSSL->>Hub: Patch Proxy/cluster (trustedCA)
    JobSSL->>Primary: Restart ramen-dr-cluster pods
    JobSSL->>Secondary: Restart ramen-dr-cluster pods
    JobSSL->>Primary: Restart Velero pods
    JobSSL->>Secondary: Restart Velero pods
    end

    rect rgb(255, 245, 238)
    Note right of ArgoCD: Wave 2
    ArgoCD->>Hub: Create RBAC (odf-ssl-precheck)
    ArgoCD->>JobPre: Launch Job: odf-ssl-precheck
    JobPre->>Hub: Verify CA bundle in ramen-hub-operator-config
    JobPre->>Primary: Verify CA certs on managed cluster
    JobPre->>Secondary: Verify CA certs on managed cluster
    alt Verification fails
        JobPre->>JobPre: Re-trigger extraction inline
    end
    ArgoCD->>Hub: Create PlacementRules (hub + managed)
    ArgoCD->>Hub: Create PlacementBindings
    ArgoCD->>Hub: Create Policy: policy-ocm-observability
    ArgoCD->>Hub: Create Policy: policy-observability-storage
    end

    rect rgb(245, 255, 245)
    Note right of ArgoCD: Wave 3–4
    ArgoCD->>Hub: Create Policy: policy-odf-ssl-certificate-management
    ArgoCD->>Hub: Create PlacementRule: placement-odf-ssl-certificates
    ArgoCD->>Hub: Create PlacementBinding: binding-odf-ssl-certificates
    ArgoCD->>Hub: Create Policy: policy-odf-managed-cluster-ssl
    end
```

## 3. RDR Chart Sequence (Wave 10)

```mermaid
sequenceDiagram
    participant ArgoCD as ArgoCD
    participant Hub as Hub Cluster
    participant Vault as Vault
    participant ESO as External Secrets<br/>Operator
    participant Hive as Hive
    participant ACM as ACM
    participant Primary as Primary Cluster
    participant Secondary as Secondary Cluster

    Note over ArgoCD,Secondary: RDR Application Sync (ArgoCD app wave 10)

    rect rgb(240, 248, 255)
    Note right of ArgoCD: Wave -1
    ArgoCD->>Hub: Create ManagedClusterSet: resilient
    end

    rect rgb(245, 245, 220)
    Note right of ArgoCD: Wave 0 — Secrets from Vault
    ArgoCD->>Hub: Create ExternalSecrets (6 total)
    ESO->>Vault: Fetch secret/hub/privatekey
    ESO->>Hub: Create Secret: primary-cluster-private-key
    ESO->>Hub: Create Secret: secondary-cluster-private-key
    ESO->>Vault: Fetch secret/hub/openshiftPullSecret
    ESO->>Hub: Create Secret: primary-cluster-pull-secret
    ESO->>Hub: Create Secret: secondary-cluster-pull-secret
    ESO->>Vault: Fetch secret/hub/aws
    ESO->>Hub: Create Secret: primary-cluster-aws-creds
    ESO->>Hub: Create Secret: secondary-cluster-aws-creds
    end

    rect rgb(255, 245, 238)
    Note right of ArgoCD: Wave 1 — Cluster Provisioning
    ArgoCD->>Hub: Create Namespace: primary-cluster
    ArgoCD->>Hub: Create Namespace: secondary-cluster
    ArgoCD->>Hub: Create Secret: install-config (primary)
    ArgoCD->>Hub: Create Secret: install-config (secondary)
    ArgoCD->>Hub: Create ClusterDeployment: primary
    ArgoCD->>Hub: Create ClusterDeployment: secondary
    ArgoCD->>Hub: Create ManagedCluster: primary
    ArgoCD->>Hub: Create ManagedCluster: secondary
    ArgoCD->>Hub: Create KlusterletAddonConfig × 2

    Hive->>Primary: Provision AWS infrastructure (VPC, EC2, DNS, LB)
    Hive->>Secondary: Provision AWS infrastructure (VPC, EC2, DNS, LB)
    Note over Hive,Secondary: ~30–45 minutes for cluster provisioning

    Primary->>ACM: Join as ManagedCluster
    Secondary->>ACM: Join as ManagedCluster
    ACM->>Primary: Deploy resilient clusterGroup apps<br/>(ODF, CNV, OADP, External Secrets, etc.)
    ACM->>Secondary: Deploy resilient clusterGroup apps<br/>(ODF, CNV, OADP, External Secrets, etc.)
    end
```

## 4. RDR Chart — Networking, DR & VMs (Waves 3–11)

```mermaid
sequenceDiagram
    participant ArgoCD as ArgoCD
    participant Hub as Hub Cluster
    participant JobODF as Job:<br/>odf-dr-prereq
    participant JobSubPre as Job:<br/>sub-prereq
    participant JobSG as Job:<br/>sub-sg-tag
    participant JobDRC as Job:<br/>drcluster-validation
    participant JobEGV as Job:<br/>edge-gitops-vms
    participant JobDRPC as Job:<br/>drpc-health
    participant Primary as Primary Cluster
    participant Secondary as Secondary Cluster

    rect rgb(240, 248, 255)
    Note right of ArgoCD: Wave 3
    ArgoCD->>Hub: Create Namespace: resilient-broker
    end

    rect rgb(245, 245, 220)
    Note right of ArgoCD: Wave 5
    ArgoCD->>JobODF: Launch Job: odf-dr-prerequisites-checker
    JobODF->>Primary: Check ODF StorageCluster ready?
    JobODF->>Secondary: Check ODF StorageCluster ready?
    JobODF->>Primary: Check S3 endpoints available?
    JobODF->>Secondary: Check S3 endpoints available?
    JobODF->>JobODF: Exit 0 (all ready)
    end

    rect rgb(255, 245, 238)
    Note right of ArgoCD: Wave 6 — Submariner
    ArgoCD->>Hub: Create Broker (resilient-broker)
    ArgoCD->>Hub: Create ManagedClusterAddOn: submariner (primary)
    ArgoCD->>Hub: Create ManagedClusterAddOn: submariner (secondary)
    ArgoCD->>Hub: Create SubmarinerConfig (primary, aws-creds)
    ArgoCD->>Hub: Create SubmarinerConfig (secondary, aws-creds)
    Hub->>Primary: Deploy Submariner gateway + routeagent
    Hub->>Secondary: Deploy Submariner gateway + routeagent
    Primary-->>Secondary: Establish IPsec tunnel
    end

    rect rgb(245, 255, 245)
    Note right of ArgoCD: Wave 7
    ArgoCD->>JobSubPre: Launch Job: submariner-prerequisites-checker
    JobSubPre->>Primary: Verify Submariner gateway running
    JobSubPre->>Secondary: Verify Submariner gateway running
    JobSubPre->>JobSubPre: Check cross-cluster connectivity
    JobSubPre->>JobSubPre: Exit 0 (connectivity OK)
    end

    rect rgb(255, 248, 240)
    Note right of ArgoCD: Wave 8 — DR Configuration
    ArgoCD->>Hub: Create Placement: gitops-vm-protection-placement-1
    ArgoCD->>Hub: Create DRPolicy: 2m-vm (interval: 2m)
    ArgoCD->>Hub: Create MirrorPeer (primary ↔ secondary, async)
    Hub->>Primary: ODF configures async replication
    Hub->>Secondary: ODF configures async replication
    ArgoCD->>JobSG: Launch Job: submariner-sg-tagger
    JobSG->>Primary: Tag AWS security groups for Submariner ports
    JobSG->>Secondary: Tag AWS security groups for Submariner ports
    ArgoCD->>JobDRC: Launch Job(s): drcluster-validation
    JobDRC->>Hub: Validate DRClusters
    JobDRC->>Hub: Validate S3 profiles
    JobDRC->>Hub: Validate fencing configuration
    end

    rect rgb(240, 240, 255)
    Note right of ArgoCD: Wave 9 — DR Protection
    ArgoCD->>Hub: Create DRPlacementControl: gitops-vm-protection
    Hub->>Hub: Ramen reconciles DRPC
    Hub->>Hub: Bind Placement → preferredCluster (primary)
    end

    rect rgb(255, 245, 245)
    Note right of ArgoCD: Wave 10 — VM Deployment
    ArgoCD->>Hub: Create ConfigMap: edge-gitops-vms-values
    ArgoCD->>JobEGV: Launch Job: edge-gitops-vms-deploy
    JobEGV->>Hub: Read DRPC Placement decision
    JobEGV->>Primary: Download kubeconfig
    JobEGV->>JobEGV: helm template edge-gitops-vms
    JobEGV->>Primary: Apply VMs (edgenode × N, drprotection=true)
    JobEGV->>Primary: Apply ExternalSecrets (vm-ssh, cloud-init)
    Note over Primary: VMs boot with cloud-init, SSH keys from Vault
    end

    rect rgb(245, 255, 250)
    Note right of ArgoCD: Wave 11 — Finalization
    ArgoCD->>JobDRPC: Launch Job: drpc-health-check-argocd-sync-disable
    JobDRPC->>Hub: Wait for DRPC status = Available
    JobDRPC->>Hub: Verify replication is active
    JobDRPC->>ArgoCD: Optionally disable auto-sync<br/>(prevent ArgoCD/Ramen conflicts)
    JobDRPC->>JobDRPC: Exit 0 (deployment complete)
    end
```

## 5. Secrets Flow Sequence

```mermaid
sequenceDiagram
    actor User
    participant File as ~/values-secret.yaml
    participant Ansible as Ansible<br/>(load_secrets)
    participant Vault as HashiCorp Vault
    participant ESO as External Secrets<br/>Operator
    participant K8s as Kubernetes Secrets
    participant CD as ClusterDeployment
    participant VM as Edge GitOps VMs

    User->>File: Create/edit values-secret.yaml
    User->>Ansible: make load-secrets

    Ansible->>File: Read secrets
    Ansible->>Vault: PUT secret/hub/privatekey (SSH key)
    Ansible->>Vault: PUT secret/hub/openshiftPullSecret (.dockerconfigjson)
    Ansible->>Vault: PUT secret/hub/aws (access_key, secret_key)
    Ansible->>Vault: PUT secret/data/global/vm-ssh (username, keys)
    Ansible->>Vault: PUT secret/data/global/cloud-init (userData)

    Note over Vault,K8s: ExternalSecrets sync (refreshInterval: 24h)

    ESO->>Vault: GET secret/hub/privatekey
    ESO->>K8s: Create: {cluster}-cluster-private-key
    ESO->>Vault: GET secret/hub/openshiftPullSecret
    ESO->>K8s: Create: {cluster}-cluster-pull-secret
    ESO->>Vault: GET secret/hub/aws
    ESO->>K8s: Create: {cluster}-cluster-aws-creds

    K8s->>CD: ClusterDeployment references secrets
    CD->>CD: Hive uses secrets to provision clusters

    Note over Vault,VM: On spoke clusters (via ExternalSecrets)
    ESO->>Vault: GET secret/data/global/vm-ssh
    ESO->>K8s: Create: vm-ssh (on spoke)
    ESO->>Vault: GET secret/data/global/cloud-init
    ESO->>K8s: Create: cloud-init (on spoke)
    K8s->>VM: VMs mount ssh/cloud-init secrets
```

## 6. Disaster Recovery Sequence — Failover & Failback

```mermaid
sequenceDiagram
    actor User
    participant Hub as Hub Cluster<br/>(Ramen Hub)
    participant DRPC as DRPlacementControl
    participant Primary as Primary Cluster
    participant Secondary as Secondary Cluster
    participant ODF as ODF<br/>(Async Replication)

    Note over User,ODF: Normal Operation

    loop Every 2 minutes
        ODF->>ODF: Replicate PVCs: primary → secondary
        Hub->>Hub: Ramen captures kube objects to S3
    end

    Primary->>Primary: VMs running (drprotection=true)

    Note over User,ODF: Failover (primary goes down or manual trigger)

    User->>DRPC: Set action: Failover
    DRPC->>Hub: Ramen processes failover

    Hub->>Secondary: Promote replicated PVCs
    Hub->>Secondary: Restore kube objects from S3
    Hub->>Secondary: Update Placement → secondary
    Secondary->>Secondary: VMs start on secondary
    Hub->>Hub: Update DRPC status: FailedOver

    Note over User,ODF: Workloads now running on secondary

    loop Every 2 minutes
        ODF->>ODF: Replicate PVCs: secondary → primary (reverse)
        Hub->>Hub: Ramen captures kube objects to S3
    end

    Note over User,ODF: Failback / Relocate (when primary recovers)

    User->>DRPC: Set action: Relocate
    DRPC->>Hub: Ramen processes relocate

    Hub->>Primary: Sync latest data from secondary
    Hub->>Primary: Restore kube objects
    Hub->>Primary: Update Placement → primary
    Primary->>Primary: VMs start on primary
    Hub->>Secondary: Demote / clean up VMs
    Hub->>Hub: Update DRPC status: Relocated

    Note over User,ODF: Back to normal operation
    loop Every 2 minutes
        ODF->>ODF: Replicate PVCs: primary → secondary
    end
```

## 7. CronJob — Periodic ArgoCD Health Monitor

```mermaid
sequenceDiagram
    participant Cron as CronJob<br/>(every 15 min)
    participant Hub as Hub Cluster
    participant Primary as Primary Cluster
    participant Secondary as Secondary Cluster
    participant ArgoApp as ArgoCD Application

    Cron->>Hub: oc get managedclusters
    Hub-->>Cron: primary, secondary, local-cluster

    loop For each managed cluster (excl. local-cluster)
        Cron->>Hub: Check ManagedClusterConditionAvailable
        Cron->>Hub: Check ManagedClusterJoined
        Cron->>Hub: Download kubeconfig

        alt Primary
            Cron->>Primary: Check resilient-gitops-server pods<br/>in ramendr-starter-kit-resilient namespace
        else Secondary
            Cron->>Secondary: Check resilient-gitops-server pods<br/>in ramendr-starter-kit-resilient namespace
        end

        alt Cluster is wedged
            Cron->>ArgoApp: Force-sync Namespace resource<br/>in Application ramendr-starter-kit-resilient
            Cron->>Primary: argocd app list → refresh each
            Cron->>Primary: argocd app list → hard-refresh each
        else Cluster is healthy
            Note over Cron: No action needed
        end
    end

    alt All healthy
        Cron->>Cron: Exit 0
    else Still wedged
        Cron->>Cron: Retry (next loop iteration)
    end
```
