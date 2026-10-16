function Remove-WinUtilKit {
    <#
    .SYNOPSIS
        Deletes a custom kit from %APPDATA%\WinUtil\kits.

    .DESCRIPTION
        Only files inside that folder are deleted, so a kit object cannot be used to remove
        something somewhere else.

    .PARAMETER Kit
        A custom kit of Get-WinUtilKits.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Kit
    )

    if (-not $Kit.Custom -or -not $Kit.Path) {
        throw 'Only a custom kit can be removed.'
    }
    $folder = [System.IO.Path]::GetFullPath((Get-WinUtilKitFolder)).TrimEnd('\') + '\'
    $full = [System.IO.Path]::GetFullPath($Kit.Path)
    if (-not $full.StartsWith($folder, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The kit '$($Kit.Name)' is not in the kits folder."
    }
    Remove-Item -LiteralPath $full -Force -ErrorAction Stop
}
