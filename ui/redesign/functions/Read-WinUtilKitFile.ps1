function Read-WinUtilKitFile {
    <#
    .SYNOPSIS
        Reads and validates a kit file (.winutil-kit.json).

    .DESCRIPTION
        The format is {"formato":"winutil-kit","versione":1,"nome":"","descrizione":"","programmi":["<package ID>", ...]}.
        Throws an InvalidDataException whose Data["KitError"] says what is wrong, so the caller can
        word it in the language of the interface: NotFound, InvalidJson, BadFormat, BadVersion,
        NoName or NoPrograms. A "colore" field (0 to 4) is read when there is one; WinUtil writes it
        into the kits it keeps in its own folder, and other files do not need it.

    .PARAMETER Path
        The file to read.

    .OUTPUTS
        An object with Name, Description, PackageIds and Color (or $null when the file has none).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    function New-KitError([string]$Code, [string]$Message) {
        $exception = [System.IO.InvalidDataException]::new($Message)
        $exception.Data['KitError'] = $Code
        return $exception
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw (New-KitError 'NotFound' "The kit file '$Path' does not exist.")
    }

    try {
        $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        # Windows PowerShell 5.1 answers an empty text with nothing instead of an error
        if ([string]::IsNullOrWhiteSpace($text)) { throw 'empty' }
        $kit = $text | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw (New-KitError 'InvalidJson' "The file '$Path' is not valid JSON.")
    }

    if ($null -eq $kit -or $kit -isnot [pscustomobject] -or $kit.formato -ne 'winutil-kit') {
        throw (New-KitError 'BadFormat' "The file '$Path' is not a WinUtil kit.")
    }
    $version = 0
    if (-not [int]::TryParse([string]$kit.versione, [ref]$version) -or $version -ne 1) {
        throw (New-KitError 'BadVersion' "The kit file '$Path' has an unsupported version ('$($kit.versione)').")
    }
    $name = ([string]$kit.nome).Trim()
    if (-not $name) {
        throw (New-KitError 'NoName' "The kit file '$Path' has no name.")
    }
    $programs = $kit.programmi
    if ($programs -isnot [System.Array] -or $programs.Count -eq 0) {
        throw (New-KitError 'NoPrograms' "The kit file '$Path' lists no programs.")
    }
    foreach ($program in $programs) {
        if ($program -isnot [string] -or [string]::IsNullOrWhiteSpace($program)) {
            throw (New-KitError 'BadFormat' "The kit file '$Path' has a program entry that is not an ID.")
        }
    }

    $color = $null
    $parsedColor = 0
    if ($null -ne $kit.colore -and [int]::TryParse([string]$kit.colore, [ref]$parsedColor) -and $parsedColor -ge 0 -and $parsedColor -le 4) {
        $color = $parsedColor
    }

    return [pscustomobject]@{
        Name        = $name
        Description = ([string]$kit.descrizione).Trim()
        PackageIds  = [string[]]@($programs | ForEach-Object { $_.Trim() })
        Color       = $color
    }
}
