function Get-WinUtilKits {
    <#
    .SYNOPSIS
        Lists the kits: the ones that come with WinUtil, then the user's own.

    .DESCRIPTION
        The built-in kits are in ui/redesign/programs.json; an application of them that the
        catalog no longer has is left out without a word, and a kit left with nothing is not
        listed. Custom kits are the files of %APPDATA%\WinUtil\kits. A file that cannot be read
        is skipped and logged, so one bad file does not hide the others.

    .PARAMETER Language
        en or it, for the names and descriptions of the built-in kits.

    .OUTPUTS
        Objects with Id, Name, Description, Color, AppKeys, Custom, Path and Skipped.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('en', 'it')]
        [string]$Language = 'en'
    )

    $kits = [System.Collections.Generic.List[object]]::new()
    $apps = $sync.configs.applicationsHashtable

    foreach ($kit in @($sync.configs.redesignprograms.kits)) {
        $keys = @(foreach ($id in $kit.apps) {
            if ($apps.ContainsKey("WPFInstall$id")) { "WPFInstall$id" }
        })
        if ($keys.Count -eq 0) {
            continue
        }
        $name = $kit.name.$Language
        if (-not $name) { $name = $kit.name.en }
        $description = $kit.desc.$Language
        if (-not $description) { $description = $kit.desc.en }
        $kits.Add([pscustomobject]@{
            Id          = [string]$kit.id
            Name        = [string]$name
            Description = [string]$description
            Color       = [int]$kit.color
            AppKeys     = [string[]]$keys
            Custom      = $false
            Path        = $null
            Skipped     = 0
        })
    }

    $folder = Get-WinUtilKitFolder
    if (Test-Path -LiteralPath $folder -PathType Container) {
        $custom = foreach ($file in Get-ChildItem -LiteralPath $folder -Filter '*.json' -File) {
            try {
                $read = Read-WinUtilKitFile -Path $file.FullName
                $resolved = Resolve-WinUtilKitApps -PackageIds $read.PackageIds
                if ($resolved.AppKeys.Count -eq 0) {
                    continue
                }
                $color = $read.Color
                if ($null -eq $color) { $color = 0 }
                [pscustomobject]@{
                    Id          = $file.BaseName
                    Name        = $read.Name
                    Description = $read.Description
                    Color       = [int]$color
                    AppKeys     = $resolved.AppKeys
                    Custom      = $true
                    Path        = $file.FullName
                    Skipped     = $resolved.Skipped
                }
            } catch {
                Write-WinUtilLog -Level 'WARN' -Component 'Kits' -Message "Skipped the kit file '$($file.Name)': $($_.Exception.Message)"
            }
        }
        foreach ($kit in ($custom | Sort-Object Name)) {
            $kits.Add($kit)
        }
    }

    return $kits.ToArray()
}
