param(
    [switch]$Purge,
    [string]$AppNamespace = "flame-ai",
    [string]$ObsNamespace = "observability"
)
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot

minikube status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "minikube is not running; nothing to tear down."
    exit 0
}

Write-Host "==> Deleting k6 TestRun (if present)"
kubectl delete -f "$RootDir\k6\k8s\testrun.yaml" --ignore-not-found

Write-Host "==> Uninstalling Helm releases"
helm uninstall grafana   -n $ObsNamespace 2>$null
helm uninstall pyroscope -n $ObsNamespace 2>$null

Write-Host "==> Deleting namespaces"
kubectl delete ns $AppNamespace --ignore-not-found
kubectl delete ns $ObsNamespace --ignore-not-found

if ($Purge) {
    Write-Host "==> Deleting minikube cluster"
    minikube delete
}

Write-Host "Done."
