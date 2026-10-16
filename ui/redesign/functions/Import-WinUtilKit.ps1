function Import-WinUtilKit {
    <#
    .SYNOPSIS
        Reads a kit file and matches its programs against the catalog.

    .DESCRIPTION
        Does not save anything: the caller decides what to do with the kit. Programs the catalog
        does not have are skipped and counted in Skipped. Throws what Read-WinUtilKitFile throws,
        and an InvalidDataException with KitError "Empty" when not one program is in the catalog.

    .PARAMETER Path
        The .winutil-kit.json file.

    .OUTPUTS
        A kit object: Name, Description, Color, AppKeys, Skipped.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $file = Read-WinUtilKitFile -Path $Path
    $resolved = Resolve-WinUtilKitApps -PackageIds $file.PackageIds
    if ($resolved.AppKeys.Count -eq 0) {
        $exception = [System.IO.InvalidDataException]::new("None of the programs of '$Path' is in the catalog.")
        $exception.Data['KitError'] = 'Empty'
        throw $exception
    }

    # A kit without a color gets a stable one from its name, so it looks the same every time
    $color = $file.Color
    if ($null -eq $color) {
        $sum = 0
        foreach ($character in $file.Name.ToCharArray()) { $sum += [int]$character }
        $color = $sum % 5
    }

    return [pscustomobject]@{
        Name        = $file.Name
        Description = $file.Description
        Color       = [int]$color
        AppKeys     = $resolved.AppKeys
        Skipped     = $resolved.Skipped
    }
}
