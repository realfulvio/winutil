function Set-WinUtilRedesignProgramSelected {
    <#
    .SYNOPSIS
        Selects or deselects a program the way a click on its checkbox does.

    .DESCRIPTION
        When the card exists its checkbox is changed and the handlers do the rest. While the
        cards are still being built the selection list is changed directly, and the card takes
        it from there when it is created.

    .PARAMETER Key
        The program key, for example WPFInstall7zip.

    .PARAMETER Selected
        $true to select, $false to deselect.
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][bool]$Selected
    )

    $card = if ($sync.RedesignProgramCards) { $sync.RedesignProgramCards[$Key] } else { $null }
    if ($card) {
        if ($card.Check.IsChecked -ne $Selected) {
            $card.Check.IsChecked = $Selected
        }
        return
    }
    Invoke-WPFSelectedCheckboxesUpdate -type $(if ($Selected) { 'Add' } else { 'Remove' }) -checkboxName $Key
    Update-WinUtilRedesignProgramSelection -Key $Key
}

function Get-WinUtilRedesignCardBackground {
    <#
    .SYNOPSIS
        The frozen top-to-bottom gradient of a card in a given state (idle or selected).

    .PARAMETER State
        idle or selected.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('idle', 'selected')]
        [string]$State
    )

    if ($null -eq $sync.RedesignCardBackgrounds) {
        $sync.RedesignCardBackgrounds = @{}
    }
    if (-not $sync.RedesignCardBackgrounds.ContainsKey($State)) {
        $colors = if ($State -eq 'selected') { @('#17386B', '#102A52') } else { @('#142243', '#0F182B') }
        $brush = [Windows.Media.LinearGradientBrush]::new()
        $brush.StartPoint = [Windows.Point]::new(0, 0)
        $brush.EndPoint = [Windows.Point]::new(0, 1)
        $null = $brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($colors[0]), 0))
        $null = $brush.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString($colors[1]), 1))
        $brush.Freeze()
        $sync.RedesignCardBackgrounds[$State] = $brush
    }
    return $sync.RedesignCardBackgrounds[$State]
}

function Set-WinUtilRedesignCardPaint {
    <#
    .SYNOPSIS
        Paints a program card: selected, in focus (its details are open) or idle.

    .PARAMETER Card
        A card of New-WinUtilRedesignAppCard.

    .PARAMETER Selected
        Whether the program is in the selection.

    .PARAMETER Focused
        Whether the details panel shows this program.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Card,
        [bool]$Selected,
        [bool]$Focused
    )

    $root = $Card.Root
    $root.Background = Get-WinUtilRedesignCardBackground -State $(if ($Selected) { 'selected' } else { 'idle' })
    if ($Focused) {
        $root.BorderBrush = New-WinUtilRedesignBrush '#4CC2FF'
        $glow = [Windows.Media.Effects.DropShadowEffect]::new()
        $glow.Color = [Windows.Media.Color]::FromRgb(76, 194, 255)
        $glow.Opacity = 0.25
        $glow.BlurRadius = 20
        $glow.ShadowDepth = 0
        $root.Effect = $glow
    } else {
        $root.Effect = $null
        $root.BorderBrush = New-WinUtilRedesignBrush $(if ($Selected) { '#4CC2FF' } else { '#1E2A44' })
    }
}

function Update-WinUtilRedesignProgramSelection {
    <#
    .SYNOPSIS
        Refreshes everything that depends on which programs are selected.

    .DESCRIPTION
        The card that changed (or all of them), the action dock, the kit buttons and the action
        of the details panel.

    .PARAMETER Key
        The program that was just checked or unchecked; omit to repaint every card.
    #>
    param(
        [string]$Key
    )

    if (-not $sync.WPFRedesignDockTitle) {
        return
    }

    $selected = $sync.selectedApps
    if ($Key) {
        $card = $sync.RedesignProgramCards[$Key]
        if ($card) {
            Set-WinUtilRedesignCardPaint -Card $card -Selected $selected.Contains($Key) -Focused ($sync.RedesignDetailKey -eq $Key)
        }
    } else {
        foreach ($entry in @($sync.RedesignProgramCards.GetEnumerator())) {
            Set-WinUtilRedesignCardPaint -Card $entry.Value -Selected $selected.Contains($entry.Key) -Focused ($sync.RedesignDetailKey -eq $entry.Key)
        }
    }

    Update-WinUtilRedesignDock
    Update-WinUtilRedesignKitButtons
    Update-WinUtilRedesignDrawerAction
}

