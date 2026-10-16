param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$verificationRoot = Join-Path ([IO.Path]::GetTempPath()) ('familiar-phase3a-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $verificationRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $verificationRoot 'scripts'), (Join-Path $verificationRoot 'tests'), (Join-Path $verificationRoot 'game/integration') | Out-Null
foreach ($name in @('SuspicionManager', 'InspectableClue', 'ItemDefinitions', 'ItemInventory', 'CollectibleItem', 'MemorabiliaInteraction', 'PlayerInteractionComponent')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot "scripts/$name.gd") -Destination (Join-Path $verificationRoot 'scripts')
}
New-Item -ItemType Directory -Path (Join-Path $verificationRoot 'scripts/observation') | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repoRoot 'scripts/observation') -File | Copy-Item -Destination (Join-Path $verificationRoot 'scripts/observation')
Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/observation/scenes') -Destination (Join-Path $verificationRoot 'scripts/observation') -Recurse
Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $verificationRoot 'tests') -Recurse
Copy-Item -LiteralPath (Join-Path $repoRoot 'game/integration/test_observation.gd') -Destination (Join-Path $verificationRoot 'game/integration')
# This is a disposable test project, never the repository's project.godot.
@'
config_version=5
[application]
config/name="Suspicion Phase 3A Verification"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $verificationRoot 'project.godot')
Write-Output "Verification copy (retained for inspection): $verificationRoot"

function Invoke-SuspicionGodot {
    param([string[]]$GodotArguments)
    $result = & $GodotPath --headless --path $verificationRoot --log-file (Join-Path $verificationRoot 'godot.log') @GodotArguments 2>&1
    $code = $LASTEXITCODE
    $result | ForEach-Object { Write-Output "$_" }
    $unexpectedErrors = $result | Where-Object { "$_" -match '^ERROR:' -and "$_" -notmatch '^ERROR: Failed to read the root certificate store\.' }
    if ($code -ne 0 -or $unexpectedErrors -or ($result -match 'SCRIPT ERROR|Parse Error|FAIL:')) {
        throw "Godot verification failed (exit $code): $GodotArguments"
    }
}

$scripts = Get-ChildItem -LiteralPath (Join-Path $verificationRoot 'scripts') -Filter '*.gd' -Recurse
$scripts += Get-ChildItem -LiteralPath (Join-Path $verificationRoot 'tests/suspicion') -Filter '*.gd'
$scripts += Get-Item -LiteralPath (Join-Path $verificationRoot 'game/integration/test_observation.gd')
foreach ($script in $scripts) {
    $relative = $script.FullName.Substring($verificationRoot.Length + 1).Replace('\', '/')
    Invoke-SuspicionGodot -GodotArguments @('--check-only', '--script', "res://$relative")
}
Write-Output "PARSE CHECKS PASSED: $($scripts.Count) scripts"
Invoke-SuspicionGodot -GodotArguments @('--script', 'res://tests/suspicion/verify_suspicion.gd')
Invoke-SuspicionGodot -GodotArguments @('--scene', 'res://tests/suspicion/suspicion_test.tscn', '--quit-after', '3')
Write-Output 'ISOLATED SCENE SMOKE TEST PASSED'
