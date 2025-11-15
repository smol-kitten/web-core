#!/usr/bin/env pwsh
# Build Test Script for PHP Docker Images
# Tests both Ubuntu 24.04 and 25.04 build chains

param(
    [Parameter()]
    [ValidateSet('24.04', '25.04', 'all')]
    [string]$Version = 'all',
    
    [Parameter()]
    [switch]$SkipBuild,
    
    [Parameter()]
    [switch]$TestOnly,
    
    [Parameter()]
    [switch]$ShowBuildOutput
)

$ErrorActionPreference = "Continue"
$ComposeFile = "docker-compose.debug.yaml"

function Write-Step {
    param([string]$Message)
    Write-Host "`n>> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Test-Service {
    param(
        [string]$Url,
        [string]$Name
    )
    
    Write-Step "Testing $Name at $Url"
    
    Start-Sleep -Seconds 2
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Success "$Name is responding (HTTP $($response.StatusCode))"
            
            if ($response.Content -match "PHP Version (\d+\.\d+\.\d+)") {
                Write-Host "   PHP Version: $($matches[1])" -ForegroundColor Yellow
            }
            
            if ($response.Content -match "imagick") {
                Write-Host "   [+] Imagick extension loaded" -ForegroundColor Green
            }
            
            return $true
        }
    }
    catch {
        Write-Failure "$Name failed: $_"
        return $false
    }
    
    return $false
}

# Main execution
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "   PHP 8.4 Docker Build Test Suite" -ForegroundColor Magenta
Write-Host "   Building from source (no sury.org dependency)" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

$profiles = @()
$testProfiles = @()

switch ($Version) {
    '24.04' {
        $profiles += 'build-2404'
        $testProfiles += 'test-2404'
        Write-Host "Target: Ubuntu 24.04 only" -ForegroundColor Yellow
    }
    '25.04' {
        $profiles += 'build-2504'
        $testProfiles += 'test-2504'
        Write-Host "Target: Ubuntu 25.04 only" -ForegroundColor Yellow
    }
    'all' {
        $profiles += 'build-all'
        $testProfiles += 'test-all'
        Write-Host "Target: Both Ubuntu 24.04 and 25.04" -ForegroundColor Yellow
    }
}

if (-not $SkipBuild -and -not $TestOnly) {
    Write-Step "Building prep images (this will take 10-15 minutes for PHP compilation)..."
    
    foreach ($profile in $profiles) {
        Write-Host "`n>> Building profile: $profile" -ForegroundColor Cyan
        
        $buildCmd = "docker compose -f $ComposeFile --profile $profile build"
        if ($ShowBuildOutput) {
            $buildCmd += " --progress=plain"
        }
        
        Write-Host "   Command: $buildCmd" -ForegroundColor DarkGray
        Invoke-Expression $buildCmd
        
        if ($LASTEXITCODE -ne 0) {
            Write-Failure "Build failed for profile $profile"
            exit 1
        }
    }
    
    Write-Success "All prep images built successfully"
}

if (-not $SkipBuild) {
    Write-Step "Building test variant images..."
    
    foreach ($profile in $testProfiles) {
        Write-Host "`n>> Building test profile: $profile" -ForegroundColor Cyan
        
        $buildCmd = "docker compose -f $ComposeFile --profile $profile build"
        if ($ShowBuildOutput) {
            $buildCmd += " --progress=plain"
        }
        
        Invoke-Expression $buildCmd
        
        if ($LASTEXITCODE -ne 0) {
            Write-Failure "Build failed for test profile $profile"
            exit 1
        }
    }
    
    Write-Success "All variant images built successfully"
}

# Start test containers
Write-Step "Starting test containers..."

foreach ($profile in $testProfiles) {
    docker compose -f $ComposeFile --profile $profile up -d
}

if ($LASTEXITCODE -ne 0) {
    Write-Failure "Failed to start test containers"
    exit 1
}

Write-Success "Test containers started"

# Wait for containers to be ready
Write-Step "Waiting for services to become healthy..."
Start-Sleep -Seconds 5

# Test services
Write-Step "Running service tests..."
$testResults = @()

if ($Version -eq '24.04' -or $Version -eq 'all') {
    Write-Host "`n[24.04] Testing Ubuntu 24.04 variants:" -ForegroundColor Magenta
    $testResults += Test-Service -Url "http://localhost:8084" -Name "Nginx 24.04 (full)"
    $testResults += Test-Service -Url "http://localhost:8085" -Name "Apache 24.04 (full)"
}

if ($Version -eq '25.04' -or $Version -eq 'all') {
    Write-Host "`n[25.04] Testing Ubuntu 25.04 variants:" -ForegroundColor Magenta
    $testResults += Test-Service -Url "http://localhost:8086" -Name "Nginx 25.04 (full)"
    $testResults += Test-Service -Url "http://localhost:8087" -Name "Apache 25.04 (full)"
}

# Show logs
Write-Step "Container logs (last 20 lines each):"

$containers = docker compose -f $ComposeFile ps --format json | ConvertFrom-Json

foreach ($container in $containers) {
    if ($container.State -eq "running") {
        Write-Host "`n>> Logs for $($container.Name):" -ForegroundColor Yellow
        docker logs $container.Name --tail 20
    }
}

# Summary
Write-Host "`n============================================================" -ForegroundColor Magenta
Write-Host "              Test Summary" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

$passed = ($testResults | Where-Object { $_ -eq $true }).Count
$failed = ($testResults | Where-Object { $_ -eq $false }).Count

Write-Host "`nPassed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -eq 0) {
    Write-Success "All tests passed!"
    Write-Host "`nServices are running on:"
    if ($Version -eq '24.04' -or $Version -eq 'all') {
        Write-Host "  - Ubuntu 24.04 Nginx:  http://localhost:8084" -ForegroundColor Cyan
        Write-Host "  - Ubuntu 24.04 Apache: http://localhost:8085" -ForegroundColor Cyan
    }
    if ($Version -eq '25.04' -or $Version -eq 'all') {
        Write-Host "  - Ubuntu 25.04 Nginx:  http://localhost:8086" -ForegroundColor Cyan
        Write-Host "  - Ubuntu 25.04 Apache: http://localhost:8087" -ForegroundColor Cyan
    }
    Write-Host "`nTo stop containers: docker compose -f $ComposeFile down" -ForegroundColor DarkGray
} else {
    Write-Failure "Some tests failed. Check logs above for details."
    exit 1
}
