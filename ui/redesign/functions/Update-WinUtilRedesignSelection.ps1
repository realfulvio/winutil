function Update-WinUtilRedesignSelection {
    <#
    .SYNOPSIS
        Refreshes everything that depends on which tweaks are selected.

    .DESCRIPTION
        Card borders, the "N changes selected" line, the Apply button (label and enabled state),
        and the estimated impact. The impact is counted from the data of the selected tweaks:
        how many services and registry values they touch, against everything the cards touch.
        A bar is shown only when the selection has that kind of data. Memory, disk space and a
        privacy score are not shown because the repo holds no figure for them.

    .PARAMETER Name
        The tweak that was just checked or unchecked, if any.

    .PARAMETER UserAction
        The change comes from the user's own click, so the tweak is also put in focus.
    #>
    param(
        [string]$Name,
        [switch]$UserAction
    )

    if (-not $sync.RedesignCardsReady) {
        return
    }

    if ($UserAction -and $Name -and $sync.selectedTweaks.Contains($Name)) {
        $sync.RedesignFocus = $Name
        Update-WinUtilRedesignDetails
    }
    Update-WinUtilRedesignCardStates

    $selected = @($sync.selectedTweaks | Where-Object { $sync.RedesignItemsByName.ContainsKey($_) })
    $count = $selected.Count

    if ($count -eq 0) {
        $sync.WPFRedesignSelCount.Text = Get-WinUtilRedesignText -Key "selNone"
    } elseif ($count -eq 1) {
        $sync.WPFRedesignSelCount.Text = Get-WinUtilRedesignText -Key "selOne"
    } else {
        $sync.WPFRedesignSelCount.Text = Get-WinUtilRedesignText -Key "selMany" -FormatArgs @($count)
    }

    # A DNS provider chosen in "Other settings" is applied by the same button
    $dnsList = $sync["WPFchangedns"]
    $dnsChosen = $dnsList -and $dnsList.Text -and $dnsList.Text -ne "Default"
    if ($count -eq 0) {
        $applyKey = if ($dnsChosen) { "applyDns" } else { "applyNone" }
        $sync.WPFTweaksbutton.Content = Get-WinUtilRedesignText -Key $applyKey
    } elseif ($count -eq 1) {
        $sync.WPFTweaksbutton.Content = Get-WinUtilRedesignText -Key "applyOne"
    } else {
        $sync.WPFTweaksbutton.Content = Get-WinUtilRedesignText -Key "applyMany" -FormatArgs @($count)
    }
    $sync.WPFTweaksbutton.IsEnabled = (@($sync.selectedTweaks).Count -gt 0) -or [bool]$dnsChosen

    $services = 0
    $registry = 0
    foreach ($key in $selected) {
        $services += $sync.RedesignItemsByName[$key].Services
        $registry += $sync.RedesignItemsByName[$key].Registry
    }
    $totals = $sync.RedesignTotals
    $showServices = $services -gt 0
    $showRegistry = $registry -gt 0

    $sync.WPFRedesignBar1Row.Visibility = if ($showServices) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $sync.WPFRedesignBar1.Visibility = $sync.WPFRedesignBar1Row.Visibility
    $sync.WPFRedesignBar2Row.Visibility = if ($showRegistry) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $sync.WPFRedesignBar2.Visibility = $sync.WPFRedesignBar2Row.Visibility
    if ($showServices) {
        $sync.WPFRedesignBar1Value.Text = Get-WinUtilRedesignText -Key "barOf" -FormatArgs @($services, $totals.Services)
        $sync.WPFRedesignBar1.Value = [Math]::Round(100 * $services / [Math]::Max($totals.Services, 1))
    }
    if ($showRegistry) {
        $sync.WPFRedesignBar2Value.Text = Get-WinUtilRedesignText -Key "barOf" -FormatArgs @($registry, $totals.Registry)
        $sync.WPFRedesignBar2.Value = [Math]::Round(100 * $registry / [Math]::Max($totals.Registry, 1))
    }

    if ($count -eq 0) {
        $sync.WPFRedesignImpactEmpty.Text = Get-WinUtilRedesignText -Key "impactEmpty"
    } elseif (-not ($showServices -or $showRegistry)) {
        $sync.WPFRedesignImpactEmpty.Text = Get-WinUtilRedesignText -Key "impactNone"
    } else {
        $sync.WPFRedesignImpactEmpty.Text = ""
    }
    $sync.WPFRedesignImpactEmpty.Visibility = if ($sync.WPFRedesignImpactEmpty.Text) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
}
