function Export-WinUtilKit {
    <#
    .SYNOPSIS
        Writes a kit to a .winutil-kit.json file that another PC can import.

    .DESCRIPTION
        The file holds package IDs (see Get-WinUtilKitPackageId), not display names. Applications
        without any ID cannot be described and are left out. The folder may be a network share;
        it has to exist.

    .PARAMETER Kit
        A kit of Get-WinUtilKits.

    .PARAMETER Path
        Where to write the file.

    .OUTPUTS
        The path written.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        $Kit,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $ids = @(foreach ($key in $Kit.AppKeys) {
        $app = $sync.configs.applicationsHashtable[$key]
        if ($app) {
            Get-WinUtilKitPackageId -App $app
        }
    }) | Where-Object { $_ }

    $payload = [ordered]@{
        formato     = 'winutil-kit'
        versione    = 1
        nome        = [string]$Kit.Name
        descrizione = [string]$Kit.Description
        programmi   = @($ids)
    }
    $json = ConvertTo-Json -InputObject $payload -Depth 4

    $folder = Split-Path -Parent $Path
    if ($folder -and -not (Test-Path -LiteralPath $folder -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new("The folder '$folder' does not exist.")
    }
    # UTF-8 without a byte order mark: Windows PowerShell 5.1 would add one with -Encoding UTF8
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    return $Path
}
