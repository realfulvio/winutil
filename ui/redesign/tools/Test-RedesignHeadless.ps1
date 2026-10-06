<#
.SYNOPSIS
    Checks the redesigned interface without starting WinUtil and without touching the machine.

.DESCRIPTION
    Loads the redesigned window and the redesign's functions in memory, with a simulated $sync and
    stubs for everything that would read or change the system, then exercises the Tweaks tab:
    the cards, selection, the Apply button, filters, search, the language switch, the impact bars,
    the progress panel and the font scaling. It never applies, undoes or installs anything.

    It needs Windows with WPF and an STA thread (the default for pwsh in a console). It is a
    developer check, not part of the Pester suite; run it from any folder.

.PARAMETER RenderDir
    When given, the window is also rendered to PNG files there, with sample data. These images
    are for reviewing the layout and are not screenshots of the running program.

.EXAMPLE
    .\ui\redesign\tools\Test-RedesignHeadless.ps1 -RenderDir $env:TEMP\winutil-renders
#>
[CmdletBinding()]
param(
    [string]$RenderDir
)

$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    throw 'Run this in an STA thread (pwsh in a console is STA by default; use -STA otherwise).'
}
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $repoRoot 'ui\redesign\ConvertTo-WinUtilRedesignInterface.ps1')
if ($RenderDir) { New-Item -ItemType Directory -Force $RenderDir | Out-Null }

