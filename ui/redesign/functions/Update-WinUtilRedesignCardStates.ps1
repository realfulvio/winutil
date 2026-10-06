function Update-WinUtilRedesignCardStates {
    <#
    .SYNOPSIS
        Repaints the border of every tweak card: in focus, selected or idle.

    .DESCRIPTION
        The card in focus gets the accent border and a soft glow, a selected card a stronger
        border than an idle one.
    #>

    if (-not $sync.RedesignCards) {
        return
    }

    $focusBrush = New-WinUtilRedesignBrush "#4CC2FF"
    $selectedBrush = New-WinUtilRedesignBrush "#2C4A73"
    $idleBrush = New-WinUtilRedesignBrush "#1E2A44"
    $selected = $sync.selectedTweaks

    foreach ($entry in $sync.RedesignCards.GetEnumerator()) {
        $root = $entry.Value.Root
        if ($sync.RedesignFocus -eq $entry.Key) {
            $root.BorderBrush = $focusBrush
            $glow = [Windows.Media.Effects.DropShadowEffect]::new()
            $glow.Color = [Windows.Media.Color]::FromRgb(76, 194, 255)
            $glow.Opacity = 0.25
            $glow.BlurRadius = 24
            $glow.ShadowDepth = 0
            $root.Effect = $glow
        } else {
            $root.Effect = $null
            if ($selected -and $selected.Contains($entry.Key)) {
                $root.BorderBrush = $selectedBrush
            } else {
                $root.BorderBrush = $idleBrush
            }
        }
    }
}
