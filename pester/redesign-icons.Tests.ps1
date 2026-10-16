#===========================================================================
# Tests - Redesign program icons: where they are looked for, what is kept
#===========================================================================

# Decided at discovery: the download tests need the WPF image decoder and the HTTP classes
$wpfAvailable = $false
try {
    Add-Type -AssemblyName PresentationCore, WindowsBase, System.Net.Http -ErrorAction Stop
    $wpfAvailable = $true
} catch {
    $wpfAvailable = $false
}

Describe "Redesign program icons" {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
        $redesignRoot = Join-Path $script:repoRoot "ui\redesign"
        $script:wpf = $false
        try {
            Add-Type -AssemblyName PresentationCore, WindowsBase, System.Net.Http -ErrorAction Stop
            $script:wpf = $true
        } catch {
            $script:wpf = $false
        }

        foreach ($name in "Get-WinUtilRedesignIconSpec", "Set-WinUtilRedesignIcon", "Save-WinUtilRedesignOfficialIcon") {
            . (Join-Path $redesignRoot "functions\$name.ps1")
        }

        $global:sync = [Hashtable]::Synchronized(@{})
        $sync.configs = @{
            redesignicons    = Get-Content -LiteralPath (Join-Path $redesignRoot "icons.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            redesignprograms = Get-Content -LiteralPath (Join-Path $redesignRoot "programs.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        }

        if ($script:wpf -and -not ("WinUtilTestHandler" -as [type])) {
            # A web client whose answers come from a table, so no network is needed
            # .NET (PowerShell 7) keeps these types in separate assemblies; .NET Framework has them in the ones below
            $references = @('System.Net.Http')
            if ($PSVersionTable.PSEdition -eq 'Core') {
                $references += 'System.Collections', 'System.Runtime', 'System.Threading.Tasks', 'System.Net.Primitives', 'netstandard'
            }
            Add-Type -ReferencedAssemblies $references -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

public class WinUtilTestHandler : HttpMessageHandler
{
    public Dictionary<string, byte[]> Answers = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
    public List<string> Requested = new List<string>();
    public bool NetworkDown;

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        string url = request.RequestUri.AbsoluteUri;
        Requested.Add(url);
        if (NetworkDown) { throw new HttpRequestException("The network is down."); }
        byte[] body;
        HttpResponseMessage response;
        if (Answers.TryGetValue(url, out body))
        {
            response = new HttpResponseMessage(HttpStatusCode.OK);
            response.Content = new ByteArrayContent(body);
        }
        else
        {
            response = new HttpResponseMessage(HttpStatusCode.NotFound);
            response.Content = new ByteArrayContent(new byte[0]);
        }
        return Task.FromResult(response);
    }
}
"@
        }

        function script:New-TestPng([int]$Size) {
            $pixels = New-Object byte[] ($Size * $Size * 4)
            for ($i = 0; $i -lt $pixels.Length; $i += 4) { $pixels[$i] = 200; $pixels[$i + 1] = 80; $pixels[$i + 2] = 20; $pixels[$i + 3] = 255 }
            $source = [System.Windows.Media.Imaging.BitmapSource]::Create($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Bgra32, $null, $pixels, $Size * 4)
            $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
            $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($source))
            $stream = New-Object System.IO.MemoryStream
            $encoder.Save($stream)
            return , $stream.ToArray()
        }
        function script:New-TestClient($Handler) {
            return New-Object System.Net.Http.HttpClient ($Handler)
        }
    }

    AfterAll {
        Remove-Variable -Name sync -Scope Global -ErrorAction SilentlyContinue
    }

    Context "the icon of a program with no download yet" {
        It "draws a brand outline in the brand color" {
            $item = [pscustomobject]@{ Key = "WPFInstallfirefox"; Slug = "firefox"; Category = "Browsers" }
            $spec = Get-WinUtilRedesignIconSpec -Item $item
            $spec.Kind | Should -Be "brand"
            $spec.From | Should -Be "#FF7139"
            $spec.Path | Should -Match "^M"
        }

        It "uses a neutral dark tile for a brand that is nearly black" {
            $item = [pscustomobject]@{ Key = "WPFInstall7zip"; Slug = "7zip"; Category = "Utilities" }
            $spec = Get-WinUtilRedesignIconSpec -Item $item
            $spec.Kind | Should -Be "brand"
            $spec.From | Should -Be "#3A4256"
        }

        It "falls back to the glyph and color of the category" {
            $item = [pscustomobject]@{ Key = "WPFInstallnmap"; Slug = ""; Category = "Pro Tools" }
            $spec = Get-WinUtilRedesignIconSpec -Item $item
            $spec.Kind | Should -Be "category"
            $spec.Glyph | Should -Be "E9D9"
            $spec.From | Should -Be "#9A7CF0"
        }

        It "falls back to a generic tile for a category it does not know" {
            $item = [pscustomobject]@{ Key = "WPFInstallx"; Slug = ""; Category = "Something new" }
            (Get-WinUtilRedesignIconSpec -Item $item).Kind | Should -Be "category"
        }
    }

    Context "finding the address of the icon" {
        It "prefers the apple-touch-icon, then the largest PNG, and ends with /favicon.ico" {
            $html = @'
<html><head>
<link rel="icon" href="/small.ico" sizes="16x16">
<link rel="icon" type="image/png" href="/big.png" sizes="192x192">
<link rel="apple-touch-icon" href="touch.png" sizes="180x180">
<link rel="icon" href="/logo.svg" type="image/svg+xml">
</head></html>
'@
            $urls = @(Find-WinUtilRedesignIconUrls -Html $html -PageUri ([uri]"https://example.org/app/"))
            $urls[0] | Should -Be "https://example.org/app/touch.png"
            $urls[1] | Should -Be "https://example.org/big.png"
            $urls | Should -Contain "https://example.org/small.ico"
            $urls | Should -Not -Contain "https://example.org/logo.svg"
            $urls[-1] | Should -Be "https://example.org/favicon.ico"
        }

        It "tries /favicon.ico when the page declares nothing" {
            @(Find-WinUtilRedesignIconUrls -Html "<html></html>" -PageUri ([uri]"https://example.org/x")) | Should -Be @("https://example.org/favicon.ico")
            @(Find-WinUtilRedesignIconUrls -Html $null -PageUri ([uri]"https://example.org/x")) | Should -Be @("https://example.org/favicon.ico")
        }

        It "reads attributes in any order and with single quotes" {
            $html = "<link href='/a.png' sizes='96x96' rel='shortcut icon'>"
            @(Find-WinUtilRedesignIconUrls -Html $html -PageUri ([uri]"https://example.org/"))[0] | Should -Be "https://example.org/a.png"
        }
    }

    Context "downloading it" -Skip:(-not $wpfAvailable) {
        BeforeEach {
            $script:folder = Join-Path $TestDrive ("icons-" + [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $script:folder | Out-Null
            $script:handler = New-Object WinUtilTestHandler
            $script:client = New-TestClient $script:handler
        }

        It "keeps the icon the page declares" {
            $script:handler.Answers["https://example.org/"] = [System.Text.Encoding]::UTF8.GetBytes('<link rel="apple-touch-icon" href="/t.png">')
            $script:handler.Answers["https://example.org/t.png"] = New-TestPng 128
            $path = Save-WinUtilRedesignOfficialIcon -Key "myapp" -Link "https://example.org/" -Folder $script:folder -Client $script:client
            $path | Should -Be (Join-Path $script:folder "myapp.png")
            Test-Path -LiteralPath $path | Should -BeTrue
        }

        It "skips an image that is too small and takes the next candidate" {
            $script:handler.Answers["https://example.org/"] = [System.Text.Encoding]::UTF8.GetBytes('<link rel="apple-touch-icon" href="/tiny.png"><link rel="icon" type="image/png" href="/ok.png" sizes="64x64">')
            $script:handler.Answers["https://example.org/tiny.png"] = New-TestPng 16
            $script:handler.Answers["https://example.org/ok.png"] = New-TestPng 64
            $path = Save-WinUtilRedesignOfficialIcon -Key "myapp" -Link "https://example.org/" -Folder $script:folder -Client $script:client
            $path | Should -Be (Join-Path $script:folder "myapp.png")
            [System.IO.File]::ReadAllBytes($path).Length | Should -Be ((New-TestPng 64).Length)
        }

        It "ignores an answer that is not an image" {
            $script:handler.Answers["https://example.org/"] = [System.Text.Encoding]::UTF8.GetBytes('<link rel="icon" href="/fake.png">')
            $script:handler.Answers["https://example.org/fake.png"] = [System.Text.Encoding]::UTF8.GetBytes("<html>not an image at all, just text pretending</html>")
            Save-WinUtilRedesignOfficialIcon -Key "myapp" -Link "https://example.org/" -Folder $script:folder -Client $script:client | Should -BeNullOrEmpty
        }

        It "uses the picture of the owner for a GitHub project, without reading the project page" {
            $script:handler.Answers["https://github.com/some-owner.png?size=128"] = New-TestPng 128
            $path = Save-WinUtilRedesignOfficialIcon -Key "ghapp" -Link "https://github.com/some-owner/some-repo/" -Folder $script:folder -Client $script:client
            $path | Should -Be (Join-Path $script:folder "ghapp.png")
            $script:handler.Requested | Should -Not -Contain "https://github.com/some-owner/some-repo/"
        }

        It "remembers that there is no icon when a server answered but had none" {
            $script:handler.Answers["https://example.org/"] = [System.Text.Encoding]::UTF8.GetBytes("<html></html>")
            Save-WinUtilRedesignOfficialIcon -Key "noicon" -Link "https://example.org/" -Folder $script:folder -Client $script:client | Should -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $script:folder "noicon.none") | Should -BeTrue
        }

        It "does not remember anything when the network was down" {
            $script:handler.NetworkDown = $true
            Save-WinUtilRedesignOfficialIcon -Key "offline" -Link "https://example.org/" -Folder $script:folder -Client $script:client | Should -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $script:folder "offline.none") | Should -BeFalse
            @(Get-ChildItem -LiteralPath $script:folder).Count | Should -Be 0
        }

        It "does not throw on an address that is not one" {
            { Save-WinUtilRedesignOfficialIcon -Key "bad" -Link "not a link" -Folder $script:folder -Client $script:client } | Should -Not -Throw
        }
    }
}
