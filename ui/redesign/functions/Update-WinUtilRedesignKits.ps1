function Get-WinUtilRedesignKitHandlers {
    <#
    .SYNOPSIS
        The event handlers shared by the buttons of every kit card. The kit travels in Tag.
    #>

    if ($null -ne $script:WinUtilRedesignKitHandlers) {
        return $script:WinUtilRedesignKitHandlers
    }

    $script:WinUtilRedesignKitHandlers = @{
        Toggle = { Invoke-WinUtilRedesignKitToggle -Kit $this.Tag }
        Export = { Invoke-WinUtilRedesignKitExport -Kit $this.Tag }
        Delete = { Invoke-WinUtilRedesignKitDelete -Kit $this.Tag }
    }
    return $script:WinUtilRedesignKitHandlers
}

function New-WinUtilRedesignKitCard {
    <#
    .SYNOPSIS
        Builds the colored card of one kit.

    .DESCRIPTION
        A gradient card with a soft highlight, the first four programs as overlapping icons and
        one button that adds the kit to the selection or takes it out again. A custom kit also
        has a dashed outline, a tag, and Export and Delete buttons.

    .PARAMETER Kit
        A kit of Get-WinUtilKits.

    .OUTPUTS
        A hashtable with Root, Toggle and IconParts (the icon tiles, so downloaded icons can be swapped in).
    #>
    param(
        [Parameter(Mandatory)]
        $Kit
    )

    $palette = @($sync.configs.redesignprograms.kitColors)
    $color = $palette[[Math]::Min([Math]::Max([int]$Kit.Color, 0), $palette.Count - 1)]
    $custom = [bool]$Kit.Custom

    $dashed = if ($custom) {
        '<Rectangle RadiusX="16" RadiusY="16" Stroke="#B3FFFFFF" StrokeThickness="1.5" StrokeDashArray="4 3" IsHitTestVisible="False" Margin="1"/>'
    } else { '' }
    $tag = if ($custom) {
        '<Border x:Name="KitTag" Grid.Row="0" HorizontalAlignment="Left" CornerRadius="10" Padding="10,2" Margin="0,0,0,8" Background="#99000000"><TextBlock x:Name="KitTagText" FontSize="{DynamicResource RdFontSmall}" FontWeight="SemiBold" Foreground="White" Background="Transparent"/></Border>'
    } else { '' }
    $actions = if ($custom) {
        @'
            <Grid Grid.Row="4" Margin="0,10,0,0">
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="8"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Button x:Name="KitExport" Grid.Column="0" Style="{DynamicResource RdKitGhostButtonStyle}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE896;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="White" Background="Transparent" Margin="0,1,8,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="KitExportText" Foreground="White" Background="Transparent" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button x:Name="KitDelete" Grid.Column="2" Style="{DynamicResource RdKitGhostButtonStyle}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE74D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Foreground="White" Background="Transparent" Margin="0,1,8,0" VerticalAlignment="Center"/>
                        <TextBlock x:Name="KitDeleteText" Foreground="White" Background="Transparent" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </Grid>
'@
    } else { '' }

    # The outline of a custom kit is drawn on the card itself, outside the padding of the content
    $xaml = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="KitRoot" Width="300" Margin="0,0,14,14" CornerRadius="16" BorderThickness="1" BorderBrush="#4DFFFFFF" ClipToBounds="True">
    <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="$($color.from)" Offset="0"/>
            <GradientStop Color="$($color.to)" Offset="1"/>
        </LinearGradientBrush>
    </Border.Background>
    <Grid>
        <Ellipse Width="220" Height="220" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,-110,-90,0" IsHitTestVisible="False">
            <Ellipse.Fill>
                <RadialGradientBrush>
                    <GradientStop Color="#33FFFFFF" Offset="0"/>
                    <GradientStop Color="#00FFFFFF" Offset="0.65"/>
                </RadialGradientBrush>
            </Ellipse.Fill>
        </Ellipse>
        $dashed
        <Grid Margin="18,16,18,14">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            $tag
            <TextBlock x:Name="KitTitle" Grid.Row="1" FontSize="{DynamicResource RdFontLarge}" FontWeight="ExtraBold" Foreground="White" Background="Transparent" TextWrapping="Wrap"/>
            <TextBlock x:Name="KitDesc" Grid.Row="2" FontSize="{DynamicResource RdFontSmall}" Foreground="#F2FFFFFF" Background="Transparent" TextWrapping="Wrap" MinHeight="36" Margin="0,4,0,12"/>
            <Grid Grid.Row="3">
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel x:Name="KitIcons" Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center"/>
                <Button x:Name="KitToggle" Grid.Column="1" Style="{DynamicResource RdKitButtonStyle}"/>
            </Grid>
            $actions
        </Grid>
    </Grid>
</Border>
"@
    $root = [Windows.Markup.XamlReader]::Parse($xaml)
    $handlers = Get-WinUtilRedesignKitHandlers

    $card = @{
        Root      = $root
        Title     = $root.FindName('KitTitle')
        Desc      = $root.FindName('KitDesc')
        Toggle    = $root.FindName('KitToggle')
        Icons     = $root.FindName('KitIcons')
        IconParts = [System.Collections.Generic.List[object]]::new()
    }
    $card.Title.Text = $Kit.Name
    $card.Desc.Text = if ($Kit.Description) { $Kit.Description } else { Get-WinUtilRedesignText -Key 'kitPrograms' -FormatArgs @($Kit.AppKeys.Count) }
    $card.Toggle.Tag = $Kit
    $card.Toggle.Add_Click($handlers.Toggle)
    [System.Windows.Automation.AutomationProperties]::SetName($card.Toggle, [string]$Kit.Name)

    $map = $sync.RedesignProgramItemMap
    $first = $true
    foreach ($key in ($Kit.AppKeys | Select-Object -First 4)) {
        $item = $map[$key]
        if (-not $item) { continue }
        $tile = New-WinUtilRedesignIconTile -Size 34 -Overlap $(if ($first) { 0 } else { -9 })
        $first = $false
        $path = $sync.RedesignIconFiles[$item.Short.ToLowerInvariant()]
        Set-WinUtilRedesignIcon -Parts $tile -Item $item -ImagePath $path
        $null = $card.Icons.Children.Add($tile.Root)
        $card.IconParts.Add(@{ Parts = $tile; Item = $item })
    }

    if ($custom) {
        $root.FindName('KitTagText').Text = Get-WinUtilRedesignText -Key 'kitCustom'
        $export = $root.FindName('KitExport')
        $delete = $root.FindName('KitDelete')
        $root.FindName('KitExportText').Text = Get-WinUtilRedesignText -Key 'kitExport'
        $root.FindName('KitDeleteText').Text = Get-WinUtilRedesignText -Key 'kitDelete'
        $export.Tag = $Kit
        $delete.Tag = $Kit
        $export.Add_Click($handlers.Export)
        $delete.Add_Click($handlers.Delete)
        [System.Windows.Automation.AutomationProperties]::SetName($export, ('{0}: {1}' -f (Get-WinUtilRedesignText -Key 'kitExport'), $Kit.Name))
        [System.Windows.Automation.AutomationProperties]::SetName($delete, ('{0}: {1}' -f (Get-WinUtilRedesignText -Key 'kitDelete'), $Kit.Name))
    }

    return $card
}

