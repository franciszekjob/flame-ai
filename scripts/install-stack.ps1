param()
$ErrorActionPreference = "Stop"

$RootDir   = Split-Path -Parent $PSScriptRoot
$Namespace = if ($env:OBSERVABILITY_NAMESPACE) { $env:OBSERVABILITY_NAMESPACE } else { "observability" }

foreach ($cmd in @("helm", "kubectl")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is required but not installed"; exit 1
    }
}

Write-Host "==> Adding Helm repos"
try { helm repo add grafana https://grafana.github.io/helm-charts | Out-Null } catch {}
helm repo update | Out-Null

Write-Host "==> Creating namespace $Namespace"
try { kubectl get ns $Namespace | Out-Null } catch {}
if ($LASTEXITCODE -ne 0) { kubectl create ns $Namespace }

Write-Host "==> Applying grafana-plugins-provisioning ConfigMap"
$AppsYaml = Join-Path $RootDir "grafana\provisioning\apps.yaml"
kubectl create configmap grafana-plugins-provisioning `
    --namespace $Namespace `
    "--from-file=apps.yaml=$AppsYaml" `
    --dry-run=client -o yaml | kubectl apply -f -

Write-Host "==> Installing/upgrading Pyroscope"
helm upgrade --install pyroscope grafana/pyroscope `
    --namespace $Namespace `
    --values (Join-Path $RootDir "helm\values-pyroscope.yaml") `
    --wait --timeout 5m

Write-Host "==> Ensuring grafana-llm-secrets exists (placeholder; real key is in gemini-llm-secrets)"
try { kubectl get secret grafana-llm-secrets -n $Namespace | Out-Null } catch {}
if ($LASTEXITCODE -ne 0) {
    kubectl create secret generic grafana-llm-secrets `
        --namespace $Namespace `
        --from-literal=OPENAI_API_KEY="litellm"
}

Write-Host "==> Ensuring gemini-llm-secrets exists (run scripts\create-gemini-secret.ps1 to set real key)"
try { kubectl get secret gemini-llm-secrets -n $Namespace | Out-Null } catch {}
if ($LASTEXITCODE -ne 0) {
    Write-Host "    NOTE: no gemini-llm-secrets found. Creating placeholder with empty GEMINI_API_KEY."
    Write-Host "    Run scripts\create-gemini-secret.ps1 to install your Gemini API key."
    kubectl create secret generic gemini-llm-secrets `
        --namespace $Namespace `
        --from-literal=GEMINI_API_KEY=""
}

Write-Host "==> Deploying LiteLLM proxy"
kubectl apply -f (Join-Path $RootDir "k8s\litellm\configmap.yaml")
kubectl apply -f (Join-Path $RootDir "k8s\litellm\deployment.yaml")
kubectl apply -f (Join-Path $RootDir "k8s\litellm\service.yaml")

Write-Host "==> Installing/upgrading Grafana"
helm upgrade --install grafana grafana/grafana `
    --namespace $Namespace `
    --values (Join-Path $RootDir "helm\values-grafana.yaml") `
    --wait --timeout 10m

Write-Host ""
Write-Host "Observability stack installed in namespace '$Namespace'."
Write-Host "Port-forward Grafana:"
Write-Host "  kubectl port-forward -n $Namespace svc/grafana 3000:80"
Write-Host "Then open http://localhost:3000 (admin / admin)."
