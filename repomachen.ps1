function Show-Usage {
    Write-Host "Usage: .\repomachen.ps1 -n <repository_name> -t <github_token> -l <local_path> [-d <optional_description>] [-r <readme_content>]"
}

if ($args.Count -lt 5) {
    Write-Host "Insufficient arguments provided."
    Show-Usage
    exit 1
}

$name = $null
$description = $null
$token = $null
$local_path = $null
$readme_content = $null

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '-n' { $name = $args[++$i] }
        '-d' { $description = $args[++$i] }
        '-t' { $token = $args[++$i] }
        '-l' { $local_path = $args[++$i]}
        '-r' { $readme_content = $args[++$i]}
        default { Write-Host "Unknown argument: $($args[$i])" }
    }
}


if (-not $name) {
    Write-Host "Missing required option: -n <repository name>"
    Show-Usage
    exit 1
}

if (-not $token) {
    Write-Host "Missing required option: -n <GitHub token>"
    Show-Usage
    exit 1
}

if (-not $local_path) {
    Write-Host "Missing required option: -l <local path>"
    Show-Usage
    exit 1
}

function Get-Username {
    try {
        $userInfo = Invoke-RestMethod -Uri "https://api.github.com/user" -Method Get -Headers @{
            Authorization = "token $token"
            "User-Agent" = "PowerShell"
        }
        return $userInfo.login
    } catch {
        Write-Host "Error retrieving username: $_"
        exit 1
    }
}

$username = Get-Username

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git is not installed or not found in PATH. Please install Git and try again."
    exit 1
}

$privacyInput = Read-Host "Should the repository be private? (y/n)"
$privacy = $privacyInput -eq 'y'

$body = @{
    name        = $name
    description = $description
    private     = $privacy
}

$jsonBody = $body | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers @{
        Authorization = "token $token"
        "User-Agent" = "PowerShell"
    } -Body $jsonBody -ContentType "application/json"

    Write-Host "Repository '$name' created successfully."

    Set-Location -Path $local_path
    New-Item -ItemType Directory -Name $name -Force | Out-Null
    Set-Location -PAth "$local_path\$name" 

    git init

    if ($readme_content) {
        Set-Content -Path "README.md" -Value $readme_content -Force
    } else {
        Set-Content -Path "README.md" -Value @"
# $name

## Description
$description

## Installation
1. Clone the repo: `git clone https://github.com/$username/$name.git`
2. Navigate into the project directory
3. Run the installation script

## Usage
Provide examples of how to use your project.

## Contributing
Guidelines for contributing to the project.

## License
Include a short snippet about the project's license.
"@
    }

    git add README.md
    New-Item -ItemType File -Name ".gitignore" -Force  
    git add .gitignore
    git commit -m "Initial commit with .gitignore"
    git remote add origin "https://github.com/$username/$name.git"
    git push -u origin master

} catch {
    Write-Host "Failed to create repository: $_"
}