[CmdletBinding()]
param([string]$OutputDirectory = "")

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Root = Split-Path $PSScriptRoot -Parent
if (!$OutputDirectory) { $OutputDirectory = Join-Path $Root '../../../dist/conway-windows-store' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$Qa = Join-Path $OutputDirectory 'qa'
New-Item -ItemType Directory -Force $Qa | Out-Null

function Invoke-Tool([string]$Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool failed with exit code $LASTEXITCODE" }
}

$SdkBase = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
$Sdk = Get-ChildItem $SdkBase -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'x64/makeappx.exe') } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (!$Sdk) { throw 'Install the Windows SDK (MakeAppx and MakePri are required).' }
$MakeAppx = Join-Path $Sdk.FullName 'x64/makeappx.exe'
$MakePri = Join-Path $Sdk.FullName 'x64/makepri.exe'
$Project = Join-Path $Root 'windows/NithiLife.csproj'
$AssetsOutput = Join-Path $OutputDirectory 'icon-assets'
Invoke-Tool 'python' @((Join-Path $PSScriptRoot 'windows-store-assets.py'), $AssetsOutput)
Invoke-Tool 'dotnet' @('run', '--project', (Join-Path $Root 'tests/dotnet/EngineTests.csproj'), '-c', 'Release')

$Packages = Join-Path $OutputDirectory 'packages'
New-Item -ItemType Directory -Force $Packages | Out-Null
$Results = @()
foreach ($Arch in @('x64', 'arm64')) {
    $Stage = Join-Path $OutputDirectory "staging/$Arch"
    $App = Join-Path $Stage 'App'
    New-Item -ItemType Directory -Force $App | Out-Null
    Invoke-Tool 'dotnet' @('publish', $Project, '-c', 'Release', '-r', "win-$Arch", '--self-contained', 'true', '-p:PublishSingleFile=true', '-o', $App)
    $Assembly = Join-Path $Root "windows/bin/Release/net10.0-windows/win-$Arch/Conway's Game of Life Lab.dll"
    Invoke-Tool 'dotnet' @('run', '--project', (Join-Path $Root 'tests/windows-assets/AssetChecks.csproj'), '-c', 'Release', '--', $Assembly, (Join-Path $Root 'windows/AppIcon.ico'), (Join-Path $Root 'shared/tour.json'))
    if ($Arch -eq 'x64') {
        Invoke-Tool 'dotnet' @('run', '--project', (Join-Path $Root 'tests/windows-ui/WindowsUiChecks.csproj'), '-c', 'Release', "-p:ConwayAssemblyPath=$Assembly", '--', (Join-Path $Qa 'windows-ui'))
    }
    $Exe = Join-Path $App "Conway's Game of Life Lab.exe"
    $Version = [Diagnostics.FileVersionInfo]::GetVersionInfo($Exe)
    if ($Version.FileVersion -ne '3.0.0.0' -or $Version.ProductVersion -ne '3.0.0.0') {
        throw "Incorrect EXE versions: $($Version.FileVersion), $($Version.ProductVersion)"
    }
    Copy-Item (Join-Path $AssetsOutput 'Assets') $Stage -Recurse -Force
    Copy-Item (Join-Path $Root 'windows/notices') $App -Recurse -Force
    Copy-Item (Join-Path $Root 'LICENSE') (Join-Path $App 'LICENSE.txt') -Force
    $Manifest = Join-Path $Stage 'AppxManifest.xml'
    $Template = Get-Content (Join-Path $Root 'windows/store/AppxManifest.xml.in') -Raw
    [IO.File]::WriteAllText($Manifest, $Template.Replace('@ARCH@', $Arch), [Text.UTF8Encoding]::new($false))
    [xml]$Xml = Get-Content $Manifest -Raw
    $Identity = $Xml.Package.Identity
    if ($Identity.Name -ne 'NithilanVivek.ConwaysGameOfLifeLab' -or
        $Identity.Publisher -ne 'CN=9743AFE3-744A-4F36-BFC2-92F48F9B7C59' -or
        $Identity.Version -ne '3.0.0.0' -or
        $Xml.Package.Properties.PublisherDisplayName -ne 'Nithilan Vivek') {
        throw 'Package identity does not match the owner-provided Partner Center values.'
    }
    $Config = Join-Path $Qa "priconfig-$Arch.xml"
    Invoke-Tool $MakePri @('createconfig', '/cf', $Config, '/dq', 'en-US', '/o')
    Invoke-Tool $MakePri @('new', '/pr', $Stage, '/cf', $Config, '/mn', $Manifest, '/in', $Identity.Name, '/of', (Join-Path $Stage 'resources.pri'), '/o')
    $PriDump = Join-Path $Qa "resources-$Arch.xml"
    Invoke-Tool $MakePri @('dump', '/if', (Join-Path $Stage 'resources.pri'), '/of', $PriDump, '/o')
    $PriText = Get-Content $PriDump -Raw
    if ($PriText -notmatch 'targetsize' -or $PriText -notmatch 'unplated' -or $PriText -notmatch 'scale') {
        throw 'PRI does not index the scale and unplated taskbar icon variants.'
    }
    $Package = Join-Path $Packages "Conways-Game-Of-Life-Lab-3.0.0.0-$Arch.msix"
    # Do not disable MakeAppx validation with /nv. Store signs this unsigned package.
    Invoke-Tool $MakeAppx @('pack', '/d', $Stage, '/p', $Package, '/o')
    $Unpacked = Join-Path $OutputDirectory "unpacked/$Arch"
    Invoke-Tool $MakeAppx @('unpack', '/p', $Package, '/d', $Unpacked, '/o')
    Invoke-Tool 'python' @((Join-Path $PSScriptRoot 'windows-store-assets.py'), (Join-Path $Unpacked 'Assets'), '--verify-only')
    $Checked = 0
    foreach ($File in Get-ChildItem $Stage -File -Recurse) {
        if ($File.Name -eq 'AppxManifest.xml') { continue } # MakeAppx can normalize XML.
        $Relative = [IO.Path]::GetRelativePath($Stage, $File.FullName)
        $Copy = Join-Path $Unpacked $Relative
        if (!(Test-Path $Copy) -or (Get-FileHash $File.FullName).Hash -ne (Get-FileHash $Copy).Hash) {
            throw "Packaged bytes differ: $Relative"
        }
        $Checked++
    }
    [xml]$PackedXml = Get-Content (Join-Path $Unpacked 'AppxManifest.xml') -Raw
    if ($PackedXml.Package.Identity.Name -ne $Identity.Name -or
        $PackedXml.Package.Identity.Publisher -ne $Identity.Publisher -or
        $PackedXml.Package.Identity.Version -ne '3.0.0.0' -or
        $PackedXml.Package.Identity.ProcessorArchitecture -ne $Arch) { throw 'Unpacked package identity mismatch.' }
    $Results += [ordered]@{ architecture=$Arch; package=(Split-Path $Package -Leaf); sha256=(Get-FileHash $Package).Hash.ToLower(); payload_files_verified=$Checked; exe_file_version=$Version.FileVersion; exe_product_version=$Version.ProductVersion; makeappx_validation='passed'; icon_variants=93; pri_variants='indexed'; installed_windows_client_test='pending' }
}
$Bundle = Join-Path $OutputDirectory 'Conways-Game-Of-Life-Lab-3.0.0.0.msixbundle'
Invoke-Tool $MakeAppx @('bundle', '/d', $Packages, '/p', $Bundle, '/bv', '3.0.0.0', '/o')
$BundleCheck = Join-Path $OutputDirectory 'unbundled'
Invoke-Tool $MakeAppx @('unbundle', '/p', $Bundle, '/d', $BundleCheck, '/o')
foreach ($Result in $Results) {
    $BundledPackage = Join-Path $BundleCheck $Result.package
    if ((Get-FileHash $BundledPackage).Hash.ToLower() -ne $Result.sha256) { throw "Bundle changed package bytes: $($Result.package)" }
}
$Report = [ordered]@{
    name='NithilanVivek.ConwaysGameOfLifeLab'; publisher='CN=9743AFE3-744A-4F36-BFC2-92F48F9B7C59'; publisher_display_name='Nithilan Vivek';
    version='3.0.0.0'; sdk=$Sdk.Name; bundle=(Split-Path $Bundle -Leaf); bundle_sha256=(Get-FileHash $Bundle).Hash.ToLower(); packages=$Results;
    signing='Unsigned Store upload; Microsoft signs after certification'; windows_app_certification_kit='Not run'; store_submission='Not submitted'
}
$Report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Qa 'package-report.json') -Encoding utf8
$HashLines = @((Get-FileHash $Bundle)) + @(Get-ChildItem $Packages -Filter '*.msix' | Get-FileHash) |
    ForEach-Object { "$($_.Hash.ToLower())  $([IO.Path]::GetRelativePath($OutputDirectory, $_.Path).Replace('\','/'))" }
$HashLines | Set-Content (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding ascii
Write-Host "PASS: validated x64/ARM64 Store packages and bundle version 3.0.0.0"
