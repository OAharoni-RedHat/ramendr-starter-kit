# RamenDR starter kit documentation

## Architecture and connectivity

| Document / diagram | Applies to | Notes |
|--------------------|------------|-------|
| [ramendr-architecture-odf.drawio](ramendr-architecture-odf.drawio) | `odf` | Full hub/spoke schematic: ODF, Submariner, DRPC, Edge GitOps VMs |
| [ramendr-architecture-drpartner-s4.drawio](ramendr-architecture-drpartner-s4.drawio) | `drpartner-s4` | Hub S4, partner CSI, VSA replication; Submariner disabled |
| [ramendr-architecture-drpartner-minimal.drawio](ramendr-architecture-drpartner-minimal.drawio) | `drpartner-minimal` | ACM + partner operators only; no S4 or DR CRs |
| [hub-managed-connectivity.drawio](hub-managed-connectivity.drawio) | All variants | Lightweight connectivity tabs (one per variant) |
| [../README.md](../README.md) | All variants | Variant selection, S3/DRCluster matrix, secrets |

User-facing connectivity write-up (mermaid + HTML/PDF): `~/Documents/ramendr-hub-managed-connectivity.md`.

## Operational guides — applicability

| Document | odf | drpartner-s4 | drpartner-minimal | Status |
|----------|-----|--------------|-------------------|--------|
| [odf-ssl-certificate-management.md](odf-ssl-certificate-management.md) | Yes | Partial (s3CaInjector only) | No | References opp-policy chart templates; paths may differ from forked chart versions in README |
| [odf-ssl-certificate-deployment-guide.md](odf-ssl-certificate-deployment-guide.md) | Yes | Partial | No | Same as above — ODF MCG focus |
| [cluster-proxy-ca-policy.md](cluster-proxy-ca-policy.md) | Yes | Yes | Yes | Describes ACM CA bundle policies; verify policy names against deployed opp-policy chart |
| [cluster-proxy-ca-policy-complete.md](cluster-proxy-ca-policy-complete.md) | Yes | Yes | Yes | Superset of cluster-proxy-ca-policy |
| [cluster-proxy-ca-policy-dynamic.md](cluster-proxy-ca-policy-dynamic.md) | Yes | Yes | Yes | Dynamic CA extraction variant |
| [ca-bundle-complete-solution.md](ca-bundle-complete-solution.md) | Yes | Yes | Yes | End-to-end CA distribution narrative |
| [sync-timeout-fix.md](sync-timeout-fix.md) | Yes | Yes | Yes | Historical ArgoCD sync timeout notes; still relevant for policy-heavy syncs |

### Summary

- **odf**: All docs apply; ODF SSL and Submariner docs are primary for that variant.
- **drpartner-s4**: Use cluster-proxy / CA docs and opp-policy `s3CaInjector` for hub S4 TLS. ODF SSL guides apply only to MCG-style endpoints if you add them manually. Submariner is disabled by default — ignore Submariner sections.
- **drpartner-minimal**: Only ACM/cluster-proxy CA guidance applies. No S3 profile or ODF SSL work from the pattern.

Policy YAML filenames in these guides refer to templates shipped in the **opp-policy** and **odf-dr** charts (fork pins in root README), not files in this repository.