function Update-WinUtilRedesignDock {
    <#
    .SYNOPSIS
        Writes the floating action bar: how many programs are selected and what Install will do.

    .DESCRIPTION
        While a notice is on (see Show-WinUtilRedesignNotice) it takes the place of the second
        line. Nothing about timing is claimed: the line says which package manager is used and,
        once the installed programs are known, how many of the selection are already there.
    #>

    if (-not $sync.WPFRedesignDockTitle) {
        return
    }

    $count = @($sync.selectedApps).Count
    if ($count -eq 0) {
        $sync.WPFRedesignDockTitle.Text = Get-WinUtilRedesignText -Key 'dockNone'
        $subtitle = Get-WinUtilRedesignText -Key 'dockNoneSub'
        $sync.WPFRedesignDockInstall.Content = Get-WinUtilRedesignText -Key 'dockInstall'
    } else {
        $sync.WPFRedesignDockTitle.Text = if ($count -eq 1) { Get-WinUtilRedesignText -Key 'dockOne' } else { Get-WinUtilRedesignText -Key 'dockMany' -FormatArgs @($count) }
        $subtitle = Get-WinUtilRedesignText -Key $(if ($sync.preferences.packagemanager -eq 'Choco') { 'dockSubChoco' } else { 'dockSubWinget' })
        if ($null -ne $sync.RedesignInstalled) {
            $already = @($sync.selectedApps | Where-Object { $sync.RedesignInstalled.Contains($_) }).Count
            if ($already -gt 0) {
                $subtitle += ' ' + [char]0x00B7 + ' ' + (Get-WinUtilRedesignText -Key 'dockSubUpdate' -FormatArgs @($already))
            }
        }
        $sync.WPFRedesignDockInstall.Content = Get-WinUtilRedesignText -Key 'dockInstallN' -FormatArgs @($count)
    }
    $sync.WPFRedesignDockInstall.IsEnabled = $count -gt 0
    $sync.WPFRedesignDockClear.IsEnabled = $count -gt 0

    if ($sync.RedesignNotice) {
        $sync.WPFRedesignDockSub.Text = $sync.RedesignNotice.Text
        $sync.WPFRedesignDockSub.Foreground = New-WinUtilRedesignBrush $(if ($sync.RedesignNotice.Warning) { '#FFD27A' } else { '#9BE7C4' })
    } else {
        $sync.WPFRedesignDockSub.Text = $subtitle
        $sync.WPFRedesignDockSub.Foreground = New-WinUtilRedesignBrush '#B7C6DE'
    }
}

function Show-WinUtilRedesignNotice {
    <#
    .SYNOPSIS
        Says something short in the second line of the action bar for a few seconds.

    .PARAMETER Text
        What to say.

    .PARAMETER Warning
        Draws it in amber instead of green.
    #>
    param(
        [Parameter(Mandatory)][string]$Text,
        [switch]$Warning
    )

    $sync.RedesignNotice = @{ Text = $Text; Warning = [bool]$Warning }
    if ($null -eq $sync.RedesignNoticeTimer) {
        $timer = [Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [TimeSpan]::FromSeconds(9)
        $timer.Add_Tick({
            $sync.RedesignNoticeTimer.Stop()
            $sync.RedesignNotice = $null
            Update-WinUtilRedesignDock
        })
        $sync.RedesignNoticeTimer = $timer
    }
    $sync.RedesignNoticeTimer.Stop()
    $sync.RedesignNoticeTimer.Start()
    Update-WinUtilRedesignDock
}

function Update-WinUtilRedesignInstallRunStatus {
    <#
    .SYNOPSIS
        When an install, uninstall or upgrade job ends, says how it went and refreshes what is installed.

    .DESCRIPTION
        Step-WinUtilJob sets the progress value and the bar color in one posted block, so the
        check waits until that block is done. A bar in the error color means the job ended in
        error; anything else counts as done.
    #>

    if (-not (Test-WinUtilUIAlive)) {
        return
    }

    $null = $sync.Form.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
        if ($sync.WPFTweaksProgressValue.Value -lt 100 -or $sync.currentTab -ne 'Install') {
            return
        }
        $errorBrush = $sync.Form.Resources['ProgressBarErrorColor']
        $barBrush = $sync.WPFTweaksProgressValue.Foreground
        $failed = $errorBrush -and $barBrush -and ($barBrush.Color -eq $errorBrush.Color)
        $sync.RedesignRunOk = -not $failed
        $line = if ($failed) { Get-WinUtilRedesignText -Key 'runFailed' } else { Get-WinUtilRedesignText -Key 'runDone' }
        $note = if ($failed) { Get-WinUtilRedesignText -Key 'runFailedNote' } else { Get-WinUtilRedesignText -Key 'runDoneNote' }
        $sync.WPFRedesignDockRunNote.Text = "$line. $note"
        Update-WinUtilRedesignInstalled
    })
}

function Update-WinUtilRedesignKitButtons {
    <#
    .SYNOPSIS
        Sets each kit button to "Add kit" or "Added", from what is selected now.
    #>

    if (-not $sync.RedesignKitButtons) {
        return
    }
    foreach ($entry in $sync.RedesignKitButtons) {
        $added = $true
        foreach ($key in $entry.Kit.AppKeys) {
            if (-not $sync.selectedApps.Contains($key)) {
                $added = $false
                break
            }
        }
        $entry.Button.Content = Get-WinUtilRedesignText -Key $(if ($added) { 'kitAdded' } else { 'kitAdd' })
        $entry.Button.Style = $sync.Form.FindResource($(if ($added) { 'RdKitButtonOnStyle' } else { 'RdKitButtonStyle' }))
    }
}
