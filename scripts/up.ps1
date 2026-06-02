param(
    [string]$AppNamespace = "flame-ai",
    [string]$ObsNamespace = "observability",
    [int]$MinikubeCpus    = 4,
    [string]$MinikubeMemory = "6g",
    [switch]$RunK6
)
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot

Write-Host "==> Ensuring minikube is running"
minikube status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    minikube start --driver=docker --cpus=$MinikubeCpus --memory=$MinikubeMemory
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "==> Creating Gemini API secret"
$env:OBSERVABILITY_NAMESPACE = $ObsNamespace
& "$RootDir\scripts\create-gemini-secret.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Building sorter image inside minikube"
& "$RootDir\scripts\build-image.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Applying sorter manifests"
kubectl apply -f "$RootDir\k8s\sorter\namespace.yaml"
kubectl apply -f "$RootDir\k8s\sorter\"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Installing observability stack"
$env:OBSERVABILITY_NAMESPACE = $ObsNamespace
& "$RootDir\scripts\install-stack.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Installing dashboards"
& "$RootDir\scripts\install-dashboards.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Waiting for sorter rollout"
kubectl rollout status deploy/sorter -n $AppNamespace --timeout=2m
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($RunK6) {
    Write-Host "==> Applying k6 TestRun"
    kubectl apply -f "$RootDir\k6\k8s\configmap.yaml"
    kubectl apply -f "$RootDir\k6\k8s\testrun.yaml"
}

Write-Host ""
Write-Host "Demo is up."
Write-Host ""
Write-Host "Grafana:   kubectl port-forward -n $ObsNamespace svc/grafana 3000:80"
Write-Host "           -> http://localhost:3000  (admin / admin)"
Write-Host ""
Write-Host "Pyroscope: kubectl port-forward -n $ObsNamespace svc/pyroscope 4040:4040"
Write-Host "           -> http://localhost:4040"
Write-Host ""
Write-Host "Sorter:    kubectl port-forward -n $AppNamespace svc/sorter 8080:80"
Write-Host "           -> http://localhost:8080/slow?n=5000"
Write-Host ""
Write-Host "To drive load locally:"
Write-Host "  `$env:BASE_URL='http://localhost:8080'; k6 run k6\scenarios\slow-flood.js"
