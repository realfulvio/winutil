function Get-WinUtilRedesignIconSpec {
    <#
    .SYNOPSIS
        Decides how a program's tile is drawn when there is no downloaded icon (yet).

    .DESCRIPTION
        A program with a Simple Icons outline (see docs/ICONS.md) gets a tile in the color of its
        brand with the outline in white. A brand that is nearly black gets a dark neutral tile
        instead, so the white outline stays readable. Every other program gets the glyph of its
        category on the category's color.

    .PARAMETER Item
        An entry of Get-WinUtilRedesignProgramItems.

    .OUTPUTS
        An object with Kind ("brand" or "category"), From and To (#RRGGBB), Path (the outline,
        for a brand) and Glyph (four hex digits, for a category).
    #>
    param(
        [Parameter(Mandatory)]
        $Item
    )

    if ($null -eq $sync.RedesignIconSpecs) {
        $sync.RedesignIconSpecs = @{}
    }
    if ($sync.RedesignIconSpecs.ContainsKey($Item.Key)) {
        return $sync.RedesignIconSpecs[$Item.Key]
    }

    $spec = $null
    $icon = if ($Item.Slug) { $sync.configs.redesignicons.($Item.Slug) } else { $null }
    if ($icon) {
        $red = [Convert]::ToInt32($icon.hex.Substring(0, 2), 16)
        $green = [Convert]::ToInt32($icon.hex.Substring(2, 2), 16)
        $blue = [Convert]::ToInt32($icon.hex.Substring(4, 2), 16)
        $luminance = $red * 0.3 + $green * 0.6 + $blue * 0.1
        if ($luminance -lt 70) {
            $from = '#3A4256'
            $to = '#1A1F2C'
        } else {
            $from = '#' + $icon.hex
            $to = '#{0:X2}{1:X2}{2:X2}' -f [int][Math]::Round($red * 0.72), [int][Math]::Round($green * 0.72), [int][Math]::Round($blue * 0.72)
        }
        $spec = [pscustomobject]@{ Kind = 'brand'; From = $from; To = $to; Path = [string]$icon.path; Glyph = $null }
    } else {
        $category = $sync.configs.redesignprograms.categories.($Item.Category)
        $spec = [pscustomobject]@{
            Kind  = 'category'
            From  = if ($category) { [string]$category.from } else { '#5B6B86' }
            To    = if ($category) { [string]$category.to } else { '#2D384D' }
            Path  = $null
            Glyph = if ($category) { [string]$category.glyph } else { 'E74C' }
        }
    }

    $sync.RedesignIconSpecs[$Item.Key] = $spec
    return $spec
}

function New-WinUtilRedesignGradient {
    <#
    .SYNOPSIS
        Returns a frozen diagonal gradient brush between two #RRGGBB colors, cached.

    .PARAMETER From
        The color at the top left.

    .PARAMETER To
        The color at the bottom right.
    #>
    param(
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To
    )

    if ($null -eq $sync.RedesignGradients) {
        $sync.RedesignGradients = @{}
    }
    $cacheKey = "$From|$To"
    if ($sync.RedesignGradients.ContainsKey($cacheKey)) {
        return $sync.RedesignGradients[$cacheKey]
    }

    $brush = [Windows.Media.LinearGradientBrush]::new()
    $brush.StartPoint = [Windows.Point]::new(0, 0)
    $brush.EndPoint = [Windows.Point]::new(1, 1)
    $null = $brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($From), 0))
    $null = $brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($To), 1))
    $brush.Freeze()
    $sync.RedesignGradients[$cacheKey] = $brush
    return $brush
}
