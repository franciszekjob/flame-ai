param()
$ErrorActionPreference = "Stop"

$RootDir   = Split-Path -Parent $PSScriptRoot
$Namespace = if ($env:OBSERVABILITY_NAMESPACE) { $env:OBSERVABILITY_NAMESPACE } else { "observability" }

# Load .env if GEMINI_API_KEY not already set
if (-not $env:GEMINI_API_KEY) {
    $EnvFile = Join-Path $RootDir ".env"
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match '^([^#=\s][^=]*)=(.*)$') {
                [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
            }
        }
    }
}

if (-not $env:GEMINI_API_KEY) {
    $env:GEMINI_API_KEY = Read-Host "GEMINI_API_KEY"
}

if (-not $env:GEMINI_API_KEY) {
    Write-Error "GEMINI_API_KEY is empty; aborting."; exit 1
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is required"; exit 1
}

try { kubectl get ns $Namespace | Out-Null } catch {}
if ($LASTEXITCODE -ne 0) { kubectl create ns $Namespace }

kubectl create secret generic gemini-llm-secrets `
    --namespace $Namespace `
    "--from-literal=GEMINI_API_KEY=$($env:GEMINI_API_KEY)" `
    --dry-run=client -o yaml | kubectl apply -f -

Write-Host "Secret gemini-llm-secrets updated in namespace $Namespace."
Write-Host "Restart LiteLLM so it picks up the new key:"
Write-Host "  kubectl rollout restart deploy/litellm -n $Namespace"
