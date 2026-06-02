param()
$ErrorActionPreference = "Stop"

$RootDir   = Split-Path -Parent $PSScriptRoot
$Namespace = if ($env:OBSERVABILITY_NAMESPACE) { $env:OBSERVABILITY_NAMESPACE } else { "observability" }
$DashDir   = Join-Path $RootDir "grafana\dashboards"

if (-not (Test-Path $DashDir)) {
    Write-Error "No dashboards directory at $DashDir"; exit 1
}

foreach ($json in (Get-ChildItem -Path $DashDir -Filter "*.json")) {
    $name   = $json.BaseName
    $cmName = "flame-ai-dashboard-$name"
    Write-Host "==> Installing dashboard ConfigMap $cmName"

    kubectl create configmap $cmName `
        --namespace $Namespace `
        "--from-file=$name.json=$($json.FullName)" `
        --dry-run=client -o yaml `
    | kubectl label --local -f - grafana_dashboard=1 -o yaml --dry-run=client `
    | kubectl apply -f -

    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Done. Grafana sidecar will reload within ~30s."
