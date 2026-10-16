function Invoke-WPFTab {
    <#
    .SYNOPSIS
        Opens a tab. The first one opened when the window starts is Home.

    .DESCRIPTION
        The upstream function is renamed to Invoke-WPFTabUpstream when the redesign is compiled
        (see Convert-WinUtilRedesignFunctionSource) and does all the work. Upstream starts on the
        Install tab and says so with -Yield; the redesign starts on Home instead. Every later
        request, from the sidebar, the Home cards or the keyboard, is passed on unchanged.

    .PARAMETER ClickedTab
        The name of the tab button, for example WPFTab1BT.

    .PARAMETER Yield
        Build the tab's content in slices, letting the interface answer between them.
    #>
    Param (
        [Parameter(Mandatory, position = 0)]
        [string]$ClickedTab,

        [switch]$Yield
    )

    if ($Yield -and $ClickedTab -eq "WPFTab1BT" -and -not $sync.RedesignStarted) {
        $ClickedTab = "WPFTab7BT"
    }
    $sync.RedesignStarted = $true

    Invoke-WPFTabUpstream -ClickedTab $ClickedTab -Yield:$Yield
}
