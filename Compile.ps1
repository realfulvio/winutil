param (
    [switch]$Run,
    [ValidateSet('Upstream', 'Redesign')]
    [string]$Interface = 'Upstream',

    # Where a Redesign build downloads itself from when it relaunches as Administrator, and what
    # the exported autorun command points to. Upstream's own address would start upstream's interface.
    [string]$ReleaseUrl = 'https://github.com/realfulvio/winutil/releases/latest/download/winutil.ps1'
)

if ($Interface -eq 'Redesign') {
    . "$PSScriptRoot\ui\redesign\ConvertTo-WinUtilRedesignInterface.ps1"
    . "$PSScriptRoot\ui\redesign\ConvertTo-WinUtilRedesignKitMode.ps1"
}

$OFS = "`r`n"

# Variable to sync between runspaces
$sync = [Hashtable]::Synchronized(@{})
$sync.configs = @{}

$script = (Get-Content -Path scripts\start.ps1) -replace '#{replaceme}', (Get-Date -Format 'yy.MM.dd')
$isLocalCompile = -not [string]::Equals($env:GITHUB_ACTIONS, "true", [StringComparison]::OrdinalIgnoreCase)
$script = $script -replace '#{islocalcompile}', $isLocalCompile.ToString().ToLowerInvariant()

$functionSources = Get-ChildItem -Path functions -Recurse -File | ForEach-Object {
    Get-Content -Path $_.FullName -Raw
}
if ($Interface -eq 'Redesign') {
    # The redesign wraps these upstream functions: upstream's becomes <Name>Upstream
    $wrapped = @('Initialize-WinUtilTabContent', 'Find-TweaksByNameOrDescription', 'Invoke-WinUtilFontScaling', 'Find-AppsByNameOrDescription', 'Invoke-WPFTab')
    $functionSources = @($functionSources | ForEach-Object { Convert-WinUtilRedesignFunctionSource -Source $_ -Name $wrapped })
    foreach ($name in $wrapped) {
        if (-not ($functionSources -match "(?m)^function ${name}Upstream \{")) {
            throw "Upstream function '$name' was not found, so the redesign cannot wrap it."
        }
    }
    $functionSources += Get-ChildItem -Path ui\redesign\functions -File | ForEach-Object {
        Get-Content -Path $_.FullName -Raw
    }

    # Two places point at upstream's published script. Both are redirected, and the build fails if
    # either is gone, so a change upstream cannot silently send the redesign back to upstream's UI.
    $upstreamScriptUrl = 'https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1'
    $upstreamAutorun = 'irm https://christitus.com/win)'
    if (-not (($script -join "`n").Contains($upstreamScriptUrl))) {
        throw 'scripts/start.ps1 no longer downloads upstream''s script from the expected address; update the redesign redirect.'
    }
    if (-not (($functionSources -join "`n").Contains($upstreamAutorun))) {
        throw 'The exported autorun command no longer uses the expected upstream address; update the redesign redirect.'
    }
    $script = $script -replace [regex]::Escape($upstreamScriptUrl), $ReleaseUrl
    $functionSources = @($functionSources | ForEach-Object { $_.Replace($upstreamAutorun, "irm $ReleaseUrl)") })

    # -Kit and -Installa exist in the redesign build only; the default build keeps upstream's scripts as they are
    $kitMode = ConvertTo-WinUtilRedesignKitMode `
        -StartScript ($script -join "`n") `
        -MainScript (Get-Content -Path scripts\main.ps1 -Raw) `
        -KitBlock (Get-Content -Path ui\redesign\main-kit.ps1 -Raw)
    $script = $kitMode.Start -split "`r?`n"
}
$script += $functionSources

Get-ChildItem config | ForEach-Object {
    $obj = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json

    if ($_.Name -eq "applications.json") {
        $fixed = [ordered]@{}
        foreach ($p in $obj.PSObject.Properties) {
            $fixed["WPFInstall$($p.Name)"] = $p.Value
        }
        $obj = [pscustomobject]$fixed
    }

    if ($Interface -eq 'Redesign' -and $_.Name -eq "themes.json") {
        $obj = ConvertTo-WinUtilRedesignThemes -Themes $obj
    }

    $json = $obj | ConvertTo-Json -Depth 10

    $sync.configs[$_.BaseName] = $obj
    $script += "`$sync.configs.$($_.BaseName) = @'`r`n$json`r`n'@ | ConvertFrom-Json"
}

if ($Interface -eq 'Redesign') {
    # UI dictionary (Italian/English), the program catalog extras (Italian descriptions, kits, icon
    # slugs) and the brand icon outlines. Non-ASCII characters are written as \uXXXX so the compiled
    # script stays ASCII, whatever encoding the file is saved or run with.
    $redesignData = [ordered]@{
        redesignstrings  = 'strings.json'
        redesignprograms = 'programs.json'
        redesignicons    = 'icons.json'
    }
    foreach ($dataName in $redesignData.Keys) {
        $dataJson = Get-Content -Path "ui\redesign\$($redesignData[$dataName])" -Raw -Encoding UTF8 | ConvertFrom-Json | ConvertTo-Json -Depth 10
        $dataJson = [regex]::Replace($dataJson, '[^\u0000-\u007F]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
        $script += "`$sync.configs.$dataName = @'`r`n$dataJson`r`n'@ | ConvertFrom-Json"
    }
}

$xaml = Get-Content -Path xaml\inputXML.xaml -Raw
if ($Interface -eq 'Redesign') {
    $xaml = ConvertTo-WinUtilRedesignInterface -Xaml $xaml
}
$script += "`$inputXML = @'`r`n$xaml`r`n'@"

$autounattendXml = Get-Content -Path tools\autounattend.xml -Raw
$script += "`$WinUtilAutounattendXml = @'`r`n$autounattendXml`r`n'@"

if ($Interface -eq 'Redesign') {
    $script += $kitMode.Main
} else {
    $script += Get-Content -Path scripts\main.ps1 -Raw
}

Set-Content -Path winutil.ps1 -Value $script

if ($Run) {
    .\Winutil.ps1
}
