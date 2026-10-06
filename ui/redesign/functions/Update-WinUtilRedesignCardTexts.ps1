function Update-WinUtilRedesignCardTexts {
    <#
    .SYNOPSIS
        Writes the current language into every tweak card and re-sorts the list by name.
    #>

    if (-not $sync.RedesignCardsReady) {
        return
    }

    $category = @{
        privacy  = Get-WinUtilRedesignText -Key "catPrivacy"
        system   = Get-WinUtilRedesignText -Key "catSystem"
        advanced = Get-WinUtilRedesignText -Key "catAdvanced"
    }
    $recommended = @{ Back = "#10304A"; Border = "#1C4A70"; Fore = "#7FD3FF"; Glyph = [string][char]0xE734; Key = "tagRec" }
    $safe = @{ Back = "#0F2E2A"; Border = "#1D5A4A"; Fore = "#6FD6A0"; Glyph = ""; Key = "tagSafe" }
    $caution = @{ Back = "#3A2C12"; Border = "#6B531C"; Fore = "#F5B94A"; Glyph = [string][char]0xE7BA; Key = "tagCaution" }

    foreach ($item in $sync.RedesignItems) {
        $card = $sync.RedesignCards[$item.Name]
        $text = Get-WinUtilRedesignItemText -Item $item
        $card.Title.Text = $text.name
        $card.Desc.Text = $text.desc
        $card.Icon.Text = $item.Icon
        $card.CatText.Text = $category[$item.Category]
        [System.Windows.Automation.AutomationProperties]::SetName($card.Check, [string]$text.name)
        [System.Windows.Automation.AutomationProperties]::SetName($card.Body, [string]$text.name)

        $state = if ($item.Caution) { $caution } elseif ($item.Recommended) { $recommended } else { $safe }
        $card.StateTag.Background = New-WinUtilRedesignBrush $state.Back
        $card.StateTag.BorderBrush = New-WinUtilRedesignBrush $state.Border
        $card.StateText.Foreground = New-WinUtilRedesignBrush $state.Fore
        $card.StateText.Text = Get-WinUtilRedesignText -Key $state.Key
        $card.StateGlyph.Foreground = New-WinUtilRedesignBrush $state.Fore
        $card.StateGlyph.Text = $state.Glyph
        $card.StateGlyph.Visibility = if ($state.Glyph) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    }

    # The list is alphabetical by what the user reads, so the order follows the language
    $list = $sync.WPFRedesignCardList
    $sorted = @($sync.RedesignItems | Sort-Object { (Get-WinUtilRedesignItemText -Item $_).name })
    $list.Children.Clear()
    foreach ($item in $sorted) {
        $null = $list.Children.Add($sync.RedesignCards[$item.Name].Root)
    }
}
