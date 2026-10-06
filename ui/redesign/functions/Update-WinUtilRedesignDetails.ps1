function Update-WinUtilRedesignDetails {
    <#
    .SYNOPSIS
        Fills the "Before you apply" panel with the tweak that is in focus.

    .DESCRIPTION
        Shows what the tweak changes, its possible effects and whether it can be undone. The
        undo line comes from the tweak's own data (see Get-WinUtilRedesignTweakItems). An amber
        box carries the tweak's warning, or a generic advice for an advanced tweak without one;
        a tweak with neither gets the green "safe" box.
    #>

    $item = $null
    if ($sync.RedesignCardsReady -and $sync.RedesignFocus) {
        $item = $sync.RedesignItemsByName[$sync.RedesignFocus]
    }

    if (-not $item) {
        $sync.WPFRedesignFocusCard.Visibility = [Windows.Visibility]::Collapsed
        $sync.WPFRedesignDetails.Visibility = [Windows.Visibility]::Collapsed
        $sync.WPFRedesignNoFocus.Text = Get-WinUtilRedesignText -Key "noFocus"
        $sync.WPFRedesignNoFocus.Visibility = [Windows.Visibility]::Visible
        return
    }

    $text = Get-WinUtilRedesignItemText -Item $item
    $sync.WPFRedesignNoFocus.Visibility = [Windows.Visibility]::Collapsed
    $sync.WPFRedesignFocusCard.Visibility = [Windows.Visibility]::Visible
    $sync.WPFRedesignDetails.Visibility = [Windows.Visibility]::Visible

    $sync.WPFRedesignFocusIcon.Text = $item.Icon
    $sync.WPFRedesignFocusName.Text = $text.name
    $sync.WPFRedesignFocusDesc.Text = $text.desc
    $sync.WPFRedesignWhatText.Text = $text.what
    $sync.WPFRedesignEffText.Text = $text.eff
    $undoKey = if ($item.Undoable) { "undoYes" } else { "undoNo" }
    $sync.WPFRedesignUndoText.Text = Get-WinUtilRedesignText -Key $undoKey

    $warning = [string]$text.warn
    if (-not $warning -and $item.Caution) {
        $warning = Get-WinUtilRedesignText -Key "cautionNote"
    }
    if ($warning) {
        $sync.WPFRedesignWarnText.Text = $warning
        $sync.WPFRedesignWarnBox.Visibility = [Windows.Visibility]::Visible
        $sync.WPFRedesignSafeBox.Visibility = [Windows.Visibility]::Collapsed
    } else {
        $sync.WPFRedesignSafeText.Text = Get-WinUtilRedesignText -Key "safeNote"
        $sync.WPFRedesignSafeBox.Visibility = [Windows.Visibility]::Visible
        $sync.WPFRedesignWarnBox.Visibility = [Windows.Visibility]::Collapsed
    }
}
