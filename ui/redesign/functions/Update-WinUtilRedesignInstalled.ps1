function Get-WinUtilRedesignBackgroundPool {
    <#
    .SYNOPSIS
        The small worker pool the redesign uses for reading the system and downloading icons.

    .DESCRIPTION
        Kept apart from the pool jobs run on: an install never waits for an icon, closing the
        window never waits for a download, and the workers are background threads that end with
        the process. Created on first use with the same functions and variables every WinUtil
        runspace has.
    #>

    if (-not $sync.RedesignBgPool) {
        $pool = [runspacefactory]::CreateRunspacePool(1, 5, (New-WinUtilSessionState), $Host)
        $pool.ApartmentState = 'MTA'
        $pool.Open()
        $sync.RedesignBgPool = $pool
    }
    return $sync.RedesignBgPool
}

function Update-WinUtilRedesignInstalled {
    <#
    .SYNOPSIS
        Finds out, in the background, which programs of the catalog are installed.

    .DESCRIPTION
        Asks the package manager that is in use (WinGet or Chocolatey) the same question the
        upstream "Show installed apps" button asks, with upstream's own detection, but does not
        tick anything: the result only marks the cards "Installed" and fills the Installed chip.
        When the package manager is not there yet the answer stays unknown and nothing is claimed.
        Run when the tab is built and after every install, uninstall or upgrade.
    #>

    if ($sync.RedesignInstalledBusy -or -not (Test-WinUtilUIAlive)) {
        return
    }
    $sync.RedesignInstalledBusy = $true

    try {
        $pool = Get-WinUtilRedesignBackgroundPool
        $shell = [powershell]::Create()
        $shell.RunspacePool = $pool
        $body = {
            param($Manager)
            $keys = $null
            try {
                if ($Manager -eq 'Choco') {
                    if (Get-Command choco -ErrorAction SilentlyContinue) {
                        $keys = @(Invoke-WinUtilCurrentSystem -CheckBox choco)
                    }
                } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
                    $keys = @(Invoke-WinUtilCurrentSystem -CheckBox winget)
                }
            } catch {
                $keys = $null
            }
            Invoke-WPFUIThread -Async -Parameters @{ Keys = $keys; Known = ($null -ne $keys) } -ScriptBlock {
                param($Keys, $Known)
                Set-WinUtilRedesignInstalled -Keys $Keys -Known $Known
            }
        }
        $null = $shell.AddScript($body.ToString()).AddArgument([string]$sync.preferences.packagemanager)
        $null = $shell.BeginInvoke()
    } catch {
        $sync.RedesignInstalledBusy = $false
        Write-WinUtilLog -Level 'WARN' -Component 'Programs' -Message "Could not check the installed programs: $($_.Exception.Message)"
    }
}

function Set-WinUtilRedesignInstalled {
    <#
    .SYNOPSIS
        Takes the answer of the background check and refreshes what depends on it.

    .PARAMETER Keys
        The keys of the catalog programs that are installed.

    .PARAMETER Known
        $false when the package manager could not say; the earlier answer, if any, is kept.
    #>
    param(
        [string[]]$Keys = @(),
        [bool]$Known
    )

    $sync.RedesignInstalledBusy = $false
    if ($Known) {
        $sync.RedesignInstalled = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Keys), [StringComparer]::OrdinalIgnoreCase)
        Write-WinUtilLog -Component 'Programs' -Message "Installed programs found: $($sync.RedesignInstalled.Count)."
    }

    foreach ($item in (Get-WinUtilRedesignProgramItems)) {
        $card = $sync.RedesignProgramCards[$item.Key]
        if ($card) {
            Set-WinUtilRedesignCardTexts -Item $item -Card $card
        }
    }
    Update-WinUtilRedesignProgramChipTexts
    Update-WinUtilRedesignProgramFilter
    Update-WinUtilRedesignDrawer
    Update-WinUtilRedesignDock
}
