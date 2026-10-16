function Save-WinUtilKit {
    <#
    .SYNOPSIS
        Stores a custom kit in %APPDATA%\WinUtil\kits.

    .DESCRIPTION
        The file is a kit file (see Read-WinUtilKitFile) with the kit's color added. A kit with
        the same name replaces the one that was saved before; a different name that happens to
        give the same file name gets a number after it.

    .PARAMETER Name
        Required.

    .PARAMETER Description
        Optional.

    .PARAMETER Color
        0 to 4, the swatch the kit is drawn with.

    .PARAMETER AppKeys
        Catalog keys of the programs in the kit.

    .OUTPUTS
        The kit as Get-WinUtilKits returns it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Description = '',

        [ValidateRange(0, 4)]
        [int]$Color = 0,

        [Parameter(Mandatory)]
        [string[]]$AppKeys
    )

    $cleanName = $Name.Trim()
    if (-not $cleanName) {
        $exception = [System.IO.InvalidDataException]::new('A kit needs a name.')
        $exception.Data['KitError'] = 'NoName'
        throw $exception
    }

    $ids = @(foreach ($key in $AppKeys) {
        $app = $sync.configs.applicationsHashtable[$key]
        if ($app) {
            Get-WinUtilKitPackageId -App $app
        }
    }) | Where-Object { $_ }
    if (@($ids).Count -eq 0) {
        $exception = [System.IO.InvalidDataException]::new('A kit needs at least one program.')
        $exception.Data['KitError'] = 'NoPrograms'
        throw $exception
    }

    $folder = Get-WinUtilKitFolder -Create
    $stem = (($cleanName -replace '[^\p{L}\p{N}]+', '-').Trim('-')).ToLowerInvariant()
    if (-not $stem) { $stem = 'kit' }
    if ($stem.Length -gt 60) { $stem = $stem.Substring(0, 60).Trim('-') }

    $path = Join-Path $folder "$stem.json"
    $suffix = 2
    while (Test-Path -LiteralPath $path) {
        $existing = $null
        try { $existing = Read-WinUtilKitFile -Path $path } catch { $existing = $null }
        if ($null -eq $existing -or $existing.Name -eq $cleanName) {
            # The same kit saved again, or a file that is not a readable kit: either way it is ours to replace
            break
        }
        $path = Join-Path $folder "$stem-$suffix.json"
        $suffix++
    }

    $payload = [ordered]@{
        formato     = 'winutil-kit'
        versione    = 1
        nome        = $cleanName
        descrizione = $Description.Trim()
        colore      = $Color
        programmi   = @($ids)
    }
    [System.IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $payload -Depth 4), [System.Text.UTF8Encoding]::new($false))

    return Get-WinUtilKits | Where-Object { $_.Custom -and $_.Path -eq $path } | Select-Object -First 1
}
