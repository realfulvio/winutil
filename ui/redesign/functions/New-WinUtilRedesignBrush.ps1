function New-WinUtilRedesignBrush {
    <#
    .SYNOPSIS
        Returns a frozen solid brush for a #RRGGBB (or #AARRGGBB) color.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Color
    )

    $brush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($Color))
    $brush.Freeze()
    return $brush
}
