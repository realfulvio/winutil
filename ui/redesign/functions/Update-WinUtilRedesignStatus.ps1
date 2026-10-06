function Update-WinUtilRedesignStatus {
    <#
    .SYNOPSIS
        Writes the status card of the sidebar: nothing applied yet, or how many tweaks were.
    #>

    $applied = [int]$sync.RedesignAppliedCount
    if ($applied -le 0) {
        $sync.WPFRedesignStatusTitle.Text = Get-WinUtilRedesignText -Key "statusNone"
    } elseif ($applied -eq 1) {
        $sync.WPFRedesignStatusTitle.Text = Get-WinUtilRedesignText -Key "statusAppliedOne"
    } else {
        $sync.WPFRedesignStatusTitle.Text = Get-WinUtilRedesignText -Key "statusAppliedMany" -FormatArgs @($applied)
    }
}

function Update-WinUtilRedesignRunStatus {
    <#
    .SYNOPSIS
        After a run, counts the tweaks as applied unless the job ended in error.

    .DESCRIPTION
        Step-WinUtilJob sets the progress value and the bar color in one posted block, so the
        check waits until that block is done. An error ends the job with the error color on the
        bar; anything else counts as applied.
    #>

    if (-not (Test-WinUtilUIAlive)) {
        return
    }

    $null = $sync.Form.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
        if ($sync.WPFTweaksProgressValue.Value -lt 100 -or -not $sync.RedesignPendingCount) {
            return
        }
        $errorBrush = $sync.Form.Resources["ProgressBarErrorColor"]
        $barBrush = $sync.WPFTweaksProgressValue.Foreground
        $failed = $errorBrush -and $barBrush -and ($barBrush.Color -eq $errorBrush.Color)
        if (-not $failed) {
            $sync.RedesignAppliedCount = $sync.RedesignPendingCount
        }
        $sync.RedesignPendingCount = 0
        Update-WinUtilRedesignStatus
    })
}
