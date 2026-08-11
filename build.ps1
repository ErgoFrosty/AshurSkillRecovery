[CmdletBinding()]
param(
    [switch]$LocalTest,
    [switch]$Validate
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceMod = Join-Path $projectRoot 'AshurSkillRecovery'
$modInfoPath = Join-Path $sourceMod '42\mod.info'
$distBase = Join-Path $projectRoot 'dist'

if (-not (Test-Path -LiteralPath $modInfoPath)) {
    throw "Source mod was not found: $modInfoPath"
}

$projectFull = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
$distFull = [IO.Path]::GetFullPath($distBase)
if (-not ($distFull + '\').StartsWith($projectFull, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to manage a dist path outside the project: $distFull"
}

if ($Validate) {
    & python (Join-Path $projectRoot 'tests\validate_project.py')
    if ($LASTEXITCODE -ne 0) { throw 'Project validation failed.' }

    $lua = Get-Command lua -ErrorAction SilentlyContinue
    if ($lua) {
        & $lua.Source (Join-Path $projectRoot 'tests\test_math.lua')
        if ($LASTEXITCODE -ne 0) { throw 'Lua recovery-math tests failed.' }
    } else {
        & python (Join-Path $projectRoot 'tests\run_lua_tests.py')
        if ($LASTEXITCODE -ne 0) { throw 'Lua recovery-math tests failed through lupa.' }
    }
}

$modInfo = Get-Content -LiteralPath $modInfoPath -Raw
$versionMatch = [regex]::Match($modInfo, '(?m)^modversion=(.+)$')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value.Trim() } else { 'dev' }

New-Item -ItemType Directory -Path $distBase -Force | Out-Null

if ($LocalTest) {
    $localTestMod = Join-Path $distBase 'AshurSkillRecoveryDev'
    $localTestZip = Join-Path $distBase "AshurSkillRecovery-B42.20-$version-LocalTest.zip"

    if (Test-Path -LiteralPath $localTestMod) {
        Remove-Item -LiteralPath $localTestMod -Recurse -Force
    }
    if (Test-Path -LiteralPath $localTestZip) {
        Remove-Item -LiteralPath $localTestZip -Force
    }

    Copy-Item -LiteralPath $sourceMod -Destination $localTestMod -Recurse
    $localInfoPath = Join-Path $localTestMod '42\mod.info'
    $localInfo = Get-Content -LiteralPath $localInfoPath -Raw
    $localInfo = $localInfo -replace '(?m)^name=.*$', 'name=Ashur Skill Recovery DEV [B42.20]'
    $localInfo = $localInfo -replace '(?m)^id=AshurSkillRecovery\r?$', 'id=AshurSkillRecoveryDev'
    if ($localInfo -notmatch '(?m)^id=AshurSkillRecoveryDev\r?$') {
        throw 'Failed to assign the distinct DEV mod ID.'
    }
    Set-Content -LiteralPath $localInfoPath -Value $localInfo -NoNewline -Encoding utf8

    $localTestPageNames = @{
        EN = 'Ashur Skill Recovery DEV'
        RU = 'Ashur Skill Recovery DEV'
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    foreach ($language in $localTestPageNames.Keys) {
        $translationPath = Join-Path $localTestMod "common\media\lua\shared\Translate\$language\Sandbox.json"
        $translationJson = [IO.File]::ReadAllText($translationPath, [Text.Encoding]::UTF8)
        $translation = $translationJson | ConvertFrom-Json
        $translation.Sandbox_AshurSkillRecovery = $localTestPageNames[$language]
        $translationJson = $translation | ConvertTo-Json -Depth 4
        [IO.File]::WriteAllText($translationPath, $translationJson, $utf8NoBom)
    }

    Compress-Archive -LiteralPath $localTestMod -DestinationPath $localTestZip -CompressionLevel Optimal
    Write-Host "Local-test mod: $localTestMod"
    Write-Host "Local-test ZIP: $localTestZip"
    return
}

$manualZip = Join-Path $distBase "AshurSkillRecovery-B42.20-$version.zip"
$workshopRoot = Join-Path $distBase 'AshurSkillRecoveryWorkshop'
$workshopMods = Join-Path $workshopRoot 'Contents\mods'
$workshopZip = Join-Path $distBase "AshurSkillRecovery-B42.20-$version-Workshop.zip"

foreach ($target in @($manualZip, $workshopZip)) {
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
}
if (Test-Path -LiteralPath $workshopRoot) {
    Remove-Item -LiteralPath $workshopRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $workshopMods -Force | Out-Null
Copy-Item -LiteralPath $sourceMod -Destination (Join-Path $workshopMods 'AshurSkillRecovery') -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot 'workshop.txt') -Destination (Join-Path $workshopRoot 'workshop.txt')
Compress-Archive -LiteralPath $sourceMod -DestinationPath $manualZip -CompressionLevel Optimal
Compress-Archive -LiteralPath $workshopRoot -DestinationPath $workshopZip -CompressionLevel Optimal

Write-Host "Workshop package: $workshopRoot"
Write-Host "Workshop ZIP: $workshopZip"
Write-Host "Manual-install ZIP: $manualZip"
