function ConvertTo-WinUtilRedesignInterface {
    <#
    .SYNOPSIS
        Builds the optional "design D" WPF interface at compile time.

    .DESCRIPTION
        Takes the upstream xaml/inputXML.xaml and returns the XAML for the redesigned window.
        Upstream sources are never edited. Every named control the existing functions rely on is
        kept: the window chrome (search box, theme/settings/window buttons, tab TabControl,
        progress bar, tweak buttons) is lifted out of the upstream tree and placed into the new
        layout in ui/redesign/shell.xaml, and only the Tweaks tab content is replaced.
        Throws when the upstream XAML no longer has the controls this adapter depends on, so a
        change upstream fails the build instead of producing a half-working window.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Xaml
    )

    $document = [xml]$Xaml
    $uiPath = $PSScriptRoot

    $required = @(
        'WPFMainGrid', 'WPFTabNav', 'WPFTab2', 'WPFTweaksProgressBar', 'WPFOfflineBanner',
        'SearchBar', 'SearchBarIcon', 'SearchBarClearButton', 'ThemeButton',
        'WPFstandard', 'WPFminimal', 'WPFAdvanced', 'WPFGetInstalledTweaks', 'WPFAppxRemoval',
        'WPFClearTweaksSelection', 'WPFTweaksbutton', 'WPFUndoall', 'tweakspanel'
    )
    foreach ($name in $required) {
        if (-not $document.SelectSingleNode("//*[@Name='$name']")) {
            throw "Upstream XAML contract changed: the redesign adapter requires the control '$name'."
        }
    }

    function Read-RedesignXml([string]$FileName) {
        $fragment = [xml]::new()
        $fragment.LoadXml((Get-Content -LiteralPath (Join-Path $uiPath $FileName) -Raw -Encoding UTF8))
        $fragment
    }

    # Imports a node into the upstream document. The window root already declares the XAML
    # namespaces, and a repeated declaration on an imported element makes XamlReader fail.
    function Import-RedesignNode($Node) {
        $imported = $document.ImportNode($Node, $true)
        if ($imported.NodeType -eq 'Element') {
            foreach ($attribute in @($imported.Attributes)) {
                if ($attribute.Name -eq 'xmlns' -or $attribute.Name -like 'xmlns:*') {
                    $null = $imported.Attributes.Remove($attribute)
                }
            }
        }
        $imported
    }
    # Returns a named upstream node after detaching it, so it can be placed somewhere else
    function Get-UpstreamNode([string]$Name) {
        $node = $document.SelectSingleNode("//*[@Name='$Name']")
        $null = $node.ParentNode.RemoveChild($node)
        $node
    }

    function Set-RedesignAttributes($Node, [hashtable]$Set, [string[]]$Remove = @()) {
        foreach ($attribute in $Remove) { $null = $Node.RemoveAttribute($attribute) }
        foreach ($key in $Set.Keys) { $Node.SetAttribute($key, [string]$Set[$key]) }
    }

    # Puts an imported node where a Slot placeholder is, carrying over the placeholder's layout attributes
    function Set-RedesignSlot($Target, [string]$Slot, $Node) {
        $placeholder = $Target.SelectSingleNode("//*[@Slot='$Slot']")
        if (-not $placeholder) { throw "Redesign layout has no slot '$Slot'." }
        $imported = $Target.OwnerDocument.ImportNode($Node, $true)
        foreach ($attribute in @($placeholder.Attributes)) {
            if ($attribute.Name -ne 'Slot') { $imported.SetAttribute($attribute.Name, $attribute.Value) }
        }
        $null = $placeholder.ParentNode.ReplaceChild($imported, $placeholder)
    }

    # --- Lift the upstream controls out of the old layout -------------------------------------
    $offlineBanner = Get-UpstreamNode 'WPFOfflineBanner'
    $clearSearch = Get-UpstreamNode 'SearchBarClearButton'
    $searchBorder = ($document.SelectSingleNode("//*[@Name='SearchBar']")).ParentNode.ParentNode
    if ($searchBorder.LocalName -ne 'Border') {
        throw 'Upstream header topology changed: the search box is no longer wrapped in a Border.'
    }
    $null = $searchBorder.ParentNode.RemoveChild($searchBorder)
    $windowButtons = ($document.SelectSingleNode("//*[@Name='ThemeButton']")).ParentNode
    if ($windowButtons.LocalName -ne 'StackPanel') {
        throw 'Upstream header topology changed: the theme/settings/window buttons are no longer in a StackPanel.'
    }
    $null = $windowButtons.ParentNode.RemoveChild($windowButtons)
    $progress = Get-UpstreamNode 'WPFTweaksProgressBar'

    $tweakButtons = @{}
    foreach ($name in 'WPFstandard', 'WPFminimal', 'WPFAdvanced', 'WPFGetInstalledTweaks', 'WPFAppxRemoval', 'WPFClearTweaksSelection', 'WPFTweaksbutton', 'WPFUndoall') {
        $tweakButtons[$name] = Get-UpstreamNode $name
    }
    $tabNav = Get-UpstreamNode 'WPFTabNav'

    # --- Restyle what moves --------------------------------------------------------------------
    Set-RedesignAttributes $windowButtons @{ Margin = '0' } -Remove @('Grid.Column')
    foreach ($button in $windowButtons.SelectNodes('.//*[local-name()="Button"][@Background]')) {
        $button.SetAttribute('Background', 'Transparent')
    }

    Set-RedesignAttributes $searchBorder @{
        Margin = '0'; Height = '52'; MinWidth = '0'; Background = '#0F182B'
        BorderBrush = '#22304D'; BorderThickness = '1'; CornerRadius = '14'
        Visibility = '{Binding Visibility, ElementName=SearchBar}'
    } -Remove @('Grid.Column', 'VerticalAlignment')
    $searchBox = $searchBorder.SelectSingleNode(".//*[@Name='SearchBar']")
    Set-RedesignAttributes $searchBox @{
        Height = '50'; FontSize = '15'; Background = 'Transparent'; BorderThickness = '0'
        Padding = '46,0,40,0'; VerticalContentAlignment = 'Center'; Effect = '{x:Null}'
    }
    $searchIcon = $searchBorder.SelectSingleNode(".//*[@Name='SearchBarIcon']")
    Set-RedesignAttributes $searchIcon @{
        HorizontalAlignment = 'Left'; Margin = '18,0,0,0'; FontSize = '20'; Foreground = '#9FB0C9'
        FontFamily = 'Segoe Fluent Icons, Segoe MDL2 Assets'
    }
    # Placeholder text: the TextBox has none, so a hint shows while it is empty
    $searchHint = $document.CreateElement('TextBlock', $document.DocumentElement.NamespaceURI)
    Set-RedesignAttributes $searchHint @{
        Name = 'WPFRedesignSearchHint'; IsHitTestVisible = 'False'; Margin = '46,0,0,0'
        VerticalAlignment = 'Center'; FontSize = '15'; Foreground = '#9FB0C9'; Text = ''
    }
    # Imported through Import-RedesignNode so no element carries an xmlns of its own; XamlReader rejects one
    $hintStyle = $document.CreateElement('TextBlock.Style', $document.DocumentElement.NamespaceURI)
    $null = $searchHint.AppendChild($hintStyle)
    $hintStyleSource = [xml]@'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="TextBlock">
    <Setter Property="Visibility" Value="Collapsed"/>
    <Style.Triggers>
        <DataTrigger Binding="{Binding Text, ElementName=SearchBar}" Value="">
            <Setter Property="Visibility" Value="Visible"/>
        </DataTrigger>
    </Style.Triggers>
