function Show-WinUtilRedesignProgramDetail {
    <#
    .SYNOPSIS
        Opens the details panel on the right for one program.

    .DESCRIPTION
        Shows the large icon, the name, whether it is installed (only once that is known), the
        description, the category, where the package comes from (the WinGet and Chocolatey IDs),
        the license when the catalog marks the program as open source, the official website and a
        button that adds the program to the selection or takes it out.

    .PARAMETER Key
        The program key, for example WPFInstall7zip.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )

    $item = $sync.RedesignProgramItemMap[$Key]
    if (-not $item) {
        return
    }

    $previous = $sync.RedesignDetailKey
    $sync.RedesignDetailKey = $Key
    Update-WinUtilRedesignDrawer
    $sync.WPFRedesignDrawer.Visibility = [Windows.Visibility]::Visible

    foreach ($changed in @($previous, $Key)) {
        if ($changed -and $sync.RedesignProgramCards[$changed]) {
            Set-WinUtilRedesignCardPaint -Card $sync.RedesignProgramCards[$changed] -Selected $sync.selectedApps.Contains($changed) -Focused ($sync.RedesignDetailKey -eq $changed)
        }
    }
    Update-WinUtilRedesignProgramLayout
}

function Close-WinUtilRedesignProgramDetail {
    <#
    .SYNOPSIS
        Closes the details panel.
    #>

    $previous = $sync.RedesignDetailKey
    $sync.RedesignDetailKey = $null
    $sync.WPFRedesignDrawer.Visibility = [Windows.Visibility]::Collapsed
    if ($previous -and $sync.RedesignProgramCards[$previous]) {
        Set-WinUtilRedesignCardPaint -Card $sync.RedesignProgramCards[$previous] -Selected $sync.selectedApps.Contains($previous) -Focused $false
    }
    Update-WinUtilRedesignProgramLayout
}

function Update-WinUtilRedesignDrawer {
    <#
    .SYNOPSIS
        Writes the details panel for the program that is open, in the current language.
    #>

    $key = $sync.RedesignDetailKey
    if (-not $key) {
        return
    }
    $item = $sync.RedesignProgramItemMap[$key]
    if (-not $item) {
        return
    }

    $parts = @{
        Tile     = $sync.WPFRedesignDrawerTile
        GlyphBox = $sync.WPFRedesignDrawerGlyphBox
        Glyph    = $sync.WPFRedesignDrawerGlyph
        Font     = $sync.WPFRedesignDrawerFont
        Image    = $sync.WPFRedesignDrawerImage
    }
    Set-WinUtilRedesignIcon -Parts $parts -Item $item -ImagePath $sync.RedesignIconFiles[$item.Short.ToLowerInvariant()]

    $sync.WPFRedesignDrawerName.Text = $item.Name
    $sync.WPFRedesignDrawerDesc.Text = Get-WinUtilRedesignProgramText -Item $item
    $sync.WPFRedesignDrawerCategory.Text = Get-WinUtilRedesignCategoryName -Category $item.Category

    if ($null -eq $sync.RedesignInstalled) {
        $sync.WPFRedesignDrawerState.Visibility = [Windows.Visibility]::Collapsed
    } else {
        $installed = $sync.RedesignInstalled.Contains($key)
        $sync.WPFRedesignDrawerState.Visibility = [Windows.Visibility]::Visible
        $sync.WPFRedesignDrawerStateText.Text = Get-WinUtilRedesignText -Key $(if ($installed) { 'drawerInstalled' } else { 'drawerNotInstalled' })
        $sync.WPFRedesignDrawerState.Background = New-WinUtilRedesignBrush $(if ($installed) { '#0E3B33' } else { '#16223C' })
        $sync.WPFRedesignDrawerState.BorderBrush = New-WinUtilRedesignBrush $(if ($installed) { '#1D5A4A' } else { '#22304D' })
        $sync.WPFRedesignDrawerStateText.Foreground = New-WinUtilRedesignBrush $(if ($installed) { '#5EE6B4' } else { '#CFE0F5' })
    }

    $sources = @()
    if ($item.WingetId) { $sources += "WinGet: $($item.WingetId)" }
    if ($item.ChocoId) { $sources += "Chocolatey: $($item.ChocoId)" }
    $sync.WPFRedesignDrawerSource.Text = $sources -join "`n"

    $sync.WPFRedesignDrawerLicenseRow.Visibility = if ($item.Foss) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $sync.WPFRedesignDrawerLicense.Text = Get-WinUtilRedesignText -Key 'drawerOpenSource'

    $hasLink = $false
    try {
        $uri = [uri]$item.Link
        $hasLink = $uri.IsAbsoluteUri -and $uri.Scheme -in 'http', 'https'
    } catch {
        $hasLink = $false
    }
    $sync.WPFRedesignDrawerWebsiteRow.Visibility = if ($hasLink) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $sync.WPFRedesignDrawerWebsiteText.Text = ([string]$item.Link).TrimEnd('/') -replace '^https?://', ''
    $sync.WPFRedesignDrawerWebsite.Tag = $item.Link

    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignDrawerWebsite, ('{0}: {1}' -f (Get-WinUtilRedesignText -Key 'drawerWebsite'), $item.Name))
    Update-WinUtilRedesignDrawerAction
}

function Update-WinUtilRedesignDrawerAction {
    <#
    .SYNOPSIS
        Sets the button of the details panel to "Add to selection" or "Remove from selection".
    #>

    $key = $sync.RedesignDetailKey
    if (-not $key -or -not $sync.WPFRedesignDrawerAction) {
        return
    }
    $selected = $sync.selectedApps.Contains($key)
    $sync.WPFRedesignDrawerAction.Content = Get-WinUtilRedesignText -Key $(if ($selected) { 'drawerRemove' } else { 'drawerAdd' })
}
