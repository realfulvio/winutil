function Initialize-WinUtilRedesignTweaks {
    <#
    .SYNOPSIS
        Builds the Tweaks tab of the redesigned interface.

    .DESCRIPTION
        One card per checkbox tweak (the ones Apply runs in one go), each carrying a CheckBox
        named after the tweak and the same Checked/Unchecked handling upstream gives it. The
        entries that are not plain checkboxes (switches that apply at once, buttons, lists) are
        built by upstream's Invoke-WPFUIElements into "Other settings", so they behave exactly
        as before.

    .PARAMETER Yield
        Let the interface answer between cards, as upstream does for tabs nobody is waiting on.
    #>
    param(
        [switch]$Yield
    )

    $items = Get-WinUtilRedesignTweakItems
    $sync.RedesignItemsByName = @{}
    $sync.RedesignCards = @{}
    $sync.RedesignTotals = [pscustomobject]@{
        Services = [int](($items | Measure-Object -Property Services -Sum).Sum)
        Registry = [int](($items | Measure-Object -Property Registry -Sum).Sum)
    }
    $sync.WPFRedesignCardList.Children.Clear()

    $yieldClock = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($item in $items) {
        if ($Yield -and $yieldClock.ElapsedMilliseconds -ge 25 -and (Test-WinUtilUIAlive)) {
            $yieldClock.Restart()
            $frame = New-Object Windows.Threading.DispatcherFrame
            $null = $sync.Form.Dispatcher.BeginInvoke(
                [Windows.Threading.DispatcherPriority]::Background,
                [Windows.Threading.DispatcherOperationCallback]{
                    param($dispatcherFrame)
                    $dispatcherFrame.Continue = $false
                    return $null
                },
                $frame)
            [Windows.Threading.Dispatcher]::PushFrame($frame)
        }

        $card = New-WinUtilRedesignCard -Item $item
        $sync.RedesignItemsByName[$item.Name] = $item
        $sync.RedesignCards[$item.Name] = $card
        $sync[$item.Name] = $card.Check

        # The same two handlers upstream gives a checkbox tweak, plus the refresh of the panel
        $card.Check.Add_Checked({
            [System.Object]$Sender = $args[0]
            Invoke-WPFSelectedCheckboxesUpdate -type "Add" -checkboxName $Sender.Name
            Update-WinUtilRedesignSelection -Name $Sender.Name -UserAction:($Sender.IsMouseOver -or $Sender.IsKeyboardFocused)
        })
        $card.Check.Add_Unchecked({
            [System.Object]$Sender = $args[0]
            Invoke-WPFSelectedCheckboxesUpdate -type "Remove" -checkboxName $Sender.Name
            Update-WinUtilRedesignSelection -Name $Sender.Name
        })
        $card.Body.Tag = $item.Name
        $card.Body.Add_Click({
            Set-WinUtilRedesignFocus -Name $this.Tag
        })

        $null = $sync.WPFRedesignCardList.Children.Add($card.Root)
    }

    # Switches, buttons and lists keep upstream's own rendering
    $others = [ordered]@{}
    foreach ($property in $sync.configs.tweaks.PSObject.Properties) {
        if (-not (Test-WinUtilRedesignCardEntry -Entry $property.Value)) {
            $others[$property.Name] = $property.Value
        }
    }
    if ($others.Count -gt 0) {
        Invoke-WPFUIElements -configVariable ([pscustomobject]$others) -targetGridName "WPFRedesignOtherGrid" -columncount 1 -Yield:$Yield
    }
    if ($sync["WPFchangedns"]) {
        $sync["WPFchangedns"].Add_SelectionChanged({
            Update-WinUtilRedesignSelection
        })
    }

    Update-WinUtilRedesignCardTexts
    Update-WinUtilRedesignChipCounts
    Update-WinUtilRedesignFilter
    Update-WinUtilRedesignDetails
    Update-WinUtilRedesignSelection
}
