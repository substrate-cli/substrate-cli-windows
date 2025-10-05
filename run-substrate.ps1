# -----------------------------
# Change to project directory
# -----------------------------
Set-Location $PSScriptRoot

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

# -----------------------------
# Start API server interactively in a new PowerShell window
# -----------------------------
$API_CONTAINER_NAME = "api-server"

# Remove old API server container if it exists
$existingContainer = docker ps -a -q -f "name=$API_CONTAINER_NAME"
if ($existingContainer) {
    Write-Host "Removing old API server container..."
    docker rm -f $API_CONTAINER_NAME | Out-Null
}

Write-Host "Opening API server in a new PowerShell window interactively..."
Start-Process powershell -ArgumentList "-NoExit", "-Command cd `"$ProjectDir`"; docker-compose -f docker-compose-public.yml run --service-ports --name $API_CONTAINER_NAME api-server"

Start-Sleep -Seconds 5
Write-Host "All supporting services are running."
Write-Host "API server started interactively in a new window."
Write-Host "Press Ctrl+C here to stop all services."

# -----------------------------
# Cleanup function
# -----------------------------
function Cleanup {
    if ($global:CLEANUP_RUNNING) {
        Write-Host "`n⚠️  Cleanup already in progress! Please wait..."
        return
    }

    $global:CLEANUP_RUNNING = $true

    Write-Host "`n🛑 Shutdown initiated..."

    # Stop interactive API server
    $existingContainer = docker ps -a -q -f "name=$API_CONTAINER_NAME"
    if ($existingContainer) {
        Write-Host "📦 Stopping API server container..."
        docker stop $API_CONTAINER_NAME -t 30 | Out-Null
        docker rm -f $API_CONTAINER_NAME | Out-Null
    }

    # Stop supporting services
    Write-Host "📦 Stopping all supporting services..."
    try {
        docker-compose -f docker-compose-public.yml down --remove-orphans
        Write-Host "✅ All services stopped successfully"
    } catch {
        Write-Host "⚠️  Timeout or error stopping services, forcing cleanup..."
        docker-compose -f docker-compose-public.yml kill | Out-Null
        docker-compose -f docker-compose-public.yml rm -f | Out-Null
    }

    Exit
}

# -----------------------------
# Setup Ctrl+C handler
# -----------------------------
$null = Register-EngineEvent PowerShell.Exiting -Action { Cleanup }

# -----------------------------
# Keep-alive loop
# -----------------------------
$counter = 0
Write-Host "`n🟢 System is running. Press Ctrl+C to gracefully shutdown all services."
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while ($true) {
    Start-Sleep -Seconds 10
    $counter++
    if ($counter % 6 -eq 0) {
        Write-Host "💓 Services running... $(Get-Date -Format 'HH:mm:ss')"
    }
}
