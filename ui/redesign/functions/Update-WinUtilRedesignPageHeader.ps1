function Update-WinUtilRedesignPageHeader {
    <#
    .SYNOPSIS
        Writes the page title and subtitle of the tab that is open.

    .DESCRIPTION
        The tweaks page has its own title and subtitle; the other tabs use the name and the line
        of their sidebar entry. The tab name is the one Invoke-WPFTab keeps in $sync.currentTab.
    #>

    $position = @{ Install = 0; Tweaks = 1; Config = 2; Updates = 3; AppX = 4; Win11ISO = 5 }
    $index = $position[[string]$sync.currentTab]
    if ($null -eq $index) {
        $index = 1
    }

    # The search box serves the Install, Tweaks and AppX tabs, so only the Tweaks one says "tweak"
    if ($index -eq 1) {
        $sync.WPFRedesignPageTitle.Text = Get-WinUtilRedesignText -Key "title"
        $sync.WPFRedesignPageSubtitle.Text = Get-WinUtilRedesignText -Key "subtitle"
        $sync.WPFRedesignSearchHint.Text = Get-WinUtilRedesignText -Key "searchPh"
    } else {
        $sync.WPFRedesignSearchHint.Text = Get-WinUtilRedesignText -Key "searchPhAll"
        $sync.WPFRedesignPageTitle.Text = @(Get-WinUtilRedesignText -Key "navTitles")[$index]
        $sync.WPFRedesignPageSubtitle.Text = @(Get-WinUtilRedesignText -Key "navSubs")[$index]
    }
}
