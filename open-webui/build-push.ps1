param(
    [Parameter(Position=0)]
    [string]$Command
)

# ===============================
# Open WebUI Build & Push Script (Windows PowerShell)
# ===============================

$ErrorActionPreference = "Stop"

function Print-Info($msg)  { Write-Host "[INFO]  $msg" -ForegroundColor Green }
function Print-Warn($msg)  { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Print-Error($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ----- Configuration -----
$PROJECT_ID  = "ai-infra-475703"
$REGION      = "us-central1"
$REPOSITORY  = "dev-artifact-repo"
$REGISTRY    = "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}"

$FE_IMAGE_NAME = "open-webui-fe"
$BE_IMAGE_NAME = "open-webui-be"
$IMAGE_TAG = $env:IMAGE_TAG
if (-not $IMAGE_TAG) { $IMAGE_TAG = "latest" }

# ----- Functions -----

function Show-Usage {
    $lines = @(
        "Usage: .\build-push.ps1 <option>",
        "",
        "Options:",
        "  build-fe    Build frontend image only",
        "  build-be    Build backend image only",
        "  build-all   Build both images",
        "  push-fe     Push frontend image (build first)",
        "  push-be     Push backend image (build first)",
        "  push-all    Push both images",
        "  fe          Build + Push frontend",
        "  be          Build + Push backend",
        "  all         Build + Push both",
        "  clean       Remove local images",
        "  help        Show this message",
        "",
        "Example:",
        '  $env:IMAGE_TAG = "v1.0.0"',
        "  .\build-push.ps1 all"
    )
    foreach ($l in $lines) { Write-Host $l }
}

function Check-GcloudAuth {
    Print-Info "Checking gcloud authentication..."
    & gcloud auth list --filter=status:ACTIVE --format="value(account)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Print-Error "Not authenticated with gcloud. Run 'gcloud auth login'"
        exit 1
    }
    $account = (& gcloud auth list --filter=status:ACTIVE --format="value(account)")
    Print-Info "Authenticated as $account"
}

function Configure-Docker {
    Print-Info "Configuring Docker for Artifact Registry..."
    & gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
    if ($LASTEXITCODE -ne 0) { Print-Error "Failed to configure docker auth"; exit 1 }
    Print-Info "Docker configured"
}

function Create-Repository {
    Print-Info "Checking Artifact Registry repository..."
    & gcloud artifacts repositories describe $REPOSITORY --location=$REGION --project=$PROJECT_ID > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Print-Info "Repository exists"
        return
    }
    Print-Warn "Repository does not exist. Creating..."
    & gcloud artifacts repositories create $REPOSITORY --repository-format=docker --location=$REGION --description="Open WebUI Docker images" --project=$PROJECT_ID
    if ($LASTEXITCODE -ne 0) { Print-Error "Failed to create repository"; exit 1 }
    Print-Info "Repository created"
}

function Build-FE {
    Print-Info "Building frontend image..."
    & docker build -f Dockerfile.fe -t "${FE_IMAGE_NAME}:${IMAGE_TAG}" .
    if ($LASTEXITCODE -ne 0) { Print-Error "Build FE failed"; exit 1 }
    Print-Info "Frontend image built"
}

function Build-BE {
    Print-Info "Building backend image..."
    & docker build -f Dockerfile.be -t "${BE_IMAGE_NAME}:${IMAGE_TAG}" .
    if ($LASTEXITCODE -ne 0) { Print-Error "Build BE failed"; exit 1 }
    Print-Info "Backend image built"
}

function Push-FE {
    Print-Info "Tagging and pushing frontend image..."
    & docker tag  "${FE_IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${FE_IMAGE_NAME}:${IMAGE_TAG}"
    if ($LASTEXITCODE -ne 0) { Print-Error "Tag FE failed"; exit 1 }
    & docker push "${REGISTRY}/${FE_IMAGE_NAME}:${IMAGE_TAG}"
    if ($LASTEXITCODE -ne 0) { Print-Error "Push FE failed"; exit 1 }
    Print-Info "Frontend image pushed"
}

function Push-BE {
    Print-Info "Tagging and pushing backend image..."
    & docker tag  "${BE_IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${BE_IMAGE_NAME}:${IMAGE_TAG}"
    if ($LASTEXITCODE -ne 0) { Print-Error "Tag BE failed"; exit 1 }
    & docker push "${REGISTRY}/${BE_IMAGE_NAME}:${IMAGE_TAG}"
    if ($LASTEXITCODE -ne 0) { Print-Error "Push BE failed"; exit 1 }
    Print-Info "Backend image pushed"
}

function Clean {
    Print-Info "Removing local images..."
    & docker rmi "${FE_IMAGE_NAME}:${IMAGE_TAG}" -f > $null 2>&1
    & docker rmi "${BE_IMAGE_NAME}:${IMAGE_TAG}" -f > $null 2>&1
    & docker rmi "${REGISTRY}/${FE_IMAGE_NAME}:${IMAGE_TAG}" -f > $null 2>&1
    & docker rmi "${REGISTRY}/${BE_IMAGE_NAME}:${IMAGE_TAG}" -f > $null 2>&1
    Print-Info "Cleanup complete"
}

if (-not $Command) { Show-Usage; exit 0 }

switch ($Command) {
    "build-fe"  { Build-FE }
    "build-be"  { Build-BE }
    "build-all" { Build-FE; Build-BE }
    "push-fe"   { Check-GcloudAuth; Configure-Docker; Create-Repository; Push-FE }
    "push-be"   { Check-GcloudAuth; Configure-Docker; Create-Repository; Push-BE }
    "push-all"  { Check-GcloudAuth; Configure-Docker; Create-Repository; Push-FE; Push-BE }
    "fe"        { Build-FE; Check-GcloudAuth; Configure-Docker; Create-Repository; Push-FE }
    "be"        { Build-BE; Check-GcloudAuth; Configure-Docker; Create-Repository; Push-BE }
    "all"       { Build-FE; Build-BE; Check-GcloudAuth; Configure-Docker; Create-Repository; Push-FE; Push-BE }
    "clean"     { Clean }
    "help"      { Show-Usage }
    default     { Print-Error "Unknown option: $Command"; Show-Usage; exit 1 }
}

Write-Host "Done."