</Style>
'@
    $null = $hintStyle.AppendChild((Import-RedesignNode $hintStyleSource.DocumentElement))
    $searchGrid = $searchBox.ParentNode
    $null = $searchGrid.InsertAfter($searchHint, $searchBox)
    Set-RedesignAttributes $clearSearch @{ Margin = '0,0,12,0'; VerticalAlignment = 'Center'; HorizontalAlignment = 'Right' } -Remove @('Grid.Column')
    # One cell holds the field and its clear button, so they overlap the way they did upstream
    $searchHost = $document.CreateElement('Grid', $document.DocumentElement.NamespaceURI)
    $null = $searchHost.AppendChild($searchBorder)
    $null = $searchHost.AppendChild($clearSearch)

    Set-RedesignAttributes $tabNav @{ Margin = '0' }

    $quick = @{ Height = '44'; Margin = '0,0,10,10'; Padding = '18,0'; Style = '{StaticResource RdSecondaryButtonStyle}' }
    foreach ($name in 'WPFstandard', 'WPFminimal', 'WPFAdvanced', 'WPFGetInstalledTweaks', 'WPFAppxRemoval') {
        Set-RedesignAttributes $tweakButtons[$name] $quick -Remove @('Width', 'Margin')
    }
    Set-RedesignAttributes $tweakButtons['WPFClearTweaksSelection'] @{ Height = '52'; Margin = '0'; Style = '{StaticResource RdSecondaryButtonStyle}' } -Remove @('Width')
    Set-RedesignAttributes $tweakButtons['WPFTweaksbutton'] @{ Height = '52'; Margin = '0'; Style = '{StaticResource RdPrimaryButtonStyle}' } -Remove @('Width')
    Set-RedesignAttributes $tweakButtons['WPFUndoall'] @{
        Height = '44'; Margin = '0,8,0,0'; HorizontalContentAlignment = 'Center'; Style = '{StaticResource RdGhostButtonStyle}'
    } -Remove @('Width')

    # --- Tweaks tab: new content, same TabItem ------------------------------------------------
    $tab2 = $tabNav.SelectSingleNode(".//*[@Name='WPFTab2']")
    while ($tab2.HasChildNodes) { $null = $tab2.RemoveChild($tab2.FirstChild) }
    $tweaksTab = Read-RedesignXml 'tweaks-tab.xaml'
    foreach ($name in $tweakButtons.Keys) {
        if ($name -in 'WPFClearTweaksSelection', 'WPFTweaksbutton', 'WPFUndoall') { continue }
        Set-RedesignSlot -Target $tweaksTab.DocumentElement -Slot $name -Node $tweakButtons[$name]
    }
    $null = $tab2.AppendChild((Import-RedesignNode $tweaksTab.DocumentElement))

    # --- New window layout --------------------------------------------------------------------
    $shell = Read-RedesignXml 'shell.xaml'
    $shellRoot = $shell.DocumentElement
    Set-RedesignSlot -Target $shellRoot -Slot 'Offline' -Node $offlineBanner
    Set-RedesignSlot -Target $shellRoot -Slot 'WindowButtons' -Node $windowButtons
    Set-RedesignSlot -Target $shellRoot -Slot 'TabHost' -Node $tabNav
    Set-RedesignSlot -Target $shellRoot -Slot 'Progress' -Node $progress
    Set-RedesignSlot -Target $shellRoot -Slot 'ClearButton' -Node $tweakButtons['WPFClearTweaksSelection']
    Set-RedesignSlot -Target $shellRoot -Slot 'ApplyButton' -Node $tweakButtons['WPFTweaksbutton']
    Set-RedesignSlot -Target $shellRoot -Slot 'UndoButton' -Node $tweakButtons['WPFUndoall']
    Set-RedesignSlot -Target $shellRoot -Slot 'SearchBox' -Node $searchHost

    $oldMain = $document.SelectSingleNode("//*[@Name='WPFMainGrid']")
    $null = $oldMain.ParentNode.ReplaceChild((Import-RedesignNode $shellRoot), $oldMain)

    # --- Styles and window ---------------------------------------------------------------------
    $styles = Read-RedesignXml 'styles.xaml'
    $resources = $document.SelectSingleNode("//*[local-name()='Window.Resources']")
    foreach ($style in $styles.DocumentElement.ChildNodes) {
        $null = $resources.AppendChild((Import-RedesignNode $style))
    }
    Set-RedesignAttributes $document.DocumentElement @{
        Width = '1280'; Height = '820'; MinWidth = '1100'; MinHeight = '760'
        Background = '#0A0F1C'; FontFamily = 'Segoe UI Variable Text, Segoe UI'
    }

    # --- Checks --------------------------------------------------------------------------------
    $leftover = @($document.SelectNodes('//*[@Slot]'))
    if ($leftover.Count -gt 0) { throw "Redesign layout left $($leftover.Count) unfilled slot(s)." }
    # Names inside a template have their own scope, so only the window-level ones must be unique
    $windowLevel = '//*[@Name][not(ancestor::*[local-name()="ControlTemplate" or local-name()="DataTemplate"])]'
    $duplicates = @($document.SelectNodes($windowLevel) | ForEach-Object { $_.GetAttribute('Name') } | Group-Object | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) { throw "Redesign layout duplicates control name(s): $($duplicates.Name -join ', ')" }

    # [xml] turns character references such as &#xE713; into the characters themselves. Writing
    # them back as references keeps the compiled script ASCII, as upstream's is.
    [regex]::Replace($document.OuterXml, '[\uD800-\uDBFF][\uDC00-\uDFFF]|[^\u0000-\u007F]', {
        param($match)
        '&#x{0:X};' -f [char]::ConvertToUtf32($match.Value, 0)
    })
}

