# RamenDR starter kit documentation

## Architecture and connectivity

| Document / diagram | Applies to | Notes |
|--------------------|------------|-------|
| [ramendr-architecture-odf.drawio](ramendr-architecture-odf.drawio) | `odf` | Full hub/spoke schematic: ODF, Submariner, DRPC, Edge GitOps VMs |
| [ramendr-architecture-drpartner-s4.drawio](ramendr-architecture-drpartner-s4.drawio) | `drpartner-s4` | Hub S4, partner CSI, VSA replication; Submariner disabled |
| [ramendr-architecture-drpartner-minimal.drawio](ramendr-architecture-drpartner-minimal.drawio) | `drpartner-minimal` | ACM + partner operators only; no S4 or DR CRs |
| [ramendr-architecture.drawio](ramendr-architecture.drawio) | `odf` | Alias for the odf schematic |
| [hub-managed-connectivity.drawio](hub-managed-connectivity.drawio) | All variants | Lightweight connectivity tabs (one per variant) |
| [ramendr-hub-managed-connectivity.md](ramendr-hub-managed-connectivity.md) | All variants | Hub ↔ managed connectivity (mermaid); [HTML](ramendr-hub-managed-connectivity.html) for print-quality SVG |
| [../README.md](../README.md) | All variants | Variant selection, S3/DRCluster matrix, secrets, chart pins |

## TLS and CA (current implementation)

Certificate handling is delivered by external charts deployed via Argo CD, not local policy YAML in this repository:

| Chart | Role |
|-------|------|
| **vp-manage-proxy-cluster-ca** | Differential CA bundle for cluster API/ingress CAs (all variants) |
| **opp-policy-chart** | `s3CaInjector` injects `caCertificates` on Ramen s3StoreProfiles (`odf`, `drpartner-s4`) |

Overrides: [`overrides/values-vp-manage-proxy-cluster-ca-hub.yaml`](../overrides/values-vp-manage-proxy-cluster-ca-hub.yaml), [`overrides/values-vp-manage-proxy-cluster-ca-resilient.yaml`](../overrides/values-vp-manage-proxy-cluster-ca-resilient.yaml).

## Scripts

Manual CA and cluster helpers live under [`scripts/`](../scripts/). Verify resource names against the live cluster before using examples that reference ACM policy names.
