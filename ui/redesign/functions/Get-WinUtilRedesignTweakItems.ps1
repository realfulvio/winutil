function Test-WinUtilRedesignCardEntry {
    <#
    .SYNOPSIS
        Tells whether a tweaks.json entry is shown as a selectable card.

    .DESCRIPTION
        Mirrors the entry types Invoke-WPFUIElements builds a dedicated control for. Anything
        else is a plain checkbox tweak, which is applied in one go with the Apply button.
    #>
    param(
        [Parameter(Mandatory)]
        $Entry
    )

    return ($Entry.Type -notin @("Toggle", "ToggleButton", "Combobox", "Button", "RadioButton", "Note"))
}

function Get-WinUtilRedesignTweakItems {
    <#
    .SYNOPSIS
        Builds, once, the list of tweaks the redesign shows as cards.

    .DESCRIPTION
        Everything that is a fact comes from the repo data: the tweak's own config entry decides
        how many registry values and services it touches, whether it can be undone (undo script,
        original registry value or original service type) and whether it is risky (upstream's
        "CAUTION" category). The Standard preset decides which ones are recommended. Only the
        wording and the icon come from strings.json. A tweak without an entry there still gets a
        card, using the Content and Description of tweaks.json.
    #>

    if ($sync.RedesignItems) {
        return $sync.RedesignItems
    }

    $texts = $sync.configs.redesignstrings.tweaks
    $standard = @($sync.configs.preset.Standard)
    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($property in $sync.configs.tweaks.PSObject.Properties) {
        $entry = $property.Value
        if (-not (Test-WinUtilRedesignCardEntry -Entry $entry)) {
            continue
        }

        $name = $property.Name
        $text = $texts.$name
        $registry = @($entry.registry | Where-Object { $_ })
        $services = @($entry.service | Where-Object { $_ })
        $hasUndoScript = $entry.UndoScript -and @($entry.UndoScript).Count -gt 0
        $hasOriginalRegistry = @($registry | Where-Object { $null -ne $_.OriginalValue }).Count -gt 0
        $hasOriginalService = @($services | Where-Object { $null -ne $_.OriginalType }).Count -gt 0

        $caution = [string]$entry.category -like "*CAUTION*"
        if ($text -and $null -ne $text.caution) {
            $caution = [bool]$text.caution
        }
        $category = if ($text -and $text.cat) { [string]$text.cat } elseif ($caution) { "advanced" } else { "system" }
        $icon = if ($text -and $text.icon) { [string]$text.icon } else { "E713" }

        $items.Add([pscustomobject]@{
            Name        = $name
            Category    = $category
            Recommended = ($standard -contains $name)
            Caution     = $caution
            Icon        = [string][char][Convert]::ToInt32($icon, 16)
            Undoable    = [bool]($hasUndoScript -or $hasOriginalRegistry -or $hasOriginalService)
            Services    = $services.Count
            Registry    = $registry.Count
            Text        = @{ en = $text.en; it = $text.it }
            Content     = [string]$entry.Content
            Description = [string]$entry.Description
        })
    }

    $sync.RedesignItems = $items
    return $items
}

function Get-WinUtilRedesignItemText {
    <#
    .SYNOPSIS
        Returns name, description and details of a tweak card in the current language.

    .DESCRIPTION
        Falls back to English and then to the Content and Description of tweaks.json, so a tweak
        added upstream without redesign strings still has a readable card. The detail fields are
        left empty rather than invented.
    #>
    param(
        [Parameter(Mandatory)]
        $Item
    )

    $language = $sync.preferences.language
    if (-not $language) {
        $language = "en"
    }

    $text = $Item.Text.$language
    if (-not $text) {
        $text = $Item.Text.en
    }
    if ($text) {
        return $text
    }
    return [pscustomobject]@{
        name = $Item.Content
        desc = $Item.Description
        what = ""
        eff  = ""
        warn = ""
    }
}
