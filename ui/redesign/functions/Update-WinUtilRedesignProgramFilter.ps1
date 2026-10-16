function Test-WinUtilRedesignProgramVisible {
    <#
    .SYNOPSIS
        Whether a program passes the chip that is active and the search text.

    .PARAMETER Item
        An entry of Get-WinUtilRedesignProgramItems.

    .PARAMETER Query
        The search text; empty matches everything. The name, the description in both languages,
        the key and the package IDs are searched, ignoring case.

    .PARAMETER Filter
        all, installed, or a category of config/applications.json.
    #>
    param(
        [Parameter(Mandatory)]$Item,
        [string]$Query = '',
        [string]$Filter = 'all'
    )

    if ($Filter -eq 'installed') {
        if ($null -eq $sync.RedesignInstalled -or -not $sync.RedesignInstalled.Contains($Item.Key)) {
            return $false
        }
    } elseif ($Filter -ne 'all' -and $Item.Category -ne $Filter) {
        return $false
    }

    if ($Query) {
        $comparison = [StringComparison]::OrdinalIgnoreCase
        $haystack = "$($Item.Name)`n$($Item.DescIt)`n$($Item.DescEn)`n$($Item.Short)`n$($Item.WingetId)`n$($Item.ChocoId)"
        return $haystack.IndexOf($Query, $comparison) -ge 0
    }
    return $true
}

function Update-WinUtilRedesignProgramFilter {
    <#
    .SYNOPSIS
        Shows the program cards that match the active chip and the search text.

    .DESCRIPTION
        Both have to pass: the search narrows the chip, as in the design. The chips show which
        one is active and how many programs they hold.

    .PARAMETER SearchString
        The text to look for. When omitted the search box is read. Matching is literal.
    #>
    param(
        [string]$SearchString
    )

    if (-not $sync.RedesignProgramsReady) {
        return
    }

    if (-not $PSBoundParameters.ContainsKey('SearchString')) {
        $SearchString = if ($sync.SearchBar) { $sync.SearchBar.Text } else { '' }
    }
    $query = $SearchString.Trim()
    $filter = if ($sync.RedesignProgFilter) { $sync.RedesignProgFilter } else { 'all' }
    $visibleCount = 0

    foreach ($item in (Get-WinUtilRedesignProgramItems)) {
        $card = $sync.RedesignProgramCards[$item.Key]
        if (-not $card) { continue }
        $visible = Test-WinUtilRedesignProgramVisible -Item $item -Query $query -Filter $filter
        $card.Root.Visibility = if ($visible) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
        if ($visible) { $visibleCount++ }
    }

    foreach ($chip in $sync.RedesignProgChips.GetEnumerator()) {
        $chip.Value.Button.IsChecked = ($chip.Key -eq $filter)
    }

    if ($visibleCount -gt 0) {
        $sync.WPFRedesignProgNoResults.Visibility = [Windows.Visibility]::Collapsed
    } else {
        $sync.WPFRedesignProgNoResults.Text = if ($query) {
            Get-WinUtilRedesignText -Key 'progNoResults' -FormatArgs @($query)
        } elseif ($filter -eq 'installed') {
            Get-WinUtilRedesignText -Key 'progNoInstalled'
        } else {
            ''
        }
        $sync.WPFRedesignProgNoResults.Visibility = if ($sync.WPFRedesignProgNoResults.Text) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    }
}

function Set-WinUtilRedesignProgramFilter {
    <#
    .SYNOPSIS
        Selects a category chip and clears the search.

    .PARAMETER Filter
        all, installed, or a category of config/applications.json. Clicking the active chip
        again goes back to all.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Filter
    )

    if ($Filter -eq $sync.RedesignProgFilter -and $Filter -ne 'all') {
        $Filter = 'all'
    }
    if ($Filter -eq 'installed' -and $null -eq $sync.RedesignInstalled) {
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignText -Key 'installedNoManager') -Warning
    }
    $sync.RedesignProgFilter = $Filter
    if ($sync.SearchBar.Text) {
        $sync.SearchBar.Text = ''
    }
    Update-WinUtilRedesignProgramFilter -SearchString ''
}

function Initialize-WinUtilRedesignProgramChips {
    <#
    .SYNOPSIS
        Builds the category chips of the catalog: all, one per category, and the installed ones.

    .DESCRIPTION
        The categories are the ones config/applications.json uses, in the order of
        ui/redesign/programs.json; a category with no program gets no chip.
    #>

    $panel = $sync.WPFRedesignProgChips
    $panel.Children.Clear()
    $sync.RedesignProgChips = @{}

    $items = Get-WinUtilRedesignProgramItems
    $used = @($items | ForEach-Object Category | Sort-Object -Unique)
    $order = @('all')
    $order += @($sync.configs.redesignprograms.categories.PSObject.Properties.Name | Where-Object { $_ -in $used })
    $order += @($used | Where-Object { $_ -notin $order })
    $order += 'installed'

    foreach ($filter in $order) {
        $xaml = @'
<ToggleButton xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
              xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Style="{DynamicResource RdChipStyle}">
    <StackPanel Orientation="Horizontal">
        <TextBlock x:Name="ChipText" Foreground="{Binding Foreground, RelativeSource={RelativeSource AncestorType=ToggleButton}}"/>
        <TextBlock x:Name="ChipCount" Opacity="0.75" Margin="6,0,0,0" Foreground="{Binding Foreground, RelativeSource={RelativeSource AncestorType=ToggleButton}}"/>
    </StackPanel>
</ToggleButton>
'@
        $button = [Windows.Markup.XamlReader]::Parse($xaml)
        $button.Tag = $filter
        $button.Add_Click({
            Set-WinUtilRedesignProgramFilter -Filter $this.Tag
        })
        $null = $panel.Children.Add($button)
        $sync.RedesignProgChips[$filter] = @{
            Button = $button
            Text   = $button.FindName('ChipText')
            Count  = $button.FindName('ChipCount')
        }
    }
    Update-WinUtilRedesignProgramChipTexts
}

function Update-WinUtilRedesignProgramChipTexts {
    <#
    .SYNOPSIS
        Writes the name and the count of every chip, in the current language.
    #>

    if (-not $sync.RedesignProgChips) {
        return
    }
    $items = Get-WinUtilRedesignProgramItems
    foreach ($chip in $sync.RedesignProgChips.GetEnumerator()) {
        $filter = $chip.Key
        switch ($filter) {
            'all' {
                $name = Get-WinUtilRedesignText -Key 'chipAll'
                $count = $items.Count
            }
            'installed' {
                $name = Get-WinUtilRedesignText -Key 'chipInstalled'
                $count = if ($null -ne $sync.RedesignInstalled) { $sync.RedesignInstalled.Count } else { $null }
            }
            default {
                $name = Get-WinUtilRedesignCategoryName -Category $filter
                $count = @($items | Where-Object { $_.Category -eq $filter }).Count
            }
        }
        $chip.Value.Text.Text = $name
        $chip.Value.Count.Text = if ($null -ne $count) { [string]$count } else { '' }
        [System.Windows.Automation.AutomationProperties]::SetName($chip.Value.Button, [string]$name)
    }
}
