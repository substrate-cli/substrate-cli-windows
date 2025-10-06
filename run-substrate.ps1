# -----------------------------
# Change to project directory
# -----------------------------
Set-Location $PSScriptRoot

# -----------------------------
# Containers we want to check
# -----------------------------
$containers = @("rabbitmq","redis","consumer-service","llm-node","api-server")
$allRunning = $true

foreach ($c in $containers) {
    $status = docker inspect -f '{{.State.Running}}' $c 2>$null
    if ($status -ne "true") {
        $allRunning = $false
        break
    }
}

if ($allRunning) {
    Write-Host "All containers are already running. Exiting..."
    Exit 0
}

# -----------------------------
# Global cleanup flag
# -----------------------------
$global:CLEANUP_RUNNING = $false

# -----------------------------
# Start supporting services in detached mode
# -----------------------------
Write-Host "Starting supporting services..."
docker-compose -f docker-compose-public.yml pull rabbitmq redis consumer-service llm-node
docker-compose -f docker-compose-public.yml up -d rabbitmq redis consumer-service llm-node

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to start supporting services. Exiting..."
    Exit 1
}

# Verify containers are running
$containers = @("rabbitmq","redis","consumer-service","llm-node")
foreach ($c in $containers) {
    $status = docker inspect -f '{{.State.Running}}' $c 2>$null
    if ($status -ne "true") {
        Write-Host "Container '$c' failed to start. Exiting..."
        Exit 1
    }
}

Write-Host "All supporting services are running."

# -----------------------------
# Start API server in a new PowerShell window
# -----------------------------
$API_CONTAINER_NAME = "api-server"

# Remove old API container if exists
$existingContainer = docker ps -a -q -f "name=$API_CONTAINER_NAME"
if ($existingContainer) {
    Write-Host "Removing old API server container..."
    docker rm -f $API_CONTAINER_NAME | Out-Null
}

Write-Host "Opening API server in a new PowerShell window..."
Start-Process powershell -ArgumentList "-NoExit", "-Command cd `"$PSScriptRoot`"; docker-compose -f docker-compose-public.yml run --service-ports --name $API_CONTAINER_NAME api-server"

Start-Sleep -Seconds 5
Write-Host "API server started in a new window."
Write-Host "Press Ctrl+C here to stop all services."

# -----------------------------
# Cleanup function
# -----------------------------
function Cleanup {
    if ($global:CLEANUP_RUNNING) {
        Write-Host "`nCleanup already running..."
        return
    }

    $global:CLEANUP_RUNNING = $true
    Write-Host "`nGraceful shutdown initiated..."

    # Stop API server
    $existingContainer = docker ps -a -q -f "name=$API_CONTAINER_NAME"
    if ($existingContainer) {
        Write-Host "Stopping API server container..."
        docker stop $API_CONTAINER_NAME -t 10 | Out-Null
        docker rm -f $API_CONTAINER_NAME | Out-Null
    }

    # Stop all other services
    Write-Host "Stopping supporting services..."
    try {
        docker-compose -f docker-compose-public.yml down --remove-orphans
        Write-Host "All services stopped successfully."
    } catch {
        Write-Host "Error during normal shutdown, forcing cleanup..."
        docker-compose -f docker-compose-public.yml kill | Out-Null
        docker-compose -f docker-compose-public.yml rm -f | Out-Null
    }

    Exit
}

# -----------------------------
# Handle Ctrl+C and exit
# -----------------------------
$null = Register-EngineEvent ConsoleCancelEventHandler -Action { Cleanup }

# -----------------------------
# Keep-alive loop
# -----------------------------
$counter = 0
Write-Host "`nSystem is running. Press Ctrl+C to gracefully shutdown all services."
Write-Host "--------------------------------------------------------------"

try {
    while ($true) {
        Start-Sleep -Seconds 10
        $counter++
        if ($counter % 6 -eq 0) {
            Write-Host "Services running... $(Get-Date -Format 'HH:mm:ss')"
        }
    }
} finally {
    Cleanup
}