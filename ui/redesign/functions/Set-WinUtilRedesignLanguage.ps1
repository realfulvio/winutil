function Set-WinUtilRedesignLanguage {
    <#
    .SYNOPSIS
        Switches the redesigned interface between Italian and English.

    .DESCRIPTION
        Every text comes from the dictionary in strings.json, so this is the only place that
        writes labels into the static controls. The tweak cards are written by
        Update-WinUtilRedesignCardTexts, which also re-sorts them by the new names.

    .PARAMETER Language
        en or it.

    .PARAMETER Toggle
        Switch to the other language.
    #>
    param(
        [ValidateSet("en", "it")]
        [string]$Language,

        [switch]$Toggle
    )

    if ($Toggle) {
        $Language = if ($sync.preferences.language -eq "it") { "en" } else { "it" }
    }
    if (-not $Language) {
        $Language = "en"
    }
    $sync.preferences.language = $Language
    $text = { param($Key) Get-WinUtilRedesignText -Key $Key }

    # Sidebar entries; the AppX tab (6) comes before Create ISO (5) in the sidebar
    $titles = @(& $text "navTitles")
    $subtitles = @(& $text "navSubs")
    $tabNumbers = @(1, 2, 3, 4, 6, 5)
    for ($position = 0; $position -lt $tabNumbers.Count; $position++) {
        $number = $tabNumbers[$position]
        $sync["WPFRedesignNavTitle$number"].Text = $titles[$position]
        $sync["WPFRedesignNavSub$number"].Text = $subtitles[$position]
        [System.Windows.Automation.AutomationProperties]::SetName($sync["WPFTab${number}BT"], [string]$titles[$position])
    }

    $sync.WPFRedesignStatusNote.Text = & $text "statusNote"
    $sync.WPFRedesignSettingsText.Text = & $text "settings"
    $sync.WPFRedesignAboutText.Text = & $text "about"
    $sync.WPFRedesignLangName.Text = & $text "langName"
    $sync.WPFRedesignLangCode.Text = & $text "langCode"
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignLangButton, [string](& $text "langAria"))
    $sync.WPFRedesignLangButton.ToolTip = & $text "langAria"
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignHelpButton, [string](& $text "help"))
    $sync.WPFRedesignHelpButton.ToolTip = & $text "help"
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignSettingsButton, [string](& $text "settings"))

    $sync.WPFRedesignSearchHint.Text = & $text "searchPh"
    [System.Windows.Automation.AutomationProperties]::SetName($sync.SearchBar, [string](& $text "searchPh"))
    $sync.SearchBar.ToolTip = & $text "searchPh"

    $sync.WPFRedesignChipRecText.Text = & $text "chipRec"
    $sync.WPFRedesignChipPrivacyText.Text = & $text "chipPrivacy"
    $sync.WPFRedesignChipSystemText.Text = & $text "chipSystem"
    $sync.WPFRedesignChipAdvancedText.Text = & $text "chipAdvanced"

    $sync.WPFRedesignQuickTitle.Text = & $text "quickTitle"
    $sync.WPFRedesignOtherTitle.Text = & $text "otherTitle"
    $sync.WPFRedesignOtherNote.Text = & $text "otherNote"
    $sync.WPFstandard.Content = & $text "presetStandard"
    $sync.WPFminimal.Content = & $text "presetMinimal"
    $sync.WPFAdvanced.Content = & $text "presetAdvanced"
    $sync.WPFGetInstalledTweaks.Content = & $text "presetInstalled"
    $sync.WPFAppxRemoval.Content = & $text "presetAppx"

    $sync.WPFRedesignBeforeTitle.Text = & $text "before"
    $sync.WPFRedesignWhatTitle.Text = & $text "whatChanges"
    $sync.WPFRedesignEffTitle.Text = & $text "effects"
    $sync.WPFRedesignUndoTitle.Text = & $text "undo"
    $sync.WPFRedesignImpactTitle.Text = (& $text "impact").ToUpper()
    $sync.WPFRedesignImpactNote.Text = & $text "impactNote"
    $sync.WPFRedesignBar1Label.Text = & $text "barServices"
    $sync.WPFRedesignBar2Label.Text = & $text "barRegistry"
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignBar1, [string](& $text "barServices"))
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignBar2, [string](& $text "barRegistry"))
    $sync.WPFRedesignFootNote.Text = & $text "footNote"
    $sync.WPFRedesignDoneNote.Text = & $text "doneNote"
    $sync.WPFClearTweaksSelection.Content = & $text "clearSel"
    $sync.WPFUndoall.Content = & $text "undoSelected"
    $sync.WPFRedesignNewSelection.Content = & $text "newSel"

    Update-WinUtilRedesignPageHeader
    Update-WinUtilRedesignStatus
    if ($sync.RedesignCards) {
        Update-WinUtilRedesignCardTexts
        Update-WinUtilRedesignChipCounts
        Update-WinUtilRedesignFilter
        Update-WinUtilRedesignDetails
        Update-WinUtilRedesignSelection
    }
}

function Update-WinUtilRedesignChipCounts {
    <#
    .SYNOPSIS
        Writes how many tweaks each filter chip holds.
    #>

    $items = $sync.RedesignItems
    if (-not $items) {
        return
    }

    $sync.WPFRedesignChipRecCount.Text = @($items | Where-Object { $_.Recommended }).Count
    $sync.WPFRedesignChipPrivacyCount.Text = @($items | Where-Object { $_.Category -eq "privacy" }).Count
    $sync.WPFRedesignChipSystemCount.Text = @($items | Where-Object { $_.Category -eq "system" }).Count
    $sync.WPFRedesignChipAdvancedCount.Text = @($items | Where-Object { $_.Category -eq "advanced" }).Count
}
