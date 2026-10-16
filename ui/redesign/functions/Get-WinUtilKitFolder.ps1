function Get-WinUtilKitFolder {
    <#
    .SYNOPSIS
        Returns the folder that holds the user's own kits: %APPDATA%\WinUtil\kits.

    .PARAMETER Create
        Creates the folder when it does not exist.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$Create
    )

    $folder = Join-Path (Join-Path $env:APPDATA 'WinUtil') 'kits'
    if ($Create -and -not (Test-Path -LiteralPath $folder)) {
        $null = New-Item -ItemType Directory -Path $folder -Force
    }
    return $folder
}
