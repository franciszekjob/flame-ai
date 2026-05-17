# K6 load scenarios

Two scripts:

| Script | What it does |
| :--- | :--- |
| `scenarios/slow-flood.js` | Ramping VUs hitting only `/slow`. Bubble sort dominates. |
| `scenarios/mixed.js` | 90/10 split between `/slow` and `/fast` — slow still dominates but with Timsort sliver. |

## Run locally (against port-forward)

```bash
kubectl port-forward -n flame-ai svc/sorter 8080:80 &
BASE_URL=http://localhost:8080 k6 run k6/scenarios/slow-flood.js
```

## Run in-cluster (via k6-operator)

Install the operator once:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install k6-operator grafana/k6-operator -n k6-operator-system --create-namespace
```

Apply the script and the TestRun:

```bash
kubectl apply -f k6/k8s/configmap.yaml
kubectl apply -f k6/k8s/testrun.yaml
```

Tail the logs:

```bash
kubectl logs -n flame-ai -l k6_cr=slow-flood -f
```

Delete the TestRun to stop:

```bash
kubectl delete -f k6/k8s/testrun.yaml
```