function Update-WinUtilRedesignKits {
    <#
    .SYNOPSIS
        Draws the kit cards again from the built-in kits and the user's own.

    .DESCRIPTION
        Run when the tab is built, after a kit is created, imported or deleted, and when the
        language changes (the built-in kits are named in both).
    #>

    if (-not $sync.WPFRedesignKitList) {
        return
    }

    $list = $sync.WPFRedesignKitList
    $list.Children.Clear()
    $sync.RedesignKitButtons = [System.Collections.Generic.List[object]]::new()
    $sync.RedesignKitCards = [System.Collections.Generic.List[object]]::new()

    $language = if ($sync.preferences.language -eq 'it') { 'it' } else { 'en' }
    foreach ($kit in @(Get-WinUtilKits -Language $language)) {
        try {
            $card = New-WinUtilRedesignKitCard -Kit $kit
        } catch {
            Write-WinUtilErrorRecord -ErrorRecord $_ -Component 'Kits' -Context "Kit card '$($kit.Name)'"
            continue
        }
        $null = $list.Children.Add($card.Root)
        $sync.RedesignKitButtons.Add(@{ Kit = $kit; Button = $card.Toggle })
        $sync.RedesignKitCards.Add($card)
    }

    Update-WinUtilRedesignProgramLayout
    Update-WinUtilRedesignKitButtons
}

function Invoke-WinUtilRedesignKitToggle {
    <#
    .SYNOPSIS
        Adds the programs of a kit to the selection, or takes them out when they are all there.

    .PARAMETER Kit
        A kit of Get-WinUtilKits.
    #>
    param(
        [Parameter(Mandatory)]
        $Kit
    )

    $allSelected = $true
    foreach ($key in $Kit.AppKeys) {
        if (-not $sync.selectedApps.Contains($key)) {
            $allSelected = $false
            break
        }
    }
    foreach ($key in $Kit.AppKeys) {
        Set-WinUtilRedesignProgramSelected -Key $key -Selected (-not $allSelected)
    }
    Update-WinUtilRedesignProgramSelection
}