# ---- $sync like start.ps1 and Compile.ps1 give it ------------------------------------------
$global:sync = [Hashtable]::Synchronized(@{})
$sync.configs = @{}
foreach ($file in Get-ChildItem (Join-Path $repoRoot 'config') -Filter *.json) {
    $sync.configs[$file.BaseName] = Get-Content $file.FullName -Raw | ConvertFrom-Json
}
$sync.configs.themes = ConvertTo-WinUtilRedesignThemes -Themes $sync.configs.themes
$sync.configs.redesignstrings = Get-Content (Join-Path $repoRoot 'ui\redesign\strings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$sync.preferences = @{ theme = 'Dark' }
foreach ($name in 'selectedApps', 'selectedTweaks', 'selectedToggles', 'selectedFeatures', 'selectedAppx') {
    $sync[$name] = [System.Collections.Generic.List[string]]::new()
}
$sync.InitializedTabs = @{}
$sync.currentTab = 'Tweaks'

# ---- functions: upstream (three renamed) + redesign, as Compile.ps1 does ---------------------
$wrapped = @('Initialize-WinUtilTabContent', 'Find-TweaksByNameOrDescription', 'Invoke-WinUtilFontScaling')
foreach ($file in Get-ChildItem (Join-Path $repoRoot 'functions') -Recurse -File) {
    . ([scriptblock]::Create((Convert-WinUtilRedesignFunctionSource -Source (Get-Content $file.FullName -Raw) -Name $wrapped)))
}
foreach ($file in Get-ChildItem (Join-Path $repoRoot 'ui\redesign\functions') -File) {
    . ([scriptblock]::Create((Get-Content $file.FullName -Raw)))
}
# Stubs: nothing below may read or change the machine
function Get-WinUtilToggleStatus { $false }
function Get-WinUtilRegistryComboState { 'Enabled' }
function Initialize-WinUtilTabContentUpstream { param($TabName, [switch]$Yield) }
function Invoke-WPFPopup { param($Action, $Popups, $PopupActionTable) }
function Invoke-WPFButton { param($Button) }
function Write-WinUtilLog { param($Message, $Level, $Component) }

# ---- window ----------------------------------------------------------------------------------
$xaml = ConvertTo-WinUtilRedesignInterface -Xaml (Get-Content (Join-Path $repoRoot 'xaml\inputXML.xaml') -Raw)
$form = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$sync.Form = $form
foreach ($set in 'shared', 'Dark') {
    foreach ($property in $sync.configs.themes.$set.PSObject.Properties) {
        $value = $property.Value
        $name = $property.Name
        # Same mapping as Invoke-WinutilThemeChange
        $form.Resources[$name] = if ($name -like '*color*') { [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($value)) }
        elseif ($name -like '*Radius*') { [Windows.CornerRadius]::new([double]$value) }
        elseif ($name -like '*RowHeight*') { [Windows.GridLength]::new([double]$value) }
        elseif (($name -like '*Thickness*') -or ($name -like '*margin')) {
            $parts = "$value" -split ','
            switch ($parts.Count) {
                1 { [Windows.Thickness]::new([double]$parts[0]) }
                2 { [Windows.Thickness]::new([double]$parts[0], [double]$parts[1]) }
                4 { [Windows.Thickness]::new([double]$parts[0], [double]$parts[1], [double]$parts[2], [double]$parts[3]) }
            }
        }
        elseif ($name -like '*FontFamily*') { [Windows.Media.FontFamily]::new($value) }
        else { [double]$value }
    }
}
foreach ($name in 'BorderColor', 'ButtonBackgroundMouseoverColor') {
    $form.Resources["C$name"] = [Windows.Media.ColorConverter]::ConvertFromString($sync.configs.themes.Dark.$name)
}
([xml]$xaml).SelectNodes('//*[@Name]') | ForEach-Object { $sync[$_.GetAttribute('Name')] = $form.FindName($_.GetAttribute('Name')) }
$form.FindName('WPFTabNav').SelectedIndex = 1
$sync.WPFTab2BT.IsChecked = $true

function Sync-UI {
    $form.Content.UpdateLayout()
    [Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)
    $form.Content.UpdateLayout()
}
function Save-Render([string]$Name) {
    if (-not $RenderDir) { return }
    $width = 1280; $height = 820
    Sync-UI
    $root = $form.Content
    $root.Measure([Windows.Size]::new($width, $height)); $root.Arrange([Windows.Rect]::new(0, 0, $width, $height)); $root.UpdateLayout()
    $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new($width, $height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $background = [Windows.Shapes.Rectangle]::new(); $background.Width = $width; $background.Height = $height
    $background.Fill = [Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromRgb(10, 15, 28))
    $background.Measure([Windows.Size]::new($width, $height)); $background.Arrange([Windows.Rect]::new(0, 0, $width, $height))
    $bitmap.Render($background); $bitmap.Render($root)
    $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Create((Join-Path $RenderDir "$Name.png")); $encoder.Save($stream); $stream.Close()
}

$results = [ordered]@{}
function Check([string]$What, $Condition) {
    $results[$What] = [bool]$Condition
    '{0} {1}' -f $(if ($Condition) { 'PASS' } else { 'FAIL' }), $What
}
function VisibleCards { @($sync.RedesignCards.GetEnumerator() | Where-Object { $_.Value.Root.Visibility -eq 'Visible' }) }

# ---- 1. open the Tweaks tab -----------------------------------------------------------------
$sync.preferences.language = 'it'
Initialize-WinUtilTabContent -TabName 'Tweaks'
Check 'shell wired' $sync.RedesignShellReady
Check 'one card per checkbox tweak' ($sync.RedesignCards.Count -eq @($sync.RedesignItems).Count -and $sync.RedesignCards.Count -gt 0)
Check 'card checkboxes registered in $sync under the tweak key' (@($sync.RedesignCards.Keys | Where-Object { $sync[$_] -is [Windows.Controls.CheckBox] -and $sync[$_].Name -eq $_ }).Count -eq $sync.RedesignCards.Count)
Check 'recommended chip shows only the Standard preset tweaks' ((VisibleCards).Count -eq @($sync.configs.preset.Standard).Count)
Check 'apply disabled with nothing selected' (-not $sync.WPFTweaksbutton.IsEnabled)
Check 'page title is Italian' ($sync.WPFRedesignPageTitle.Text -eq 'Ottimizzazioni')
Save-Render 'rt-1-it-initial'

# ---- 2. select through the real checkboxes ---------------------------------------------------
$sync['WPFTweaksTelemetry'].IsChecked = $true
$sync['WPFTweaksServices'].IsChecked = $true
$sync['WPFTweaksBraveDebloat'].IsChecked = $true
Check 'selectedTweaks updated by the upstream handler' (($sync.selectedTweaks -contains 'WPFTweaksTelemetry') -and $sync.selectedTweaks.Count -eq 3)
Check 'apply enabled and labelled with the count' ($sync.WPFTweaksbutton.IsEnabled -and $sync.WPFTweaksbutton.Content -eq 'Applica 3 modifiche')
Check 'selection line' ($sync.WPFRedesignSelCount.Text -eq '3 modifiche selezionate')
Set-WinUtilRedesignFocus -Name 'WPFTweaksServices'
Check 'focus on a caution tweak shows the warning box' ($sync.WPFRedesignWarnBox.Visibility -eq 'Visible' -and $sync.WPFRedesignSafeBox.Visibility -eq 'Collapsed')
Check 'impact bars appear when the selection has the data' ($sync.WPFRedesignBar1Row.Visibility -eq 'Visible' -and $sync.WPFRedesignBar2Row.Visibility -eq 'Visible')
Save-Render 'rt-2-it-selected-focus'

# ---- 3. filter, language, search -------------------------------------------------------------
Set-WinUtilRedesignFilter -Filter 'advanced'
Check 'advanced chip lists the advanced tweaks only' ((VisibleCards).Count -eq @($sync.RedesignItems | Where-Object { $_.Category -eq 'advanced' }).Count)
Save-Render 'rt-3-it-advanced'
Set-WinUtilRedesignLanguage -Toggle
Check 'language switched to English' ($sync.preferences.language -eq 'en' -and $sync.WPFRedesignPageTitle.Text -eq 'Tweaks')
Check 'apply label follows the language' ($sync.WPFTweaksbutton.Content -eq 'Apply 3 changes')
Check 'card text follows the language' ($sync.RedesignCards['WPFTweaksTelemetry'].Title.Text -eq 'Telemetry')
Update-WinUtilRedesignFilter -SearchString 'onedrive'
Check 'search finds a card whatever the chip' ($sync.RedesignCards['WPFTweaksRemoveOneDrive'].Root.Visibility -eq 'Visible')
Save-Render 'rt-4-en-search'
Update-WinUtilRedesignFilter -SearchString 'zzzz-no-match'
Check 'no-results message' ($sync.WPFRedesignNoResults.Visibility -eq 'Visible')
Update-WinUtilRedesignFilter -SearchString ''
Set-WinUtilRedesignFilter -Filter 'rec'

# ---- 4. clear --------------------------------------------------------------------------------
foreach ($key in @($sync.selectedTweaks)) { $sync[$key].IsChecked = $false }
Check 'clearing the selection disables apply' ((-not $sync.WPFTweaksbutton.IsEnabled) -and $sync.selectedTweaks.Count -eq 0)

# ---- 5. progress panel (what Step-WinUtilJob does to the upstream controls) -------------------
$sync['WPFTweaksTelemetry'].IsChecked = $true
$sync.WPFTweaksProgressBar.Visibility = [Windows.Visibility]::Visible
$sync.WPFTweaksProgressLabel.Text = 'Applying (1/2)'
$sync.WPFTweaksProgressValue.Value = 45
Sync-UI
Check 'actions are replaced by the progress while a job runs' ($sync.WPFRedesignActions.Visibility -eq 'Collapsed' -and $sync.WPFRedesignProgress.Visibility -eq 'Visible')
Check 'new-selection button and done note wait for 100%' ($sync.WPFRedesignNewSelection.Visibility -eq 'Collapsed' -and $sync.WPFRedesignDoneNote.Visibility -eq 'Collapsed')
Save-Render 'rt-5-progress'
$sync.WPFTweaksProgressValue.Value = 100
Sync-UI
Check 'new-selection button and done note appear at 100%' ($sync.WPFRedesignNewSelection.Visibility -eq 'Visible' -and $sync.WPFRedesignDoneNote.Visibility -eq 'Visible')
$sync.WPFTweaksProgressBar.Visibility = [Windows.Visibility]::Collapsed
$sync.WPFTweaksProgressValue.Value = 0
Sync-UI
Check 'actions come back when upstream hides the bar' ($sync.WPFRedesignActions.Visibility -eq 'Visible')
$sync['WPFTweaksTelemetry'].IsChecked = $false

# ---- 6. other tabs ---------------------------------------------------------------------------
$sync.currentTab = 'Updates'
Initialize-WinUtilTabContent -TabName 'Updates'
Check 'other tabs use the sidebar text as the page title' ($sync.WPFRedesignPageTitle.Text -eq 'Updates')
$sync.WPFTabNav.SelectedIndex = 3
Sync-UI
Check 'right panel is hidden on other tabs' ($sync.WPFRedesignRightPanel.Visibility -eq 'Collapsed')
$barHost = $sync.WPFTweaksProgressBar.Parent
Check 'window-level progress is shown on other tabs only' ($barHost.Visibility -eq 'Visible')
$sync.WPFTabNav.SelectedIndex = 1
Sync-UI
Check 'window-level progress is hidden on the Tweaks tab' ($barHost.Visibility -eq 'Collapsed')

# ---- 7. font scaling reaches the redesign's sizes --------------------------------------------
$sync.currentTab = 'Tweaks'
Invoke-WinUtilFontScaling -ScaleFactor 1.5
Check 'upstream sizes scale' ($form.Resources['FontSize'] -eq 21)
Check 'redesign sizes scale' ($form.Resources['RdFontBody'] -eq 21 -and $form.Resources['RdFontPage'] -eq 60)
Save-Render 'rt-6-scaled-150'
Invoke-WinUtilFontScaling -ScaleFactor 1.0
Check 'scaling back to 100% restores them' ($form.Resources['RdFontBody'] -eq 14 -and $form.Resources['RdIconXL'] -eq 26)
Invoke-WinUtilFontScaling -ScaleFactor 9 3>$null
Check 'an out-of-range factor falls back to 100%' ($form.Resources['RdFontBody'] -eq 14)

$failed = @($results.GetEnumerator() | Where-Object { -not $_.Value })
"`n$($results.Count - $failed.Count)/$($results.Count) checks passed"
if ($failed.Count -gt 0) { exit 1 }
