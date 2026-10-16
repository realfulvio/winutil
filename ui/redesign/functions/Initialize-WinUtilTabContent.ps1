function Initialize-WinUtilTabContent {
    <#
    .SYNOPSIS
        Builds a tab's content, with the redesigned Programs and Tweaks tabs in place of upstream's.

    .DESCRIPTION
        The upstream function is renamed to Initialize-WinUtilTabContentUpstream when the redesign
        is compiled (see Convert-WinUtilRedesignFunctionSource) and still builds every other tab.
        This wrapper also makes sure the window's own controls are wired, and refreshes the page
        title for the tab that is open. Home has nothing to build: it is static.

    .PARAMETER TabName
        Install, Tweaks, Config, Updates, Win11ISO, AppX or Home.

    .PARAMETER Yield
        Build in batches, letting the interface answer in between.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TabName,

        [switch]$Yield
    )

    Initialize-WinUtilRedesignShell
    Update-WinUtilRedesignPageHeader

    if ($TabName -eq "Home") {
        return
    }
    if ($TabName -notin "Tweaks", "Install") {
        Initialize-WinUtilTabContentUpstream -TabName $TabName -Yield:$Yield
        return
    }

    if ($null -eq $sync.InitializedTabs) {
        $sync.InitializedTabs = @{}
    }
    if ($sync.InitializedTabs[$TabName]) {
        return
    }

    # Claimed before building, as upstream does, so a click during a yielding build cannot start a second one
    $sync.InitializedTabs[$TabName] = $true
    try {
        if ($TabName -eq "Install") {
            Initialize-WinUtilRedesignPrograms -Yield:$Yield
        } else {
            Initialize-WinUtilRedesignTweaks -Yield:$Yield
        }
        # Cards start unchecked, so anything chosen by an import or a preset is applied to them now
        Reset-WPFCheckBoxes -doToggles $true
    } catch {
        $sync.InitializedTabs[$TabName] = $false
        throw
    }
}
