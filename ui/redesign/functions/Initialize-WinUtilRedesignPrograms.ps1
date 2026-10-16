function Initialize-WinUtilRedesignPrograms {
    <#
    .SYNOPSIS
        Builds the Programs tab of the redesigned interface.

    .DESCRIPTION
        Upstream's own install controls are still built, hidden: the install, uninstall and
        upgrade buttons, the package manager choice and the list of selected apps. The redesign
        drives them (the dock buttons call Invoke-WPFButton with their names), so installing,
        removing and upgrading are the code that already existed. What is new is the window:
        kits, category chips, one card per program in the catalog, the details panel and the
        floating action bar.

        The cards are built in slices on the interface thread, between the things the user does,
        as upstream does for its own list; the icons come from the cache at once and from the
        network later.

    .PARAMETER Yield
        Accepted for symmetry with the other tabs. The cards are always built in slices.
    #>
    param(
        [switch]$Yield
    )
    $null = $Yield

    $items = Get-WinUtilRedesignProgramItems
    $sync.RedesignProgramsReady = $false
    $sync.RedesignProgramCards = @{}
    $sync.RedesignProgFilter = 'all'
    $sync.RedesignInstalled = $null
    $sync.RedesignDetailKey = $null
    $sync.RedesignKitCards = [System.Collections.Generic.List[object]]::new()
    $sync.WPFRedesignProgGrid.Children.Clear()
    Read-WinUtilRedesignIconIndex

    # Upstream's controls, built in the hidden "appscategory" grid. The job layer also disables
    # $sync.ItemsControl while a job runs, which here is the whole catalog area.
    Initialize-WPFUI -targetGridName 'appscategory'
    Initialize-WinUtilInstallTabControls
    $sync.ItemsControl = $sync.WPFRedesignProgContent

    Initialize-WinUtilRedesignProgramControls
    Initialize-WinUtilRedesignProgramChips
    Update-WinUtilRedesignProgramTexts

    $queue = [System.Collections.Queue]::new()
    $queue.Enqueue([pscustomobject]@{ Keys = @($items | ForEach-Object Key) })
    Start-WinUtilBackgroundQueue -Name 'ProgramCards' -Queue $queue `
        -Step { param($Batch) Invoke-WinUtilRedesignProgramCardBatch -Batch $Batch } `
        -OnComplete { Complete-WinUtilRedesignPrograms } `
        -DeferWhile { $sync.TabWarmupQueue -and $sync.TabWarmupQueue.Count -gt 0 }
}

function Invoke-WinUtilRedesignProgramCardBatch {
    <#
    .SYNOPSIS
        Builds as many program cards as fit in a slice of time, and queues the rest.

    .DESCRIPTION
        Runs to a deadline rather than a count, so how long a click can be left waiting does not
        depend on the machine. At least one card is built per pass, so a slow machine finishes.

    .PARAMETER Batch
        An object with Keys, the program keys still to build.
    #>
    param(
        [Parameter(Mandatory)]
        $Batch
    )

    $budgetMs = 25
    $keys = @($Batch.Keys)
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $built = 0
    $query = if ($sync.SearchBar -and $sync.currentTab -eq 'Install') { $sync.SearchBar.Text.Trim() } else { '' }

    foreach ($key in $keys) {
        $item = $sync.RedesignProgramItemMap[$key]
        $card = New-WinUtilRedesignAppCard -Item $item
        $sync.RedesignProgramCards[$key] = $card
        # Registered like upstream's entry checkbox, so selection, presets and import keep working
        $sync[$key] = $card.Check

        if ($sync.RedesignCardWidth) {
            $card.Root.Width = $sync.RedesignCardWidth
        }
        Set-WinUtilRedesignCardTexts -Item $item -Card $card
        Set-WinUtilRedesignIcon -Parts $card -Item $item -ImagePath $sync.RedesignIconFiles[$item.Short.ToLowerInvariant()]
        Set-WinUtilRedesignCardPaint -Card $card -Selected $false -Focused $false
        if (-not (Test-WinUtilRedesignProgramVisible -Item $item -Query $query -Filter $sync.RedesignProgFilter)) {
            $card.Root.Visibility = [Windows.Visibility]::Collapsed
        }
        $null = $sync.WPFRedesignProgGrid.Children.Add($card.Root)
        # Something chosen before the card existed (an import, a preset, a kit) is applied now
        if ($sync.selectedApps.Contains($key)) {
            $card.Check.IsChecked = $true
        }

        $built++
        if ($clock.ElapsedMilliseconds -ge $budgetMs) {
            break
        }
    }

    if ($built -lt $keys.Count) {
        $sync.BackgroundQueues['ProgramCards'].Queue.Enqueue([pscustomobject]@{ Keys = @($keys[$built..($keys.Count - 1)]) })
    }
}

function Complete-WinUtilRedesignPrograms {
    <#
    .SYNOPSIS
        Runs once every program card exists: filters, counts, icons from the network, installed marks.
    #>

    $sync.RedesignProgramsReady = $true
    Update-WinUtilRedesignProgramLayout
    Update-WinUtilRedesignProgramFilter
    Update-WinUtilRedesignProgramSelection
    Start-WinUtilRedesignIconFetch -Items (Get-WinUtilRedesignProgramItems)
    Update-WinUtilRedesignInstalled
}

function Initialize-WinUtilRedesignProgramControls {
    <#
    .SYNOPSIS
        Wires the controls of the Programs tab that are in the XAML: kits, action bar, menu, details, kit dialog.

    .DESCRIPTION
        Run once. Every action either calls the redesign's own functions or presses an upstream
        button by name through Invoke-WPFButton, so the work is done by the code that was there.
    #>

    if ($sync.RedesignProgramControlsWired) {
        return
    }
    $sync.RedesignProgramControlsWired = $true

    $sync.WPFRedesignKitImport.Add_Click({ Invoke-WinUtilRedesignKitImport })
    $sync.WPFRedesignKitCreate.Add_Click({ Show-WinUtilRedesignKitDialog })

    $sync.WPFRedesignDockClear.Add_Click({ Invoke-WPFButton 'WPFClearInstallSelection' })
    $sync.WPFRedesignDockInstall.Add_Click({ Invoke-WPFButton 'WPFInstall' })
    $sync.WPFRedesignDockMore.Add_Click({
        Update-WinUtilRedesignManagerMenu
        $sync.WPFRedesignDockMenu.IsOpen = -not $sync.WPFRedesignDockMenu.IsOpen
    })
    $sync.WPFRedesignDockDone.Add_Click({
        # The same thing a button press does before anything else: clear the bar of a finished job
        if (-not $sync.ActiveJob) {
            Step-WinUtilJob -Hide
            if ($sync.RedesignRunOk) {
                Invoke-WPFButton 'WPFClearInstallSelection'
            }
        }
    })

    $sync.WPFRedesignMenuUninstall.Add_Click({
        $sync.WPFRedesignDockMenu.IsOpen = $false
        Invoke-WPFButton 'WPFUninstall'
    })
    $sync.WPFRedesignMenuUpgradeAll.Add_Click({
        $sync.WPFRedesignDockMenu.IsOpen = $false
        Invoke-WPFButton 'WPFInstallUpgrade'
    })
    $sync.WPFRedesignMenuSelectInstalled.Add_Click({
        $sync.WPFRedesignDockMenu.IsOpen = $false
        if ($null -ne $sync.RedesignInstalled) {
            foreach ($key in $sync.RedesignInstalled) {
                Set-WinUtilRedesignProgramSelected -Key $key -Selected $true
            }
        } else {
            Invoke-WPFButton 'WPFGetInstalled'
        }
    })
    $sync.WPFRedesignMenuWinget.Add_Click({
        # The upstream radio button keeps $sync.preferences.packagemanager, so it is the one set
        if ($sync.WingetRadioButton) { $sync.WingetRadioButton.IsChecked = $true } else { $sync.preferences.packagemanager = 'Winget' }
        Update-WinUtilRedesignManagerMenu
        Update-WinUtilRedesignDock
        Update-WinUtilRedesignInstalled
    })
    $sync.WPFRedesignMenuChoco.Add_Click({
        if ($sync.ChocoRadioButton) { $sync.ChocoRadioButton.IsChecked = $true } else { $sync.preferences.packagemanager = 'Choco' }
        Update-WinUtilRedesignManagerMenu
        Update-WinUtilRedesignDock
        Update-WinUtilRedesignInstalled
    })

    $sync.WPFRedesignDrawerClose.Add_Click({ Close-WinUtilRedesignProgramDetail })
    $sync.WPFRedesignDrawerAction.Add_Click({
        $key = $sync.RedesignDetailKey
        if ($key) {
            Set-WinUtilRedesignProgramSelected -Key $key -Selected (-not $sync.selectedApps.Contains($key))
        }
    })
    $sync.WPFRedesignDrawerWebsite.Add_Click({
        $link = [string]$this.Tag
        try {
            $uri = [uri]$link
            if ($uri.IsAbsoluteUri -and $uri.Scheme -in 'http', 'https') {
                Start-Process $uri.AbsoluteUri
            }
        } catch {
            Write-WinUtilLog -Level 'WARN' -Component 'Programs' -Message "Could not open '$link': $($_.Exception.Message)"
        }
    })

    $sync.WPFRedesignKdCancel.Add_Click({ Hide-WinUtilRedesignKitDialog })
    $sync.WPFRedesignKdSave.Add_Click({ Save-WinUtilRedesignKitFromDialog })
    $sync.WPFRedesignKdName.Add_TextChanged({
        $sync.WPFRedesignKdError.Visibility = [Windows.Visibility]::Collapsed
        $sync.WPFRedesignKdName.BorderBrush = New-WinUtilRedesignBrush '#2A3A5C'
    })
    $sync.WPFRedesignKitScrim.Add_PreviewKeyDown({
        param($eventSender, $keyArgs)
        $null = $eventSender
        if ($keyArgs.Key -eq [Windows.Input.Key]::Escape) {
            Hide-WinUtilRedesignKitDialog
            $keyArgs.Handled = $true
        } elseif ($keyArgs.Key -eq [Windows.Input.Key]::Return -and $keyArgs.OriginalSource -is [Windows.Controls.TextBox]) {
            Save-WinUtilRedesignKitFromDialog
            $keyArgs.Handled = $true
        }
    })

    $sync.WPFRedesignProgScroll.Add_SizeChanged({ Update-WinUtilRedesignProgramLayout })

    # An install, uninstall or upgrade job ends when the shared progress bar reaches 100
    $sync.WPFTweaksProgressValue.Add_ValueChanged({
        Update-WinUtilRedesignInstallRunStatus
    })
}
