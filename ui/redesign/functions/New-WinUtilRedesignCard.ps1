function New-WinUtilRedesignCard {
    <#
    .SYNOPSIS
        Builds the card of one tweak.

    .DESCRIPTION
        The card holds the same kind of CheckBox Invoke-WPFUIElements would create, with the
        tweak's own key as its Name, so selection, presets, import/export and Reset-WPFCheckBoxes
        keep working on it untouched. The card body is a separate button that puts the tweak in
        focus in the right panel.

        Styles are looked up with DynamicResource because the card is parsed on its own and only
        meets the window's resources once it is added to the list.

    .PARAMETER Item
        An entry of Get-WinUtilRedesignTweakItems.

    .OUTPUTS
        Hashtable with the card's Root, Check, Body, Icon, Title, Desc, CatText, StateTag,
        StateGlyph and StateText controls.
    #>
    param(
        [Parameter(Mandatory)]
        $Item
    )

    $xaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="CardRoot" Margin="0,0,0,14" CornerRadius="16" BorderThickness="1" BorderBrush="#1E2A44" Padding="6,8,12,8">
    <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#121C33" Offset="0"/>
            <GradientStop Color="#0F182B" Offset="1"/>
        </LinearGradientBrush>
    </Border.Background>
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <CheckBox Name="@KEY@" Grid.Column="0" Style="{DynamicResource RdCheckBoxStyle}" VerticalAlignment="Center" Margin="4,0,6,0"/>
        <Button x:Name="CardBody" Grid.Column="1" Style="{DynamicResource RdCardButtonStyle}" Padding="6,6,2,6">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Border Grid.Column="0" Width="56" Height="56" CornerRadius="14" BorderThickness="1" BorderBrush="#243558" Background="#16223C" VerticalAlignment="Center">
                    <TextBlock x:Name="CardIcon" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="{DynamicResource RdIconXL}" Foreground="#7FD3FF" Background="Transparent" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <StackPanel Grid.Column="1" Margin="16,0,8,0" VerticalAlignment="Center">
                    <TextBlock x:Name="CardTitle" FontSize="{DynamicResource RdFontLarge}" FontWeight="Bold" Foreground="#EAF0FA" Background="Transparent" TextWrapping="Wrap" HorizontalAlignment="Left"/>
                    <TextBlock x:Name="CardDesc" FontSize="{DynamicResource RdFontBody}" Foreground="#9FB0C9" Background="Transparent" TextWrapping="Wrap" Margin="0,3,0,0" HorizontalAlignment="Left"/>
                    <WrapPanel Margin="0,10,0,0" HorizontalAlignment="Left">
                        <Border Style="{DynamicResource RdTagBorderStyle}" Background="#16223C" BorderBrush="#22304D">
                            <TextBlock x:Name="CardCatText" FontSize="{DynamicResource RdFontSmall}" FontWeight="SemiBold" Foreground="#CFE0F5" Background="Transparent"/>
                        </Border>
                        <Border x:Name="CardStateTag" Style="{DynamicResource RdTagBorderStyle}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock x:Name="CardStateGlyph" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="{DynamicResource RdFontSmall}" Margin="0,1,6,0" Background="Transparent" VerticalAlignment="Center"/>
                                <TextBlock x:Name="CardStateText" FontSize="{DynamicResource RdFontSmall}" FontWeight="SemiBold" Background="Transparent"/>
                            </StackPanel>
                        </Border>
                    </WrapPanel>
                </StackPanel>
                <TextBlock Grid.Column="2" Text="&#xE76C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="{DynamicResource RdIconS}" Foreground="#9FB0C9" Background="Transparent" VerticalAlignment="Center" Margin="0,0,6,0"/>
            </Grid>
        </Button>
    </Grid>
</Border>
'@

    $root = [Windows.Markup.XamlReader]::Parse($xaml.Replace("@KEY@", $Item.Name))

    return @{
        Root       = $root
        Check      = $root.FindName($Item.Name)
        Body       = $root.FindName("CardBody")
        Icon       = $root.FindName("CardIcon")
        Title      = $root.FindName("CardTitle")
        Desc       = $root.FindName("CardDesc")
        CatText    = $root.FindName("CardCatText")
        StateTag   = $root.FindName("CardStateTag")
        StateGlyph = $root.FindName("CardStateGlyph")
        StateText  = $root.FindName("CardStateText")
    }
}
