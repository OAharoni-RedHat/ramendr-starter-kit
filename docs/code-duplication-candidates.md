# Code Duplication Candidates

Identified duplication across the ramendr-starter-kit repository. Items are ranked by severity.

---

## High Severity

### 1. ODF SSL Extraction Logic (~500+ lines)

**Files:**
- `charts/hub/opp/scripts/odf-ssl-certificate-extraction.sh`
- `charts/hub/opp/scripts/odf-ssl-precheck.sh` (lines 212–977)

`odf-ssl-precheck.sh` embeds a large inline script inside `trigger_certificate_extraction()` that duplicates most of `odf-ssl-certificate-extraction.sh`:
- `extract_cluster_ca`, `extract_ingress_ca`, `create_combined_ca_bundle`
- ramen-dr-cluster-operator pod restart loop
- `ramen-hub-operator-config` patching
- Velero pod restart loop
- Certificate distribution

**Recommendation:** Have `odf-ssl-precheck.sh` invoke `odf-ssl-certificate-extraction.sh` rather than embedding its own copy.

---

### 2. s3StoreProfiles Verification (~240 lines)

**Files:**
- `charts/hub/opp/scripts/odf-ssl-certificate-extraction.sh` (3 blocks: lines ~411–490, ~524–606, ~837–909)

The same verification pattern (check `s3StoreProfiles`, count profiles, check `caCertificates`, grep fallbacks) is repeated 3 times within a single script.

**Recommendation:** Extract a `verify_s3_store_profiles()` function and call it from each location.

---

### 3. Kubeconfig Download Function (~35 lines × 4 scripts)

**Files:**
- `scripts/download-kubeconfigs.sh` (lines 50–107)
- `charts/hub/opp/scripts/argocd-health-monitor.sh` (lines 38–82)
- `charts/hub/rdr/scripts/odf-dr-prerequisites-check.sh` (lines 352–398)
- `charts/hub/rdr/scripts/submariner-prerequisites-check.sh` (lines 77–122)

All implement the same logic: check cluster availability → find kubeconfig secret → try `kubeconfig` then `raw-kubeconfig` field → base64 decode → validate with `oc get nodes`.

**Recommendation:** Create `scripts/lib/kubeconfig-utils.sh` with a shared `download_kubeconfig()` function.

---

### 4. Kubeconfig Secret Extraction Pattern (~5 lines × 9 scripts)

**Files:**
- `charts/hub/opp/scripts/argocd-health-monitor.sh`
- `charts/hub/opp/scripts/odf-ssl-certificate-extraction.sh` (4 occurrences)
- `charts/hub/opp/scripts/odf-ssl-precheck.sh` (4 occurrences)
- `charts/hub/rdr/scripts/submariner-prerequisites-check.sh`
- `charts/hub/rdr/scripts/odf-dr-prerequisites-check.sh`
- `charts/hub/rdr/scripts/submariner-sg-tag.sh`
- `charts/hub/rdr/scripts/edge-gitops-vms-deploy.sh`
- `scripts/cleanup-placeholder-configmaps.sh`
- `scripts/cleanup-gitops-vms-non-primary.sh`

Repeated pattern:
```bash
oc get secret -n "$cluster" -o name | grep -E "(admin-kubeconfig|kubeconfig)" | head -1
oc get ... -o jsonpath='{.data.kubeconfig}' | base64 -d > ...
```

**Recommendation:** Consolidate into the shared kubeconfig-utils library above.

---

### 5. Pod Restart/Wait Loops (~60 lines × 4 locations)

**Files:**
- `charts/hub/opp/scripts/odf-ssl-certificate-extraction.sh` (lines 361–437, 914–989)
- `charts/hub/opp/scripts/odf-ssl-precheck.sh` (lines 480–547, 715–790)

Same pattern in all four locations: delete pods → poll with `MAX_WAIT_ATTEMPTS=30`, `WAIT_INTERVAL=10` → verify new pods are Running.

**Recommendation:** Extract a `restart_and_wait_pods()` function parameterized by namespace, label selector, and timeout.

---

### 6. Ansible Storage Class Detection (~40 lines × 2 playbooks)

**Files:**
- `ansible/odf_clean_pvcs.yml` (lines 17–51)
- `ansible/odf_fix_dataimportcrons.yml` (lines 24–58)

Nearly identical tasks: find default StorageClass → find virtualization default StorageClass → compare and set a fact. Only the variable names differ (`pvc_cleanup` vs `dataimportcron_cleanup`).

**Recommendation:** Factor into a shared role or include file with a parameterized variable name.

---

### 7. Edge GitOps VMs Values (~38 lines)

**Files:**
- `charts/hub/rdr/files/values-egv-dr.yaml` (40 lines)
- `overrides/values-egv-dr.yaml` (40 lines)

Near-duplicate content. The only meaningful difference is `disableExternalSecrets: false` vs `true`.

**Recommendation:** Use a single base file and override `disableExternalSecrets` through chart values or the overrides mechanism.

---

## Medium Severity

