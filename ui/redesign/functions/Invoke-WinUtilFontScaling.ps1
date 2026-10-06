function Invoke-WinUtilFontScaling {
    <#
    .SYNOPSIS
        Applies UI and font scaling for accessibility, including the redesign's own sizes.

    .DESCRIPTION
        The upstream function is renamed to Invoke-WinUtilFontScalingUpstream when the redesign is
        compiled (see Convert-WinUtilRedesignFunctionSource). It scales a fixed list of theme
        resources, so the font and icon sizes the redesign adds (the Rd* resources of
        ui/redesign/tokens.json) are scaled here with the same factor.

    .PARAMETER ScaleFactor
        Sets the scaling from 0.75 and 2.0. Default is 1.0 (100%, no scaling).
    #>
    param(
        [double]$ScaleFactor = 1.0
    )

    Invoke-WinUtilFontScalingUpstream -ScaleFactor $ScaleFactor

    # Upstream stores the factor it actually used, which is 1.0 when the one given was out of range
    $factor = if ($sync.FontScaleFactor) { [double]$sync.FontScaleFactor } else { 1.0 }
    foreach ($property in $sync.configs.themes.shared.PSObject.Properties) {
        if ($property.Name -like "Rd*") {
            $sync.Form.Resources[$property.Name] = [math]::Round([double]$property.Value * $factor, 1)
        }
    }
}
