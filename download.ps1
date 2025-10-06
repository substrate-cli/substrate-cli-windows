# Use first argument as target directory, default to ./gen if not provided
param (
    [string]$BaseDir = "./gen"
)

# Create base directory if it doesn't exist
if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir | Out-Null
}

# Get the list of projects inside the container
$projects = docker exec consumer-service ls /apps/substrate-home | ForEach-Object { $_.Trim() }

foreach ($project in $projects) {
    $src = "/apps/substrate-home/$project"
    $dest = Join-Path $BaseDir $project
    
    # If a folder with the same name exists, append a number to avoid overwriting
    $count = 1
    while (Test-Path $dest) {
        $dest = Join-Path $BaseDir ("{0}_{1}" -f $project, $count)
        $count++
    }
    
    # Copy the project
    docker cp "consumer-service:$src" "$dest"
    Write-Output "Copied $project to $dest"
}