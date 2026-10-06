function Initialize-WinUtilRedesignShell {
    <#
    .SYNOPSIS
        Wires the controls of the redesigned window, once.

    .DESCRIPTION
        Runs the first time a tab is opened (see Initialize-WinUtilTabContent), when every
        control of the window is in $sync. Sidebar entries, the search box, the window buttons and
        the theme and settings popups are the upstream controls and keep their upstream handlers;
        this only adds the handlers of the controls the redesign introduces: language, settings,
        about and help in the sidebar, the filter chips, the "new selection" button and the
        status watch on the progress bar.

        The language starts from the Windows display language (Italian or English).
    #>

    if ($sync.RedesignShellReady) {
        return
    }
    $sync.RedesignShellReady = $true

    try {
        if (-not $sync.preferences.language) {
            $sync.preferences.language = if ((Get-UICulture).TwoLetterISOLanguageName -eq "it") { "it" } else { "en" }
        }
        $sync.RedesignFilter = "rec"
        $sync.RedesignAppliedCount = 0
        $sync.RedesignPendingCount = 0

        $sync.WPFRedesignLangButton.Add_Click({
            Set-WinUtilRedesignLanguage -Toggle
        })
        $sync.WPFRedesignSettingsButton.Add_Click({
            Invoke-WPFPopup -PopupActionTable @{ "Settings" = "Toggle"; "Theme" = "Hide"; "FontScaling" = "Hide" }
        })
        $sync.WPFRedesignAboutButton.Add_Click({
            $sync.AboutMenuItem.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))
        })
        $sync.WPFRedesignHelpButton.Add_Click({
            $sync.DocumentationMenuItem.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))
        })
        $sync.WPFRedesignNewSelection.Add_Click({
            $sync.RedesignAppliedCount = 0
            Update-WinUtilRedesignStatus
            Invoke-WPFButton "WPFClearTweaksSelection"
        })

        $filters = @{
            WPFRedesignChipRec      = "rec"
            WPFRedesignChipPrivacy  = "privacy"
            WPFRedesignChipSystem   = "system"
            WPFRedesignChipAdvanced = "advanced"
        }
        foreach ($chip in $filters.GetEnumerator()) {
            $sync[$chip.Key].Tag = $chip.Value
            $sync[$chip.Key].Add_Click({
                Set-WinUtilRedesignFilter -Filter $this.Tag
            })
        }

        # Counts what the Apply button starts, so the status card can report it once the job ends
        $sync.WPFTweaksbutton.Add_Click({
            $sync.RedesignPendingCount = @($sync.selectedTweaks).Count
            $sync.RedesignAppliedCount = 0
            Update-WinUtilRedesignStatus
        })
        $sync.WPFTweaksProgressValue.Add_ValueChanged({
            Update-WinUtilRedesignRunStatus
        })

        Set-WinUtilRedesignLanguage -Language $sync.preferences.language
    } catch {
        $sync.RedesignShellReady = $false
        throw
    }
}