### 8. Install Config Structures (~70 lines × 3 locations)

**Files:**
- `charts/hub/rdr/files/default-primary-install-config.json` (56 lines)
- `charts/hub/rdr/files/default-secondary-install-config.json` (56 lines)
- `charts/hub/rdr/values.yaml` — `regionalDR[0].clusters.primary/secondary.install_config` (lines 59–131)

Primary and secondary install configs differ only in: `metadata.name`, CIDR ranges (`clusterNetwork`, `machineNetwork`, `serviceNetwork`), and `platform.aws.region`.

**Recommendation:** Use a single base template and parameterize the differing fields.

---

### 9. RBAC Template Structure (~50–80 lines × 8 templates)

**Files:**
- `charts/hub/rdr/templates/rbac-drpc-health-check-argocd-sync-disable.yaml`
- `charts/hub/rdr/templates/rbac-odf-dr-prerequisites.yaml`
- `charts/hub/rdr/templates/rbac-submariner-prerequisites.yaml`
- `charts/hub/rdr/templates/rbac-submariner-sg-tag.yaml`
- `charts/hub/rdr/templates/rbac-edge-gitops-vms-deploy.yaml`
- `charts/hub/rdr/templates/rbac-drcluster-validation.yaml`
- `charts/hub/opp/templates/rbac-argocd-health-monitor.yaml`
- `charts/hub/opp/templates/rbac-odf-ssl-extractor.yaml`

All follow the same ServiceAccount → ClusterRole → ClusterRoleBinding pattern with identical annotations, labels, namespace, and roleRef/subjects structure. Only the name, rules, and sync-wave differ.

**Recommendation:** Create a Helm named template (e.g., `define "rbac.fullSet"`) that generates all three resources from parameters.

---

### 10. Helm Helpers – Cluster Name Resolution

**Files:**
- `charts/hub/rdr/templates/_helpers.tpl` (`rdr.primaryClusterName`, `rdr.secondaryClusterName`)
- `charts/hub/opp/templates/_helpers.tpl` (`opp.primaryClusterName`, `opp.secondaryClusterName`)

Both resolve cluster names from the same values structure with slightly different precedence logic.

**Recommendation:** Unify into a shared helper library chart, or ensure both charts reference the same logic.

---

### 11. Cluster Readiness/Availability Checks (~70 lines)

**Files:**
- `charts/hub/opp/scripts/argocd-health-monitor.sh` (lines 246–296)
- `charts/hub/opp/scripts/odf-ssl-precheck.sh` (`wait_for_cluster_readiness`, lines 61–126)

Both check `ManagedClusterConditionAvailable` and `ManagedClusterJoined` with similar retry logic.

**Recommendation:** Include in the shared kubeconfig-utils library.

---

## Low Severity

### 12. PRIMARY_CLUSTER / SECONDARY_CLUSTER Defaults (7 scripts)

**Files:**
- `charts/hub/opp/scripts/argocd-health-monitor.sh`
- `charts/hub/opp/scripts/odf-ssl-certificate-extraction.sh`
- `charts/hub/opp/scripts/odf-ssl-precheck.sh`
- `charts/hub/rdr/scripts/odf-dr-prerequisites-check.sh`
- `charts/hub/rdr/scripts/submariner-prerequisites-check.sh`
- `charts/hub/rdr/scripts/edge-gitops-vms-deploy.sh`
- `scripts/extract-cluster-cas.sh`

All default to `ocp-primary` / `ocp-secondary`. Trivial but could drift.

**Recommendation:** Always inject via env vars from Helm templates (already done in most cases). Remove hardcoded defaults where possible.

---

### 13. Job Template Layout (8 templates)

All Job/CronJob templates share: metadata structure, image references, env for PRIMARY/SECONDARY_CLUSTER, `.Files.Get` script inlining. This is structural similarity rather than true duplication and is expected in Helm charts.

**Recommendation:** No action needed unless the number of jobs grows significantly. A named template could help but adds indirection.

---

## Summary

| # | Category | Severity | ~Duplicated Lines | Scripts/Files |
|---|----------|----------|-------------------|---------------|
| 1 | ODF SSL extraction logic | High | 500+ | 2 |
| 2 | s3StoreProfiles verification | High | 240 | 1 (3 blocks) |
| 3 | Kubeconfig download function | High | 140 | 4 |
| 4 | Kubeconfig secret extraction | High | 45 | 9 |
| 5 | Pod restart/wait loops | High | 240 | 2 (4 blocks) |
| 6 | Ansible storage class detection | High | 40 | 2 |
| 7 | Edge GitOps VMs values | High | 38 | 2 |
| 8 | Install config structures | Medium | 100 | 3 |
| 9 | RBAC template structure | Medium | 400 | 8 |
| 10 | Helm helpers (cluster names) | Medium | 20 | 2 |
| 11 | Cluster readiness checks | Medium | 70 | 2 |
| 12 | PRIMARY/SECONDARY defaults | Low | 14 | 7 |
| 13 | Job template layout | Low | — | 8 |
