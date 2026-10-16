function Resolve-WinUtilKitApps {
    <#
    .SYNOPSIS
        Turns package IDs into the application keys of the catalog, and counts the ones it does not have.

    .DESCRIPTION
        An ID matches the WinGet or the Chocolatey ID of a catalog entry, ignoring case. IDs the
        catalog does not know are skipped, not an error: a kit made on a PC with a newer catalog
        still works on this one. Two IDs for the same application count once.

    .PARAMETER PackageIds
        The IDs as stored in a kit file.

    .OUTPUTS
        An object with AppKeys (catalog keys, in the order of the IDs) and Skipped (a count).
    #>
    [CmdletBinding()]
    param(
        [string[]]$PackageIds = @()
    )

    $index = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    $apps = $sync.configs.applicationsHashtable
    foreach ($key in ($apps.Keys | Sort-Object)) {
        foreach ($field in 'winget', 'choco') {
            $id = ([string]$apps[$key].$field).Trim()
            if ($id -and $id -ne 'na' -and -not $index.ContainsKey($id)) {
                $index[$id] = $key
            }
        }
    }

    $keys = [System.Collections.Generic.List[string]]::new()
    $skipped = 0
    foreach ($id in $PackageIds) {
        $lookup = ([string]$id).Trim()
        $key = $null
        if ($lookup -and $index.TryGetValue($lookup, [ref]$key)) {
            if (-not $keys.Contains($key)) {
                $keys.Add($key)
            }
        } else {
            $skipped++
        }
    }

    return [pscustomobject]@{
        AppKeys = [string[]]$keys.ToArray()
        Skipped = $skipped
    }
}
