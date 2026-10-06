function Update-WinUtilRedesignFilter {
    <#
    .SYNOPSIS
        Shows the tweak cards that match the active chip, or the search text when there is one.

    .DESCRIPTION
        A search looks at every tweak (name, short description and details in the current
        language, plus the original English name) and ignores the chips, which then show as
        unselected. While a search is active the quick selections and "Other settings" are
        hidden, since the search does not cover them.

    .PARAMETER SearchString
        The text to look for. When omitted the search box is read. Matching is literal.
    #>
    param(
        [string]$SearchString
    )

    if (-not $sync.RedesignCardsReady) {
        return
    }

    if (-not $PSBoundParameters.ContainsKey("SearchString")) {
        $SearchString = if ($sync.SearchBar) { $sync.SearchBar.Text } else { "" }
    }
    $query = $SearchString.Trim()
    $filter = if ($sync.RedesignFilter) { $sync.RedesignFilter } else { "rec" }
    $comparison = [StringComparison]::OrdinalIgnoreCase
    $visibleCount = 0

    foreach ($item in $sync.RedesignItems) {
        if ($query) {
            $text = Get-WinUtilRedesignItemText -Item $item
            $haystack = "$($text.name)`n$($text.desc)`n$($text.what)`n$($item.Content)"
            $visible = $haystack.IndexOf($query, $comparison) -ge 0
        } elseif ($filter -eq "rec") {
            $visible = $item.Recommended
        } else {
            $visible = $item.Category -eq $filter
        }

        $sync.RedesignCards[$item.Name].Root.Visibility = if ($visible) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
        if ($visible) {
            $visibleCount++
        }
    }

    $chips = @{
        rec      = $sync.WPFRedesignChipRec
        privacy  = $sync.WPFRedesignChipPrivacy
        system   = $sync.WPFRedesignChipSystem
        advanced = $sync.WPFRedesignChipAdvanced
    }
    foreach ($chip in $chips.GetEnumerator()) {
        $chip.Value.IsChecked = (-not $query) -and ($chip.Key -eq $filter)
    }

    $sync.WPFRedesignNoResults.Text = Get-WinUtilRedesignText -Key "noResults"
    $sync.WPFRedesignNoResults.Visibility = if ($visibleCount -eq 0) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $outside = if ($query) { [Windows.Visibility]::Collapsed } else { [Windows.Visibility]::Visible }
    $sync.WPFRedesignQuickSection.Visibility = $outside
    $sync.WPFRedesignOtherSection.Visibility = $outside
}

function Set-WinUtilRedesignFilter {
    <#
    .SYNOPSIS
        Selects a filter chip and clears the search.

    .PARAMETER Filter
        rec, privacy, system or advanced.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("rec", "privacy", "system", "advanced")]
        [string]$Filter
    )

    $sync.RedesignFilter = $Filter
    if ($sync.SearchBar.Text) {
        $sync.SearchBar.Text = ""
    }
    Update-WinUtilRedesignFilter -SearchString ""
}
