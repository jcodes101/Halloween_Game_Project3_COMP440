param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$HouseRegression
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$verificationRoot = Join-Path ([IO.Path]::GetTempPath()) ('familiar-phase3b-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $verificationRoot | Out-Null
foreach ($folder in @('scripts', 'tests', 'game', 'systems', 'assets')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $folder) -Destination $verificationRoot -Recurse
}
New-Item -ItemType Directory -Path (Join-Path $verificationRoot '.godot') | Out-Null
foreach ($cache in @('imported', 'global_script_class_cache.cfg', 'uid_cache.bin')) {
    $source = Join-Path $repoRoot ".godot/$cache"
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $verificationRoot '.godot') -Recurse
    }
}
# Preserve actual input bindings in a separate fixture, without copying plugins,
# autoloads, MCP configuration or the repository's project settings file.
$sourceConfig = Get-Content -LiteralPath (Join-Path $repoRoot 'project.godot') -Raw
$inputSection = [regex]::Match($sourceConfig, '(?ms)^\[input\]\s*\r?\n(.*?)(?=^\[|\z)').Value
$fixtureConfig = "config_version=5`n[application]`nconfig/name=`"The Familiar Phase 3B Test`"`n[display]`nwindow/size/viewport_width=960`nwindow/size/viewport_height=720`n$inputSection`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n"
Set-Content -LiteralPath (Join-Path $verificationRoot 'project.godot') -Value $fixtureConfig
Write-Output "Verification copy (retained): $verificationRoot"

function Invoke-HouseGodot {
    param([string[]]$GodotArguments, [string]$ExpectedPattern, [switch]$AllowHouseAudioShutdown)
    $result = & $GodotPath --headless --path $verificationRoot --log-file (Join-Path $verificationRoot 'godot.log') @GodotArguments 2>&1
    $code = $LASTEXITCODE
    $result | ForEach-Object { Write-Output "$_" }
    $houseCompleted = [bool]($result -match '^HOUSE CHECKS: \d+ / failures: 0$')
    $errors = $result | Where-Object {
        "$_" -match '^ERROR:' -and
        "$_" -notmatch '^ERROR: Failed to read the root certificate store\.' -and
        -not ($AllowHouseAudioShutdown -and $houseCompleted -and "$_" -match '^ERROR: \d+ resources still in use at exit')
    }
    if ($code -ne 0 -or $errors -or ($result -match 'SCRIPT ERROR|Parse Error|FAIL:')) {
        throw "House verification failed (exit $code): $GodotArguments"
    }
    if ($ExpectedPattern -and -not ($result -match $ExpectedPattern)) {
        throw "Verification did not reach its completion marker: $ExpectedPattern"
    }
    if ($AllowHouseAudioShutdown -and ($result -match '^ERROR: \d+ resources still in use at exit')) {
        Write-Warning 'All house assertions passed; inherited audio emitted its known resource-shutdown diagnostic after completion.'
    }
}

# Keep all fixture user:// settings inside the disposable test directory.
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $verificationRoot 'userdata'
    $env:LOCALAPPDATA = Join-Path $verificationRoot 'localdata'
    New-Item -ItemType Directory -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $parseScripts = @(Get-ChildItem -LiteralPath (Join-Path $verificationRoot 'scripts/observation/house') -Filter '*.gd')
    $parseScripts += Get-Item -LiteralPath (Join-Path $verificationRoot 'tests/suspicion/phase3b/verify_house_observation.gd')
    foreach ($script in $parseScripts) {
        $relative = $script.FullName.Substring($verificationRoot.Length + 1).Replace('\', '/')
        Invoke-HouseGodot -GodotArguments @('--check-only', '--script', "res://$relative")
    }
    Write-Output "PHASE 3B PARSE CHECKS PASSED: $($parseScripts.Count) scripts"
    Invoke-HouseGodot -GodotArguments @('--script', 'res://tests/suspicion/verify_suspicion.gd') -ExpectedPattern '^SUSPICION TESTS: \d+ passed, 0 failed'
    Invoke-HouseGodot -GodotArguments @('--scene', 'res://tests/suspicion/phase3b/verify_house_observation.tscn', '--quit-after', '3000', '--', '--verify-monster') -ExpectedPattern '^PHASE 3B CHECKS: \d+ passed, 0 failed'
    if ($HouseRegression) {
        Invoke-HouseGodot -GodotArguments @('--scene', 'res://tests/suspicion/house_preview.tscn', '--', '--verify-house') -ExpectedPattern '^HOUSE CHECKS: \d+ / failures: 0$' -AllowHouseAudioShutdown
    }
    Write-Output 'PHASE 3B VERIFICATION COMPLETED'
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
