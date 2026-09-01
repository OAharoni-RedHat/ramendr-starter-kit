# CI Tests for ramendr-starter-kit

Pytest is invoked per-clustergroup from the repo root via the `interop-test` Tekton task:

```
pytest -lv test_<TARGET_CLUSTERGROUP>.py --junit-xml .results/test_<TARGET_CLUSTERGROUP>.xml
```

## Required environment variables

| Variable | Description |
|---|---|
| `VP_HUBCONFIG` | Path to kubeconfig for the hub cluster |
| `VP_OCP_PRIMARY` | Path to kubeconfig for `ocp-primary` (DR spoke 1) |
| `VP_OCP_SECONDARY` | Path to kubeconfig for `ocp-secondary` (DR spoke 2) |
| `TARGET_CLUSTERGROUP` | Clustergroup to test (defaults to `hub`) |

## Running tests locally

From the repo root:

```bash
VP_HUBCONFIG=~/.kube/hub-config \
VP_OCP_PRIMARY=~/.kube/spoke-primary-config \
VP_OCP_SECONDARY=~/.kube/spoke-secondary-config \
TARGET_CLUSTERGROUP=odf \
./pattern.sh make run-ci-tests
```

## Test coverage

- `test_odf.py` — hub-side operator subscriptions, pod health, ACM ManagedCluster status, ArgoCD reachability and application health for all three clusters