function Get-WinUtilRedesignKitErrorText {
    <#
    .SYNOPSIS
        Words an error of the kit functions in the language of the interface.

    .PARAMETER ErrorRecord
        The error caught.
    #>
    param(
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    $code = $ErrorRecord.Exception.Data['KitError']
    if ($code) {
        return Get-WinUtilRedesignText -Key "kitErr$code"
    }
    return Get-WinUtilRedesignText -Key 'kitErrGeneric' -FormatArgs @($ErrorRecord.Exception.Message)
}

function Invoke-WinUtilRedesignKitExport {
    <#
    .SYNOPSIS
        Asks where to save a kit and writes it as a .winutil-kit.json file.

    .DESCRIPTION
        The save dialog takes any folder, a network share included. The file holds package IDs,
        so another PC reads it as the same programs.

    .PARAMETER Kit
        A kit of Get-WinUtilKits.

    .PARAMETER Path
        Skips the dialog and writes there. For tests and scripts.
    #>
    param(
        [Parameter(Mandatory)]
        $Kit,

        [string]$Path
    )

    if (-not $Path) {
        $dialog = [Microsoft.Win32.SaveFileDialog]::new()
        $dialog.Title = Get-WinUtilRedesignText -Key 'kitExportTitle'
        $dialog.Filter = Get-WinUtilRedesignText -Key 'kitFilter'
        $stem = (($Kit.Name -replace '[^\p{L}\p{N}]+', '-').Trim('-')).ToLowerInvariant()
        if (-not $stem) { $stem = 'kit' }
        $dialog.FileName = "$stem.winutil-kit.json"
        $dialog.OverwritePrompt = $true
        $dialog.AddExtension = $false
        if (-not $dialog.ShowDialog($sync.Form)) {
            return
        }
        $Path = $dialog.FileName
        if (-not [System.IO.Path]::GetExtension($Path)) {
            $Path += '.winutil-kit.json'
        }
    }

    try {
        $null = Export-WinUtilKit -Kit $Kit -Path $Path
        Write-WinUtilLog -Component 'Kits' -Message "Kit '$($Kit.Name)' exported to '$Path'."
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignText -Key 'kitExported' -FormatArgs @($Path))
    } catch {
        Write-WinUtilErrorRecord -ErrorRecord $_ -Component 'Kits' -Context "Export of '$($Kit.Name)'"
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignKitErrorText -ErrorRecord $_) -Warning
    }
}

function Invoke-WinUtilRedesignKitImport {
    <#
    .SYNOPSIS
        Asks for a kit file, checks it and adds it to the kits.

    .DESCRIPTION
        Programs the catalog does not have are skipped and counted in the message. A file that is
        not a kit says why. The imported kit is stored in %APPDATA%\WinUtil\kits like one made here.

    .PARAMETER Path
        Skips the dialog and reads this file. For tests and scripts.
    #>
    param(
        [string]$Path
    )

    if (-not $Path) {
        $dialog = [Microsoft.Win32.OpenFileDialog]::new()
        $dialog.Title = Get-WinUtilRedesignText -Key 'kitImportTitle'
        $dialog.Filter = Get-WinUtilRedesignText -Key 'kitFilter'
        $dialog.CheckFileExists = $true
        if (-not $dialog.ShowDialog($sync.Form)) {
            return
        }
        $Path = $dialog.FileName
    }

    try {
        $kit = Import-WinUtilKit -Path $Path
        $saved = Save-WinUtilKit -Name $kit.Name -Description $kit.Description -Color $kit.Color -AppKeys $kit.AppKeys
        Write-WinUtilLog -Component 'Kits' -Message "Kit '$($kit.Name)' imported from '$Path' ($($kit.AppKeys.Count) program(s), $($kit.Skipped) skipped)."
        Update-WinUtilRedesignKits
        $message = Get-WinUtilRedesignText -Key 'kitImported' -FormatArgs @($saved.Name)
        if ($kit.Skipped -gt 0) {
            Write-WinUtilLog -Level 'WARN' -Component 'Kits' -Message "Kit '$($kit.Name)': $($kit.Skipped) program(s) are not in the catalog and were skipped."
            Show-WinUtilRedesignNotice -Text ($message + ' ' + (Get-WinUtilRedesignText -Key 'kitSkipped' -FormatArgs @($kit.Skipped))) -Warning
        } else {
            Show-WinUtilRedesignNotice -Text $message
        }
    } catch {
        Write-WinUtilLog -Level 'WARN' -Component 'Kits' -Message "Kit file '$Path' was refused: $($_.Exception.Message)"
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignText -Key 'kitInvalid' -FormatArgs @((Get-WinUtilRedesignKitErrorText -ErrorRecord $_))) -Warning
    }
}

function Invoke-WinUtilRedesignKitDelete {
    <#
    .SYNOPSIS
        Deletes a custom kit after asking. The programs stay installed.

    .PARAMETER Kit
        A custom kit of Get-WinUtilKits.

    .PARAMETER Confirmed
        Skips the question. For tests and scripts.
    #>
    param(
        [Parameter(Mandatory)]
        $Kit,

        [switch]$Confirmed
    )

    if (-not $Confirmed) {
        $answer = [System.Windows.MessageBox]::Show(
            $sync.Form,
            (Get-WinUtilRedesignText -Key 'kitDeleteAsk' -FormatArgs @($Kit.Name)),
            (Get-WinUtilRedesignText -Key 'kitDelete'),
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }
    }

    try {
        Remove-WinUtilKit -Kit $Kit
        Write-WinUtilLog -Component 'Kits' -Message "Kit '$($Kit.Name)' deleted."
        Update-WinUtilRedesignKits
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignText -Key 'kitDeleted' -FormatArgs @($Kit.Name))
    } catch {
        Write-WinUtilErrorRecord -ErrorRecord $_ -Component 'Kits' -Context "Delete of '$($Kit.Name)'"
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignKitErrorText -ErrorRecord $_) -Warning
    }
}
