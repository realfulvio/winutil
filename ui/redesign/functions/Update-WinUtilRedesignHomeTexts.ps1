function Update-WinUtilRedesignHomeTexts {
    <#
    .SYNOPSIS
        Writes the texts of the Home page in the current language.
    #>

    if (-not $sync.WPFRedesignHomeCard1) {
        return
    }
    foreach ($number in 1..4) {
        $title = Get-WinUtilRedesignText -Key "home${number}Title"
        $sync["WPFRedesignHomeTitle$number"].Text = $title
        $sync["WPFRedesignHomeDesc$number"].Text = Get-WinUtilRedesignText -Key "home${number}Desc"
        $sync["WPFRedesignHomeOpen$number"].Text = Get-WinUtilRedesignText -Key 'homeOpen'
        [System.Windows.Automation.AutomationProperties]::SetName($sync["WPFRedesignHomeCard$number"], [string]$title)
    }
}

function Initialize-WinUtilRedesignHome {
    <#
    .SYNOPSIS
        Makes the four cards of the Home page open the tab they name.

    .DESCRIPTION
        1 Install programs, 2 Optimize Windows, 3 Keep everything up to date (the Updates tab) and
        4 Fix a problem (the Repair tab). Each card presses the sidebar button of its tab, so it
        goes through the same code a click on the sidebar does.
    #>

    $targets = @{
        WPFRedesignHomeCard1 = 'WPFTab1BT'
        WPFRedesignHomeCard2 = 'WPFTab2BT'
        WPFRedesignHomeCard3 = 'WPFTab4BT'
        WPFRedesignHomeCard4 = 'WPFTab3BT'
    }
    foreach ($entry in $targets.GetEnumerator()) {
        $card = $sync[$entry.Key]
        $card.Tag = $entry.Value
        $card.Add_Click({
            Invoke-WPFButton $this.Tag
        })
    }
}
