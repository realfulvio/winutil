function Set-WinUtilRedesignCardTexts {
    <#
    .SYNOPSIS
        Writes the texts of one program card in the current language.

    .PARAMETER Item
        An entry of Get-WinUtilRedesignProgramItems.

    .PARAMETER Card
        The card of that program.
    #>
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][hashtable]$Card
    )

    $Card.Title.Text = $Item.Name
    $Card.Desc.Text = Get-WinUtilRedesignProgramText -Item $Item
    [System.Windows.Automation.AutomationProperties]::SetName($Card.Check, (Get-WinUtilRedesignText -Key 'selectAria' -FormatArgs @($Item.Name)))
    [System.Windows.Automation.AutomationProperties]::SetName($Card.Body, [string]$Item.Name)
    [System.Windows.Automation.AutomationProperties]::SetName($Card.Info, (Get-WinUtilRedesignText -Key 'infoAria' -FormatArgs @($Item.Name)))

    $installed = $null -ne $sync.RedesignInstalled -and $sync.RedesignInstalled.Contains($Item.Key)
    if ($installed) {
        $Card.BadgeText.Text = Get-WinUtilRedesignText -Key 'badgeInstalled'
        $Card.BadgeText.Foreground = New-WinUtilRedesignBrush '#5EE6B4'
        $Card.Badge.Background = New-WinUtilRedesignBrush '#0E3B33'
        $Card.Badge.BorderBrush = New-WinUtilRedesignBrush '#1D5A4A'
    } else {
        $Card.BadgeText.Text = Get-WinUtilRedesignCategoryName -Category $Item.Category
        $Card.BadgeText.Foreground = New-WinUtilRedesignBrush '#9FC0FF'
        $Card.Badge.Background = New-WinUtilRedesignBrush '#123068'
        $Card.Badge.BorderBrush = New-WinUtilRedesignBrush '#1E3F7A'
    }
}

function Set-WinUtilRedesignCardIcon {
    <#
    .SYNOPSIS
        Draws the icon of one program everywhere it is shown, from the cache when it has one.

    .DESCRIPTION
        Called when a card is built and again when the background download has saved an icon.
        The card, the icons of the kit cards that include the program and the details panel
        are all updated.

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
    $path = $sync.RedesignIconFiles[$item.Short.ToLowerInvariant()]

    $card = $sync.RedesignProgramCards[$Key]
    if ($card) {
        Set-WinUtilRedesignIcon -Parts $card -Item $item -ImagePath $path
    }
    foreach ($kitCard in @($sync.RedesignKitCards)) {
        foreach ($entry in $kitCard.IconParts) {
            if ($entry.Item.Key -eq $Key) {
                Set-WinUtilRedesignIcon -Parts $entry.Parts -Item $item -ImagePath $path
            }
        }
    }
    if ($sync.RedesignDetailKey -eq $Key) {
        Update-WinUtilRedesignDrawer
    }
}

function Update-WinUtilRedesignProgramLayout {
    <#
    .SYNOPSIS
        Sizes the program cards and the kit cards so each row is filled evenly.

    .DESCRIPTION
        A card is at least 280 px wide (a kit 272 px); the columns are as many as fit and the cards
        share what is left. Called when the area changes size, which also happens when the details
        panel opens or closes.
    #>

    if (-not $sync.WPFRedesignProgContent) {
        return
    }
    $available = $sync.WPFRedesignProgContent.ActualWidth
    if ($available -le 0) {
        return
    }

    $columns = [Math]::Max(1, [Math]::Floor($available / 292))
    $width = [Math]::Floor($available / $columns) - 12
    if ($width -ne $sync.RedesignCardWidth) {
        $sync.RedesignCardWidth = $width
        foreach ($card in $sync.RedesignProgramCards.Values) {
            $card.Root.Width = $width
        }
    }

    $kitColumns = [Math]::Max(1, [Math]::Floor($available / 286))
    $kitWidth = [Math]::Floor($available / $kitColumns) - 14
    foreach ($kitCard in @($sync.RedesignKitCards)) {
        $kitCard.Root.Width = $kitWidth
    }
}

