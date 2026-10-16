function Get-WinUtilRedesignIconFolder {
    <#
    .SYNOPSIS
        The folder that keeps the downloaded program icons: %LOCALAPPDATA%\WinUtil\icons.

    .PARAMETER Create
        Creates the folder when it does not exist.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$Create
    )

    $folder = Join-Path (Join-Path $env:LOCALAPPDATA 'WinUtil') 'icons'
    if ($Create -and -not (Test-Path -LiteralPath $folder)) {
        $null = New-Item -ItemType Directory -Path $folder -Force
    }
    return $folder
}

function Read-WinUtilRedesignIconIndex {
    <#
    .SYNOPSIS
        Lists what the icon folder holds, once, so a card does not have to look on disk.

    .DESCRIPTION
        Files are named <program key>.<png|ico|jpg|gif|bmp>. A <program key>.none file records
        that no icon could be found, and is trusted for seven days so an app without a usable
        icon is not asked about again on every start.

    .OUTPUTS
        Nothing; fills $sync.RedesignIconFiles (key to path) and $sync.RedesignIconMisses (a set).
    #>

    $sync.RedesignIconFiles = [Hashtable]::Synchronized(@{})
    $sync.RedesignIconMisses = [Hashtable]::Synchronized(@{})
    $folder = Get-WinUtilRedesignIconFolder
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        return
    }

    foreach ($file in [System.IO.Directory]::GetFiles($folder)) {
        $key = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
        if ($extension -eq '.none') {
            if (([datetime]::UtcNow - [System.IO.File]::GetLastWriteTimeUtc($file)).TotalDays -lt 7) {
                $sync.RedesignIconMisses[$key] = $true
            }
        } elseif ($extension -in '.png', '.ico', '.jpg', '.gif', '.bmp') {
            $sync.RedesignIconFiles[$key] = $file
        }
    }
}

function Get-WinUtilRedesignIconBitmap {
    <#
    .SYNOPSIS
        Loads a cached icon file as a frozen bitmap, or $null when it cannot be read.

    .DESCRIPTION
        The file is read fully and released, so a later download can replace it. An .ico file
        holds several sizes and the largest is used.

    .PARAMETER Path
        The cached file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $stream = New-Object System.IO.MemoryStream (, $bytes)
        try {
            $decoder = [Windows.Media.Imaging.BitmapDecoder]::Create($stream, [Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
            $frame = $decoder.Frames | Sort-Object PixelWidth -Descending | Select-Object -First 1
            if ($frame) {
                $frame.Freeze()
                return $frame
            }
        } finally {
            $stream.Dispose()
        }
    } catch {
        $null = $_
    }
    return $null
}

function Set-WinUtilRedesignIcon {
    <#
    .SYNOPSIS
        Draws a program's icon into a tile.

    .DESCRIPTION
        With a cached image: the image on a light plate, the way an application icon is shown
        on a launcher. Without one: the brand outline on its colored tile, or the category glyph.

    .PARAMETER Parts
        The controls of the tile: Tile (Border), GlyphBox (Viewbox), Glyph (Path), Font (TextBlock)
        and Image (Image).

    .PARAMETER Item
        An entry of Get-WinUtilRedesignProgramItems.

    .PARAMETER ImagePath
        The cached icon file, when there is one.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Parts,
        [Parameter(Mandatory)]$Item,
        [string]$ImagePath
    )

    $bitmap = if ($ImagePath) { Get-WinUtilRedesignIconBitmap -Path $ImagePath } else { $null }
    if ($bitmap) {
        $Parts.Image.Source = $bitmap
        $Parts.Image.Visibility = [Windows.Visibility]::Visible
        $Parts.Tile.Background = New-WinUtilRedesignGradient -From '#F7F9FD' -To '#DCE4F2'
        $Parts.GlyphBox.Visibility = [Windows.Visibility]::Collapsed
        $Parts.Font.Visibility = [Windows.Visibility]::Collapsed
        return
    }

    $spec = Get-WinUtilRedesignIconSpec -Item $Item
    $Parts.Image.Source = $null
    $Parts.Image.Visibility = [Windows.Visibility]::Collapsed
    $Parts.Tile.Background = New-WinUtilRedesignGradient -From $spec.From -To $spec.To
    if ($spec.Kind -eq 'brand') {
        if ($null -eq $sync.RedesignGeometries) {
            $sync.RedesignGeometries = @{}
        }
        if (-not $sync.RedesignGeometries.ContainsKey($Item.Slug)) {
            $geometry = [Windows.Media.Geometry]::Parse($spec.Path)
            $geometry.Freeze()
            $sync.RedesignGeometries[$Item.Slug] = $geometry
        }
        $Parts.Glyph.Data = $sync.RedesignGeometries[$Item.Slug]
        $Parts.GlyphBox.Visibility = [Windows.Visibility]::Visible
        $Parts.Font.Visibility = [Windows.Visibility]::Collapsed
    } else {
        $Parts.Font.Text = [string][char][Convert]::ToInt32($spec.Glyph, 16)
        $Parts.Font.Visibility = [Windows.Visibility]::Visible
        $Parts.GlyphBox.Visibility = [Windows.Visibility]::Collapsed
    }
}

function New-WinUtilRedesignIconTile {
    <#
    .SYNOPSIS
        Builds a small icon tile (kit cards, the selection list of the kit dialog).

    .PARAMETER Size
        Width and height in device-independent pixels.

    .PARAMETER Overlap
        A negative left margin, so a row of tiles overlaps like the stack on a kit card.

    .OUTPUTS
        A hashtable with Root, Tile, GlyphBox, Glyph, Font and Image, as Set-WinUtilRedesignIcon takes.
    #>
    param(
        [int]$Size = 32,
        [int]$Overlap = 0
    )

    $glyphSize = [int]($Size * 0.5)
    $radius = [int]($Size * 0.3)
    $xaml = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="IconTile" Width="$Size" Height="$Size" CornerRadius="$radius" BorderThickness="2" BorderBrush="#0B1C40" Margin="$Overlap,0,0,0">
    <Grid>
        <Viewbox x:Name="IconGlyphBox" Width="$glyphSize" Height="$glyphSize" HorizontalAlignment="Center" VerticalAlignment="Center">
            <Path x:Name="IconGlyph" Fill="White" Stretch="Uniform" Width="24" Height="24"/>
        </Viewbox>
        <TextBlock x:Name="IconFont" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="$glyphSize" Foreground="White" Background="Transparent" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        <Image x:Name="IconImage" Margin="3" Visibility="Collapsed" Stretch="Uniform"/>
    </Grid>
</Border>
"@
    $root = [Windows.Markup.XamlReader]::Parse($xaml)
    return @{
        Root     = $root
        Tile     = $root
        GlyphBox = $root.FindName('IconGlyphBox')
        Glyph    = $root.FindName('IconGlyph')
        Font     = $root.FindName('IconFont')
        Image    = $root.FindName('IconImage')
    }
}
