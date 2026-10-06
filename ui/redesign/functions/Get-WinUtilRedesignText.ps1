function Get-WinUtilRedesignText {
    <#
    .SYNOPSIS
        Returns a string of the redesigned interface in the current language.

    .DESCRIPTION
        Every label of the redesign comes from ui/redesign/strings.json (embedded as
        $sync.configs.redesignstrings), so no text is written in the code. A key missing in the
        current language falls back to English, and a key missing everywhere returns the key.

    .PARAMETER Key
        The key under "ui" in strings.json.

    .PARAMETER FormatArgs
        Values for the {0}, {1} placeholders of the string.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [object[]]$FormatArgs = @()
    )

    $language = $sync.preferences.language
    if (-not $language) {
        $language = "en"
    }

    $strings = $sync.configs.redesignstrings.ui
    $text = $strings.$language.$Key
    if ($null -eq $text) {
        $text = $strings.en.$Key
    }
    if ($null -eq $text) {
        return $Key
    }
    if ($text -is [string] -and $FormatArgs.Count -gt 0) {
        return ($text -f $FormatArgs)
    }
    return $text
}
