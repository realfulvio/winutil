function Get-WinUtilRedesignCardHandlers {
    <#
    .SYNOPSIS
        The event handlers shared by every program card.

    .DESCRIPTION
        Scriptblocks are made once and read the sender through $this, as upstream's entry
        handlers do: building several per card is what costs time when there are hundreds.
    #>

    if ($null -ne $script:WinUtilRedesignCardHandlers) {
        return $script:WinUtilRedesignCardHandlers
    }

    $script:WinUtilRedesignCardHandlers = @{
        Body = {
            $check = $sync[$this.Tag]
            if ($check) { $check.IsChecked = -not $check.IsChecked }
        }
        Info = {
            Show-WinUtilRedesignProgramDetail -Key $this.Tag
        }
        Checked = {
            Invoke-WPFSelectedCheckboxesUpdate -type "Add" -checkboxName $this.Tag
            Update-WinUtilRedesignProgramSelection -Key $this.Tag
        }
        Unchecked = {
            Invoke-WPFSelectedCheckboxesUpdate -type "Remove" -checkboxName $this.Tag
            Update-WinUtilRedesignProgramSelection -Key $this.Tag
        }
    }
    return $script:WinUtilRedesignCardHandlers
}

function New-WinUtilRedesignAppCard {
    <#
    .SYNOPSIS
        Builds the card of one program.

    .DESCRIPTION
        The card holds a CheckBox that is registered in $sync under the program's own key
        (WPFInstall<key>), the way upstream's entry checkbox is, so the selection, presets,
        import and export and Reset-WPFCheckBoxes keep working on it untouched. The card body
        toggles it; the round button opens the details. Texts are written later by
        Update-WinUtilRedesignProgramTexts, since they depend on the language.

        Styles are looked up with DynamicResource because the card is parsed on its own and only
        meets the window's resources once it is added to the list.

    .PARAMETER Item
        An entry of Get-WinUtilRedesignProgramItems.

    .OUTPUTS
        A hashtable with Root, Check, Body, Info, Title, Desc, Badge, BadgeText and the icon parts
        (Tile, GlyphBox, Glyph, Font, Image).
    #>
    param(
        [Parameter(Mandatory)]
        $Item
    )

    $xaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="CardRoot" Margin="0,0,12,12" Width="290" MinHeight="132" CornerRadius="16" BorderThickness="1" BorderBrush="#1E2A44" Padding="14,14,6,10">
    <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#142243" Offset="0"/>
            <GradientStop Color="#0F182B" Offset="1"/>
        </LinearGradientBrush>
    </Border.Background>
    <Grid>
        <Button x:Name="CardBody" Style="{DynamicResource RdCardButtonStyle}" IsTabStop="False" VerticalContentAlignment="Top" Padding="0,0,0,2">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="IconTile" Grid.Column="0" Width="48" Height="48" CornerRadius="13" VerticalAlignment="Top" Background="#16223C">
                    <Grid>
                        <Viewbox x:Name="IconGlyphBox" Width="24" Height="24" HorizontalAlignment="Center" VerticalAlignment="Center">
                            <Path x:Name="IconGlyph" Fill="White" Stretch="Uniform" Width="24" Height="24"/>
                        </Viewbox>
                        <TextBlock x:Name="IconFont" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="{DynamicResource RdIconL}" Foreground="White" Background="Transparent" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        <Image x:Name="IconImage" Margin="6" Visibility="Collapsed" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality"/>
                    </Grid>
                </Border>
                <StackPanel Grid.Column="1" Margin="12,0,40,0" VerticalAlignment="Top">
                    <TextBlock x:Name="CardTitle" FontSize="{DynamicResource RdFontMedium}" FontWeight="Bold" Foreground="#EAF0FA" Background="Transparent" TextWrapping="Wrap" HorizontalAlignment="Left"/>
                    <TextBlock x:Name="CardDesc" FontSize="{DynamicResource RdFontSmall}" Foreground="#A9B9D2" Background="Transparent" TextWrapping="Wrap" Margin="0,2,0,0" HorizontalAlignment="Left"/>
                    <Border x:Name="CardBadge" Style="{DynamicResource RdTagBorderStyle}" Padding="10,2" Margin="0,8,0,0" HorizontalAlignment="Left" Background="#123068" BorderBrush="#1E3F7A">
                        <TextBlock x:Name="CardBadgeText" FontSize="{DynamicResource RdFontSmall}" FontWeight="SemiBold" Foreground="#9FC0FF" Background="Transparent"/>
                    </Border>
                </StackPanel>
            </Grid>
        </Button>
        <CheckBox x:Name="CardCheck" Style="{DynamicResource RdCheckBoxStyle}" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,-12,-6,0"/>
        <Button x:Name="CardInfo" Style="{DynamicResource RdCaptionButtonStyle}" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,-6,-10" Content="&#xE946;"/>
    </Grid>
</Border>
'@

    $root = [Windows.Markup.XamlReader]::Parse($xaml)
    $handlers = Get-WinUtilRedesignCardHandlers

    $card = @{
        Root      = $root
        Check     = $root.FindName('CardCheck')
        Body      = $root.FindName('CardBody')
        Info      = $root.FindName('CardInfo')
        Title     = $root.FindName('CardTitle')
        Desc      = $root.FindName('CardDesc')
        Badge     = $root.FindName('CardBadge')
        BadgeText = $root.FindName('CardBadgeText')
        Tile      = $root.FindName('IconTile')
        GlyphBox  = $root.FindName('IconGlyphBox')
        Glyph     = $root.FindName('IconGlyph')
        Font      = $root.FindName('IconFont')
        Image     = $root.FindName('IconImage')
    }

    $card.Check.Tag = $Item.Key
    $card.Body.Tag = $Item.Key
    $card.Info.Tag = $Item.Key
    $card.Check.Add_Checked($handlers.Checked)
    $card.Check.Add_Unchecked($handlers.Unchecked)
    $card.Body.Add_Click($handlers.Body)
    $card.Info.Add_Click($handlers.Info)

    return $card
}
