function Find-TweaksByNameOrDescription {
    <#
    .SYNOPSIS
        Search entry point shared with upstream: cards on the Tweaks tab, upstream panels elsewhere.

    .DESCRIPTION
        The upstream function is renamed to Find-TweaksByNameOrDescriptionUpstream when the
        redesign is compiled (see Convert-WinUtilRedesignFunctionSource) and still serves the
        AppX tab.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$SearchString = ""
    )

    if ($sync.currentTab -eq "Tweaks") {
        Update-WinUtilRedesignFilter -SearchString $SearchString
        return
    }
    Find-TweaksByNameOrDescriptionUpstream -SearchString $SearchString
}
