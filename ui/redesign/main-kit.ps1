#===========================================================================
# Kit mode (redesign build): -Kit <file> [-Installa] runs without a window
#===========================================================================
#
# Added to scripts/main.ps1 by ConvertTo-WinUtilRedesignKitMode when the redesign is compiled,
# in front of the part that starts the interface. It follows the headless -Preset / -Config path.

if ($Kit -or $Installa) {
    $kitExitCode = 1
    try {
        Initialize-WinUtilRunspacePool | Out-Null
        $kitExitCode = Invoke-WinUtilKitHeadless -Path $Kit -Install:$Installa
    } catch {
        Write-WinUtilErrorRecord -ErrorRecord $_ -Component "Kits" -Context "Kit run"
        Write-Host "WinUtil could not complete the kit run: $($_.Exception.Message)" -ForegroundColor Red
        $kitExitCode = 1
    } finally {
        Close-WinUtilRunspacePool
        [System.GC]::Collect()
        Remove-WinUtilTempScript
        Stop-Transcript | Out-Null
    }

    if ($env:WINUTIL_HEADLESS_CHILD -eq "1" -or $script:WinUtilIsFileProcess) {
        exit $kitExitCode
    }
    $global:LASTEXITCODE = $kitExitCode
    return $kitExitCode
}

