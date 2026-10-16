function Invoke-WinUtilKitHeadless {
    <#
    .SYNOPSIS
        Installs a kit without a window: winutil.ps1 -Kit "path\kit.winutil-kit.json" -Installa

    .DESCRIPTION
        Reads the kit, matches its package IDs against the catalog, selects those programs and
        runs the same install job the window starts, one program at a time, to the end. Without
        -Installa it only says what the kit holds and installs nothing. Messages are in the
        language of Windows (Italian or English).

        Returns the exit code of the run: 0 for success, 1 for a bad kit or an installation with
        problems, 2 when -Installa came without a kit.

    .PARAMETER Path
        The .winutil-kit.json file. A network path is fine.

    .PARAMETER Install
        Install the programs. Without it nothing is changed.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$Path,

        [switch]$Install
    )

    if (-not $sync.preferences.language) {
        $sync.preferences.language = if ((Get-UICulture).TwoLetterISOLanguageName -eq 'it') { 'it' } else { 'en' }
    }

    if (-not $Path) {
        Write-Host (Get-WinUtilRedesignText -Key 'cliNeedsKit') -ForegroundColor Red
        return 2
    }

    try {
        $kit = Import-WinUtilKit -Path $Path
    } catch {
        $code = $_.Exception.Data['KitError']
        $reason = if ($code) { Get-WinUtilRedesignText -Key "kitErr$code" } else { $_.Exception.Message }
        Write-WinUtilLog -Level 'ERROR' -Component 'Kits' -Message "Kit '$Path' could not be used: $($_.Exception.Message)"
        Write-Host (Get-WinUtilRedesignText -Key 'cliKitError' -FormatArgs @($reason)) -ForegroundColor Red
        return 1
    }

    Write-Host (Get-WinUtilRedesignText -Key 'cliKitHeader' -FormatArgs @($kit.Name, $kit.AppKeys.Count)) -ForegroundColor Cyan
    foreach ($key in $kit.AppKeys) {
        $app = $sync.configs.applicationsHashtable[$key]
        Write-Host ("  {0}  ({1})" -f $app.content, (Get-WinUtilKitPackageId -App $app))
    }
    if ($kit.Skipped -gt 0) {
        Write-Host (Get-WinUtilRedesignText -Key 'cliKitSkipped' -FormatArgs @($kit.Skipped)) -ForegroundColor Yellow
        Write-WinUtilLog -Level 'WARN' -Component 'Kits' -Message "Kit '$($kit.Name)': $($kit.Skipped) program(s) are not in the catalog and were skipped."
    }

    if (-not $Install) {
        Write-Host (Get-WinUtilRedesignText -Key 'cliKitDry')
        return 0
    }

    Write-WinUtilLog -Component 'Kits' -Message "Installing the kit '$($kit.Name)' from '$Path' ($($kit.AppKeys.Count) program(s))."
    $null = Update-WinUtilSelections -flatJson $kit.AppKeys -Replace
    $summary = Invoke-WinUtilAutoRun
    return (Write-WinUtilAutoRunSummary -Summary $summary)
}