function ConvertTo-WinUtilRedesignThemes {
    <#
    .SYNOPSIS
        Returns a copy of config/themes.json with the design D palette.

    .DESCRIPTION
        The redesign is dark only, so both Light and Dark get the same palette; the upstream
        controls inside the tabs that keep their layout (Install, Config, Updates, ISO, AppX)
        pick it up through the same theme keys they already use. Throws when a key this
        override targets no longer exists upstream.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)][psobject]$Themes
    )

    $copy = $Themes | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $tokens = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tokens.json') -Raw -Encoding UTF8 | ConvertFrom-Json

    foreach ($property in $tokens.shared.PSObject.Properties) {
        if (-not $copy.shared.PSObject.Properties[$property.Name]) {
            throw "Upstream theme contract changed: shared.$($property.Name) no longer exists."
        }
        $copy.shared.($property.Name) = $property.Value
    }
    # Sizes the redesign adds. They live in "shared" so the theme code applies them as numbers,
    # and the wrapped Invoke-WinUtilFontScaling scales the ones named Rd*.
    foreach ($property in $tokens.sharedNew.PSObject.Properties) {
        if ($copy.shared.PSObject.Properties[$property.Name]) {
            throw "Upstream theme contract changed: shared.$($property.Name) now exists upstream; rename the redesign token."
        }
        $copy.shared | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
    }
    foreach ($theme in 'Light', 'Dark') {
        foreach ($property in $tokens.colors.PSObject.Properties) {
            if (-not $copy.$theme.PSObject.Properties[$property.Name]) {
                throw "Upstream theme contract changed: $theme.$($property.Name) no longer exists."
            }
            $copy.$theme.($property.Name) = $property.Value
        }
    }
    $copy
}

function Convert-WinUtilRedesignFunctionSource {
    <#
    .SYNOPSIS
        Renames upstream functions the redesign wraps, so the wrapper can take their name.

    .DESCRIPTION
        The compiled script is one file, so a function defined later replaces one defined
        earlier. To extend an upstream function without copying it, the upstream definition is
        renamed to <Name>Upstream and the redesign defines <Name> and calls it for everything
        it does not change. Throws when the definition is not found exactly once.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string[]]$Name
    )

    foreach ($functionName in $Name) {
        $pattern = "(?m)^function $([regex]::Escape($functionName)) \{"
        $found = [regex]::Matches($Source, $pattern).Count
        if ($found -eq 0) { continue }
        if ($found -gt 1) { throw "Function '$functionName' is defined more than once; cannot wrap it." }
        $Source = [regex]::Replace($Source, $pattern, "function ${functionName}Upstream {")
    }
    $Source
}
