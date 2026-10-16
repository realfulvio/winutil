function Show-WinUtilRedesignKitDialog {
    <#
    .SYNOPSIS
        Opens the dialog that turns the current selection into a custom kit.

    .DESCRIPTION
        The name is required, the description is not; one of five colors is chosen; the programs
        that will be in the kit are listed. Without a selection there is nothing to save, and
        the action bar says so instead.
    #>

    if (@($sync.selectedApps).Count -eq 0) {
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignText -Key 'kdNeedSel') -Warning
        return
    }

    $sync.WPFRedesignKdName.Text = ''
    $sync.WPFRedesignKdDesc.Text = ''
    $sync.WPFRedesignKdError.Visibility = [Windows.Visibility]::Collapsed
    $sync.RedesignKdColor = 3

    $map = $sync.RedesignProgramItemMap
    $names = @($sync.selectedApps | ForEach-Object { if ($map[$_]) { $map[$_].Name } else { $_ } } | Sort-Object)
    $sync.WPFRedesignKdProgramsLabel.Text = (Get-WinUtilRedesignText -Key 'kdPrograms' -FormatArgs @($names.Count)).ToUpper()
    $panel = $sync.WPFRedesignKdPrograms
    $panel.Children.Clear()
    foreach ($name in $names) {
        $pill = [Windows.Controls.Border]::new()
        $pill.CornerRadius = [Windows.CornerRadius]::new(12)
        $pill.Padding = [Windows.Thickness]::new(11, 3, 11, 3)
        $pill.Margin = [Windows.Thickness]::new(0, 0, 6, 6)
        $pill.Background = New-WinUtilRedesignBrush '#123068'
        $label = [Windows.Controls.TextBlock]::new()
        $label.Text = $name
        $label.FontSize = [double]$sync.Form.Resources['RdFontSmall']
        $label.Foreground = New-WinUtilRedesignBrush '#CFE0F5'
        $pill.Child = $label
        $null = $panel.Children.Add($pill)
    }

    Update-WinUtilRedesignKitColors
    $sync.WPFRedesignKitScrim.Visibility = [Windows.Visibility]::Visible
    $null = $sync.WPFRedesignKdName.Focus()
}

function Update-WinUtilRedesignKitColors {
    <#
    .SYNOPSIS
        Draws the five color swatches of the kit dialog; the chosen one has a white ring.
    #>

    $panel = $sync.WPFRedesignKdColors
    $panel.Children.Clear()
    $palette = @($sync.configs.redesignprograms.kitColors)
    for ($index = 0; $index -lt $palette.Count; $index++) {
        $xaml = @"
<ToggleButton xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
              xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
              Width="44" Height="44" Margin="0,0,4,0" Cursor="Hand" Focusable="True" Background="Transparent" BorderThickness="0">
    <ToggleButton.Template>
        <ControlTemplate TargetType="ToggleButton">
            <Grid Background="Transparent">
                <Ellipse x:Name="Ring" Width="36" Height="36" StrokeThickness="3" Stroke="Transparent"/>
                <Ellipse Width="28" Height="28">
                    <Ellipse.Fill>
                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                            <GradientStop Color="$($palette[$index].from)" Offset="0"/>
                            <GradientStop Color="$($palette[$index].to)" Offset="1"/>
                        </LinearGradientBrush>
                    </Ellipse.Fill>
                </Ellipse>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsChecked" Value="True">
                    <Setter TargetName="Ring" Property="Stroke" Value="#FFFFFF"/>
                </Trigger>
                <Trigger Property="IsKeyboardFocused" Value="True">
                    <Setter TargetName="Ring" Property="Stroke" Value="#4CC2FF"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
    </ToggleButton.Template>
</ToggleButton>
"@
        $swatch = [Windows.Markup.XamlReader]::Parse($xaml)
        $swatch.Tag = $index
        $swatch.IsChecked = ($index -eq $sync.RedesignKdColor)
        [System.Windows.Automation.AutomationProperties]::SetName($swatch, [string]($index + 1))
        $swatch.Add_Click({
            $sync.RedesignKdColor = [int]$this.Tag
            foreach ($other in $sync.WPFRedesignKdColors.Children) {
                $other.IsChecked = ([int]$other.Tag -eq $sync.RedesignKdColor)
            }
        })
        $null = $panel.Children.Add($swatch)
    }
}

function Hide-WinUtilRedesignKitDialog {
    <#
    .SYNOPSIS
        Closes the kit dialog without saving.
    #>

    $sync.WPFRedesignKitScrim.Visibility = [Windows.Visibility]::Collapsed
}

function Save-WinUtilRedesignKitFromDialog {
    <#
    .SYNOPSIS
        Saves the kit the dialog describes, closes it and shows the new kit.

    .DESCRIPTION
        A blank name is not accepted and is said so in the dialog, which stays open.
    #>

    $name = $sync.WPFRedesignKdName.Text.Trim()
    if (-not $name) {
        $sync.WPFRedesignKdError.Text = Get-WinUtilRedesignText -Key 'kdNeedName'
        $sync.WPFRedesignKdError.Visibility = [Windows.Visibility]::Visible
        $sync.WPFRedesignKdName.BorderBrush = New-WinUtilRedesignBrush '#FF6B6B'
        $null = $sync.WPFRedesignKdName.Focus()
        return
    }

    try {
        $kit = Save-WinUtilKit -Name $name -Description $sync.WPFRedesignKdDesc.Text -Color ([int]$sync.RedesignKdColor) -AppKeys @($sync.selectedApps)
        Write-WinUtilLog -Component 'Kits' -Message "Kit '$name' saved with $($kit.AppKeys.Count) program(s)."
        Hide-WinUtilRedesignKitDialog
        Update-WinUtilRedesignKits
        Show-WinUtilRedesignNotice -Text (Get-WinUtilRedesignText -Key 'kitSaved' -FormatArgs @($kit.Name))
    } catch {
        Write-WinUtilErrorRecord -ErrorRecord $_ -Component 'Kits' -Context "Save of '$name'"
        $sync.WPFRedesignKdError.Text = Get-WinUtilRedesignKitErrorText -ErrorRecord $_
        $sync.WPFRedesignKdError.Visibility = [Windows.Visibility]::Visible
    }
}
