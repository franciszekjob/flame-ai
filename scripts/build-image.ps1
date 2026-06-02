param()
$ErrorActionPreference = "Stop"

$ImageName = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "flame-ai-sorter" }
$ImageTag  = if ($env:IMAGE_TAG)  { $env:IMAGE_TAG }  else { "0.1.0" }
$RootDir   = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
    Write-Error "minikube not found on PATH"; exit 1
}

minikube status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "minikube is not running; start it first (minikube start)"; exit 1
}

Write-Host "==> Building ${ImageName}:${ImageTag} into minikube's Docker daemon"
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
docker build -t "${ImageName}:${ImageTag}" $RootDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Built ${ImageName}:${ImageTag}"