function Update-WinUtilRedesignProgramTexts {
    <#
    .SYNOPSIS
        Writes every text of the Programs tab in the current language.

    .DESCRIPTION
        Run when the tab is built and when the language changes. The kits are drawn again, since
        the built-in ones are named in both languages.
    #>

    if (-not $sync.WPFRedesignKitsLabel) {
        return
    }
    $text = { param($Key) Get-WinUtilRedesignText -Key $Key }

    $sync.WPFRedesignKitsLabel.Text = & $text 'kitsLabel'
    $sync.WPFRedesignCatalogLabel.Text = & $text 'catalogLabel'
    $sync.WPFRedesignKitImport.Content = & $text 'kitImport'
    $sync.WPFRedesignKitCreate.Content = & $text 'kitCreate'

    $sync.WPFRedesignDockClear.Content = & $text 'dockClear'
    $sync.WPFRedesignDockMore.ToolTip = & $text 'dockMore'
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignDockMore, [string](& $text 'dockMore'))
    $sync.WPFRedesignMenuUninstall.Content = & $text 'menuUninstall'
    $sync.WPFRedesignMenuUpgradeAll.Content = & $text 'menuUpgradeAll'
    $sync.WPFRedesignMenuSelectInstalled.Content = & $text 'menuSelectInstalled'
    $sync.WPFRedesignMenuManagerLabel.Text = & $text 'menuManager'
    $sync.WPFRedesignDockDone.Content = & $text 'runOk'

    $sync.WPFRedesignDrawerClose.ToolTip = & $text 'drawerClose'
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignDrawerClose, [string](& $text 'drawerClose'))
    $sync.WPFRedesignDrawerCategoryLabel.Text = & $text 'drawerCategory'
    $sync.WPFRedesignDrawerSourceLabel.Text = & $text 'drawerSource'
    $sync.WPFRedesignDrawerLicenseLabel.Text = & $text 'drawerLicense'
    $sync.WPFRedesignDrawerWebsiteLabel.Text = & $text 'drawerWebsite'

    $sync.WPFRedesignKdTitle.Text = & $text 'kdTitle'
    $sync.WPFRedesignKdIntro.Text = & $text 'kdIntro'
    $sync.WPFRedesignKdNameLabel.Text = (& $text 'kdName').ToUpper()
    $sync.WPFRedesignKdNameHint.Text = & $text 'kdNamePh'
    $sync.WPFRedesignKdDescLabel.Text = (& $text 'kdDesc').ToUpper()
    $sync.WPFRedesignKdDescHint.Text = & $text 'kdDescPh'
    $sync.WPFRedesignKdColorLabel.Text = (& $text 'kdColor').ToUpper()
    $sync.WPFRedesignKdTip.Text = & $text 'kdTip'
    $sync.WPFRedesignKdCancel.Content = & $text 'kdCancel'
    $sync.WPFRedesignKdSave.Content = & $text 'kdSave'
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignKdName, [string](& $text 'kdName'))
    [System.Windows.Automation.AutomationProperties]::SetName($sync.WPFRedesignKdDesc, [string](& $text 'kdDesc'))
    if ($sync.WPFRedesignKitScrim.Visibility -eq [Windows.Visibility]::Visible) {
        $sync.WPFRedesignKdProgramsLabel.Text = (Get-WinUtilRedesignText -Key 'kdPrograms' -FormatArgs @($sync.WPFRedesignKdPrograms.Children.Count)).ToUpper()
    }

    foreach ($item in (Get-WinUtilRedesignProgramItems)) {
        $card = $sync.RedesignProgramCards[$item.Key]
        if ($card) {
            Set-WinUtilRedesignCardTexts -Item $item -Card $card
        }
    }
    Update-WinUtilRedesignProgramChipTexts
    Update-WinUtilRedesignManagerMenu
    Update-WinUtilRedesignKits
    Update-WinUtilRedesignDrawer
    Update-WinUtilRedesignProgramFilter
    Update-WinUtilRedesignProgramSelection
}

function Update-WinUtilRedesignManagerMenu {
    <#
    .SYNOPSIS
        Shows which package manager is in use in the "more actions" menu.
    #>

    if (-not $sync.WPFRedesignMenuWinget) {
        return
    }
    $choco = $sync.preferences.packagemanager -eq 'Choco'
    $sync.WPFRedesignMenuWinget.IsChecked = -not $choco
    $sync.WPFRedesignMenuChoco.IsChecked = $choco
}
