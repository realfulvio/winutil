function ConvertTo-WinUtilModernInterface {
    <#
    .SYNOPSIS
        Builds the optional personal WPF shell without editing upstream sources.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Xaml,
        [Parameter(Mandatory)][psobject]$Themes
    )

    $document = [xml]$Xaml
    $namespace = $document.DocumentElement.NamespaceURI
    $main = $document.SelectSingleNode('//*[@Name="WPFMainGrid"]')
    $nav = $document.SelectSingleNode('//*[@Name="NavDockPanel"]')
    $tools = $document.SelectSingleNode('//*[@Name="GridBesideNavDockPanel"]')
    $tabs = $document.SelectSingleNode('//*[@Name="WPFTabNav"]')
    if (-not ($main -and $nav -and $tools -and $tabs)) {
        throw 'Upstream shell contract changed: modern interface requires WPFMainGrid, NavDockPanel, GridBesideNavDockPanel and WPFTabNav.'
    }
    $header = $nav.ParentNode
    if ($header -ne $tools.ParentNode -or $header.ParentNode -ne $main) {
        throw 'Upstream header topology changed. Review the modern adapter before building.'
    }

    # Keep every existing named control and all content; only relocate the shell.
    $columns = $main.SelectSingleNode('./*[local-name()="Grid.ColumnDefinitions"]')
    if ($columns.ChildNodes.Count -ne 1) {
        throw 'Upstream main grid columns changed. Review the modern adapter before building.'
    }
    $sidebarColumn = $document.CreateElement('ColumnDefinition', $namespace)
    $sidebarColumn.SetAttribute('Width', '208')
    $null = $columns.PrependChild($sidebarColumn)
    $null = $header.RemoveChild($nav)
    $nav.SetAttribute('Orientation', 'Vertical')
    $nav.SetAttribute('Grid.Row', '1')
    $nav.SetAttribute('Grid.RowSpan', '2')
    $nav.SetAttribute('VerticalAlignment', 'Top')
    $nav.SetAttribute('Margin', '12,16,12,12')
    $null = $main.AppendChild($nav)
    $header.SetAttribute('Grid.Column', '1')
    $header.SetAttribute('Margin', '0,8,12,8')
    $headerColumns = $header.SelectSingleNode('./*[local-name()="Grid.ColumnDefinitions"]')
    $headerColumns.FirstChild.SetAttribute('Width', '0')
    $tabs.SetAttribute('Grid.Column', '1')
    $tabs.SetAttribute('Margin', '0,0,12,12')
    foreach ($name in @('WPFOfflineBanner', 'WPFTweaksProgressBar')) {
        $document.SelectSingleNode("//*[@Name='$name']").SetAttribute('Grid.ColumnSpan', '2')
    }
    $document.DocumentElement.SetAttribute('Title', 'WinUtil - Personal interface (unofficial fork)')

    $logo = $document.SelectSingleNode('//*[@Name="NavLogoPanel"]')
    $logo.SetAttribute('Margin', '8,0,0,20')
    $brand = $document.CreateElement('TextBlock', $namespace)
    $brand.SetAttribute('Text', 'WINUTIL / PERSONAL')
    $brand.SetAttribute('FontSize', '12')
    $brand.SetAttribute('FontWeight', 'Bold')
    $brand.SetAttribute('VerticalAlignment', 'Center')
    $brand.SetAttribute('Foreground', '{DynamicResource MainForegroundColor}')
    $null = $logo.AppendChild($brand)

    foreach ($button in $nav.SelectNodes('./*[local-name()="ToggleButton"]')) {
        $button.SetAttribute('Margin', '0,0,0,8')
        $button.SetAttribute('Width', '184')
        $button.SetAttribute('MinWidth', '184')
        $button.SetAttribute('Height', '44')
        $button.SetAttribute('HorizontalContentAlignment', 'Left')
    }
    $navStyle = $document.SelectSingleNode('//*[local-name()="Style"][@*[local-name()="Key"]="TabToggleButton"]')
    $presenter = $navStyle.SelectSingleNode('.//*[local-name()="ContentPresenter"]')
    $presenter.SetAttribute('HorizontalAlignment', 'Left')
    $presenter.SetAttribute('Margin', '16,2,12,2')
    # Flat focus/selection surfaces keep the existing template parts and triggers.
    foreach ($effect in @($navStyle.SelectNodes('.//*[local-name()="Setter"][@Property="Effect"]'))) {
        $null = $effect.ParentNode.RemoveChild($effect)
    }

    # Clone the theme object: callers and config/themes.json remain unchanged.
    $modernThemes = $Themes | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $overrides = Get-Content -LiteralPath "$PSScriptRoot/tokens.json" -Raw | ConvertFrom-Json
    foreach ($group in $overrides.PSObject.Properties) {
        foreach ($property in $group.Value.PSObject.Properties) {
            if (-not $modernThemes.($group.Name).PSObject.Properties[$property.Name]) {
                throw "Upstream theme contract changed: missing $($group.Name).$($property.Name)."
            }
            $modernThemes.($group.Name).($property.Name) = $property.Value
        }
    }
    [pscustomobject]@{ Xaml = $document.OuterXml; Themes = $modernThemes }
}
