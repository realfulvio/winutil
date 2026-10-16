function Find-WinUtilRedesignIconUrls {
    <#
    .SYNOPSIS
        Lists the addresses an official icon may be at, best first.

    .DESCRIPTION
        For a GitHub project the avatar of its owner (the project's own picture). For any other
        site, the icons its page declares: an apple-touch-icon first, then the largest PNG or
        ICO of <link rel="icon">, then /favicon.ico. SVG and WebP are left out, since the window
        cannot draw them without extra code.

    .PARAMETER Html
        The text of the program's web page ($null when it could not be read).

    .PARAMETER PageUri
        The address the page was read from; relative links are resolved against it.

    .OUTPUTS
        A list of absolute addresses.
    #>
    param(
        [string]$Html,
        [Parameter(Mandatory)][uri]$PageUri
    )

    $found = [System.Collections.Generic.List[object]]::new()
    if ($Html) {
        foreach ($tag in [regex]::Matches($Html, '(?is)<link\b[^>]*>')) {
            $attributes = @{}
            foreach ($attribute in [regex]::Matches($tag.Value, '(?is)([\w:-]+)\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s"''>]+))')) {
                $value = if ($attribute.Groups[2].Success) { $attribute.Groups[2].Value } elseif ($attribute.Groups[3].Success) { $attribute.Groups[3].Value } else { $attribute.Groups[4].Value }
                $attributes[$attribute.Groups[1].Value.ToLowerInvariant()] = $value
            }
            $rel = ([string]$attributes['rel']).ToLowerInvariant()
            $href = [string]$attributes['href']
            if (-not $href -or $rel -notmatch 'icon') {
                continue
            }
            $absolute = $null
            try { $absolute = [uri]::new($PageUri, $href.Trim()).AbsoluteUri } catch { continue }
            if ($absolute -notmatch '^https?://') {
                continue
            }
            $type = ([string]$attributes['type']).ToLowerInvariant()
            if ($type -match 'svg|webp' -or $absolute -match '\.(svg|webp)(\?|#|$)') {
                continue
            }
            $size = 0
            $sizes = [regex]::Match([string]$attributes['sizes'], '(\d+)x\d+')
            if ($sizes.Success) { $size = [int]$sizes.Groups[1].Value }
            $rank = if ($rel -match 'apple-touch-icon') { 1000 + $size } elseif ($absolute -match '\.png(\?|$)' -or $type -match 'png') { 500 + $size } else { $size }
            $found.Add([pscustomobject]@{ Url = $absolute; Rank = $rank })
        }
    }

    $ordered = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in ($found | Sort-Object Rank -Descending)) {
        if (-not $ordered.Contains($candidate.Url)) { $ordered.Add($candidate.Url) }
    }
    $favicon = "$($PageUri.Scheme)://$($PageUri.Authority)/favicon.ico"
    if (-not $ordered.Contains($favicon)) { $ordered.Add($favicon) }
    return $ordered
}

function Save-WinUtilRedesignOfficialIcon {
    <#
    .SYNOPSIS
        Downloads a program's icon from its official site or repository into the icon folder.

    .DESCRIPTION
        Runs on a worker thread and never throws. The page of the program (the "link" of
        config/applications.json) is read, its declared icons are tried best first, and the first
        one that decodes as an image at least 32 px wide is kept. For a GitHub project the owner's
        avatar is used, since the project page only declares GitHub's own icon. When nothing
        works although a server answered, a <key>.none file is written, so the next start does not
        try again at once; when the network was unreachable nothing is written and the next start tries again.

    .PARAMETER Key
        The short key of the program (the name of the cache file).

    .PARAMETER Link
        The program's official web page.

    .PARAMETER Folder
        The icon folder.

    .PARAMETER Client
        A shared System.Net.Http.HttpClient.

    .OUTPUTS
        The path of the saved file, or $null.
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Link,
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)]$Client
    )

    $readLimit = 1500000
    # Whether any server answered. Only then is "no icon" a fact worth remembering: a network that
    # was down says nothing about the program.
    $state = @{ Reached = $false }

    function Get-IconBytes([string]$Url, [int]$Limit) {
        try {
            $response = $Client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            $state.Reached = $true
            try {
                if (-not $response.IsSuccessStatusCode) { return $null }
                if ($response.Content.Headers.ContentLength -and $response.Content.Headers.ContentLength -gt $Limit) { return $null }
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $buffer = New-Object System.IO.MemoryStream
                $chunk = New-Object byte[] 16384
                while (($read = $stream.Read($chunk, 0, $chunk.Length)) -gt 0) {
                    $buffer.Write($chunk, 0, $read)
                    if ($buffer.Length -gt $Limit) { return $null }
                }
                return ,$buffer.ToArray()
            } finally {
                $response.Dispose()
            }
        } catch {
            return $null
        }
    }

    function Get-ImageExtension([byte[]]$Bytes) {
        if ($Bytes.Length -lt 12) { return $null }
        if ($Bytes[0] -eq 0x89 -and $Bytes[1] -eq 0x50 -and $Bytes[2] -eq 0x4E -and $Bytes[3] -eq 0x47) { return '.png' }
        if ($Bytes[0] -eq 0x00 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0x01 -and $Bytes[3] -eq 0x00) { return '.ico' }
        if ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xD8) { return '.jpg' }
        if ($Bytes[0] -eq 0x47 -and $Bytes[1] -eq 0x49 -and $Bytes[2] -eq 0x46) { return '.gif' }
        if ($Bytes[0] -eq 0x42 -and $Bytes[1] -eq 0x4D) { return '.bmp' }
        return $null
    }

    function Get-ImageWidth([byte[]]$Bytes) {
        try {
            $stream = New-Object System.IO.MemoryStream (, $Bytes)
            try {
                $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create($stream, [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
                return [int](($decoder.Frames | Measure-Object -Property PixelWidth -Maximum).Maximum)
            } finally {
                $stream.Dispose()
            }
        } catch {
            return 0
        }
    }

    try {
        $pageUri = [uri]$Link
        $candidates = [System.Collections.Generic.List[string]]::new()
        if ($pageUri.Host -match '^(www\.)?github\.com$' -and $pageUri.Segments.Count -ge 2) {
            $owner = $pageUri.Segments[1].Trim('/')
            if ($owner) {
                $candidates.Add("https://github.com/$owner.png?size=128")
            }
        } else {
            $page = Get-IconBytes $Link 600000
            $html = if ($page) { [System.Text.Encoding]::UTF8.GetString($page) } else { $null }
            foreach ($url in (Find-WinUtilRedesignIconUrls -Html $html -PageUri $pageUri)) {
                $candidates.Add($url)
            }
        }

        foreach ($url in $candidates) {
            $bytes = Get-IconBytes $url $readLimit
            if (-not $bytes) { continue }
            $extension = Get-ImageExtension $bytes
            if (-not $extension) { continue }
            if ((Get-ImageWidth $bytes) -lt 32) { continue }

            $path = Join-Path $Folder "$Key$extension"
            [System.IO.File]::WriteAllBytes($path, $bytes)
            return $path
        }
    } catch {
        $null = $_
    }

    if ($state.Reached) {
        try {
            [System.IO.File]::WriteAllBytes((Join-Path $Folder "$Key.none"), [byte[]]@())
        } catch {
            $null = $_
        }
    }
    return $null
}
