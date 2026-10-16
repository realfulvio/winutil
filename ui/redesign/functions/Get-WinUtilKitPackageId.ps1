function Get-WinUtilKitPackageId {
    <#
    .SYNOPSIS
        Returns the package manager ID a kit file stores for an application.

    .DESCRIPTION
        Kit files hold IDs, never display names, so they mean the same thing on every PC. The
        WinGet ID is used when the application has one and the Chocolatey ID otherwise. The value
        is the one in config/applications.json, unchanged (a Microsoft Store entry keeps its
        "msstore:" prefix), so importing it back is an exact match.

    .PARAMETER App
        An entry of $sync.configs.applicationsHashtable.

    .OUTPUTS
        The ID, or $null when the application has neither.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $App
    )

    foreach ($field in 'winget', 'choco') {
        $id = ([string]$App.$field).Trim()
        if ($id -and $id -ne 'na') {
            return $id
        }
    }
    return $null
}
