function Update-WinUtilRedesignPageHeader {
    <#
    .SYNOPSIS
        Writes the page title and subtitle of the tab that is open.

    .DESCRIPTION
        The tweaks page has its own title and subtitle; the other tabs use the name and the line
        of their sidebar entry. The tab name is the one Invoke-WPFTab keeps in $sync.currentTab.
        The search box says what it searches: programs on the Programs tab, tweaks on the Tweaks
        tab, and a general hint elsewhere.
    #>

    $position = @{ Install = 0; Tweaks = 1; Config = 2; Updates = 3; AppX = 4; Win11ISO = 5; Home = 6 }
    $index = $position[[string]$sync.currentTab]
    if ($null -eq $index) {
        $index = 1
    }

    if ($index -eq 1) {
        $sync.WPFRedesignPageTitle.Text = Get-WinUtilRedesignText -Key "title"
        $sync.WPFRedesignPageSubtitle.Text = Get-WinUtilRedesignText -Key "subtitle"
        $sync.WPFRedesignSearchHint.Text = Get-WinUtilRedesignText -Key "searchPh"
    } elseif ($index -eq 6) {
        $sync.WPFRedesignPageTitle.Text = Get-WinUtilRedesignText -Key "homeTitle"
        $sync.WPFRedesignPageSubtitle.Text = Get-WinUtilRedesignText -Key "homeSub"
        $sync.WPFRedesignSearchHint.Text = Get-WinUtilRedesignText -Key "searchPhAll"
    } else {
        $sync.WPFRedesignSearchHint.Text = Get-WinUtilRedesignText -Key $(if ($index -eq 0) { "searchPhApps" } else { "searchPhAll" })
        $sync.WPFRedesignPageTitle.Text = @(Get-WinUtilRedesignText -Key "navTitles")[$index]
        $sync.WPFRedesignPageSubtitle.Text = @(Get-WinUtilRedesignText -Key "navSubs")[$index]
    }
}
