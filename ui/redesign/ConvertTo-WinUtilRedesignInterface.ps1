function ConvertTo-WinUtilRedesignInterface {
    <#
    .SYNOPSIS
        Builds the optional "design D" WPF interface at compile time.

    .DESCRIPTION
        Takes the upstream xaml/inputXML.xaml and returns the XAML for the redesigned window.
        Upstream sources are never edited: every named control the existing functions rely on
        is kept, and only the window chrome and the Tweaks tab content are replaced.
        Throws when the upstream XAML no longer has the controls this adapter depends on, so a
        change upstream fails the build instead of producing a half-working window.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Xaml
    )

    $document = [xml]$Xaml
    $required = @('WPFMainGrid', 'NavDockPanel', 'GridBesideNavDockPanel', 'WPFTabNav', 'WPFTab2', 'WPFTweaksProgressBar')
    foreach ($name in $required) {
        if (-not $document.SelectSingleNode("//*[@Name='$name']")) {
            throw "Upstream XAML contract changed: the redesign adapter requires the control '$name'."
        }
    }

    $document.OuterXml
}
