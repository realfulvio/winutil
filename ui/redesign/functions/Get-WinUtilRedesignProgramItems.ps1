function Get-WinUtilRedesignProgramItems {
    <#
    .SYNOPSIS
        Builds, once, the list of programs the redesign shows as cards.

    .DESCRIPTION
        Everything that is a fact comes from config/applications.json (name, category, package
        IDs, website, open-source flag). The short Italian line, the icon outline to use and the
        category names come from ui/redesign/programs.json. The English line is the first sentence
        of the upstream description, so an application never shows an empty card.

    .OUTPUTS
        Objects with Key, Name, Category, WingetId, ChocoId, Link, Foss, DescEn, DescIt and Slug,
        sorted by name.
    #>

    if ($sync.RedesignProgramItems) {
        return $sync.RedesignProgramItems
    }

    $extras = $sync.configs.redesignprograms.apps
    $items = [System.Collections.Generic.List[object]]::new()

    foreach ($entry in $sync.configs.applicationsHashtable.GetEnumerator()) {
        $app = $entry.Value
        $key = [string]$entry.Key
        $short = $key -replace '^WPFInstall', ''
        $extra = $extras.$short

        $english = ([string]$app.description).Trim()
        $firstSentence = [regex]::Match($english, '^.*?[.!?](?=\s|$)').Value
        if ($firstSentence) { $english = $firstSentence }

        $wingetId = ([string]$app.winget).Trim()
        if ($wingetId -eq 'na') { $wingetId = '' }
        $chocoId = ([string]$app.choco).Trim()
        if ($chocoId -eq 'na') { $chocoId = '' }

        $items.Add([pscustomobject]@{
            Key      = $key
            Short    = $short
            Name     = ([string]$app.content).Trim()
            Category = [string]$app.category
            WingetId = $wingetId
            ChocoId  = $chocoId
            Link     = [string]$app.link
            Foss     = [bool]$app.foss
            DescEn   = $english
            DescIt   = if ($extra -and $extra.it) { [string]$extra.it } else { $english }
            Slug     = if ($extra -and $extra.icon) { [string]$extra.icon } else { '' }
        })
    }

    $sync.RedesignProgramItems = @($items | Sort-Object { $_.Name.TrimStart('.').ToLowerInvariant() })
    $sync.RedesignProgramItemMap = @{}
    foreach ($item in $sync.RedesignProgramItems) {
        $sync.RedesignProgramItemMap[$item.Key] = $item
    }
    return $sync.RedesignProgramItems
}

function Get-WinUtilRedesignProgramText {
    <#
    .SYNOPSIS
        The line shown under a program's name, in the language of the interface.

    .PARAMETER Item
        An entry of Get-WinUtilRedesignProgramItems.
    #>
    param(
        [Parameter(Mandatory)]
        $Item
    )

    if ($sync.preferences.language -eq 'it') {
        return $Item.DescIt
    }
    return $Item.DescEn
}

function Get-WinUtilRedesignCategoryName {
    <#
    .SYNOPSIS
        The name of an application category in the language of the interface.

    .PARAMETER Category
        A category of config/applications.json, such as "Multimedia Tools".
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Category
    )

    $entry = $sync.configs.redesignprograms.categories.$Category
    if (-not $entry) {
        return $Category
    }
    $language = if ($sync.preferences.language -eq 'it') { 'it' } else { 'en' }
    $name = $entry.$language
    if ($name) { return [string]$name }
    return $Category
}
