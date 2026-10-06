BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $repoRoot 'ui\redesign\ConvertTo-WinUtilRedesignInterface.ps1')
    $upstreamXaml = Get-Content -LiteralPath (Join-Path $repoRoot 'xaml\inputXML.xaml') -Raw
    $tweaks = Get-Content -LiteralPath (Join-Path $repoRoot 'config\tweaks.json') -Raw | ConvertFrom-Json
    $strings = Get-Content -LiteralPath (Join-Path $repoRoot 'ui\redesign\strings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $themes = Get-Content -LiteralPath (Join-Path $repoRoot 'config\themes.json') -Raw | ConvertFrom-Json
    $cardTweaks = @($tweaks.PSObject.Properties | Where-Object { $_.Value.Type -notin @('Toggle', 'ToggleButton', 'Combobox', 'Button', 'RadioButton', 'Note') } | ForEach-Object Name)
}

Describe "Redesign interface adapter" {
    It "returns well-formed XAML for the upstream window" {
        $result = ConvertTo-WinUtilRedesignInterface -Xaml $upstreamXaml
        { [xml]$result } | Should -Not -Throw
    }

    It "keeps every named control of the upstream window" {
        $upstreamNames = ([xml]$upstreamXaml).SelectNodes('//*[@Name]') | ForEach-Object { $_.GetAttribute('Name') }
        $result = [xml](ConvertTo-WinUtilRedesignInterface -Xaml $upstreamXaml)
        $resultNames = $result.SelectNodes('//*[@Name]') | ForEach-Object { $_.GetAttribute('Name') }
        $missing = $upstreamNames | Where-Object { $_ -notin $resultNames }
        $missing | Should -BeNullOrEmpty
    }

    It "adds the sixth tab button so the AppX tab has a sidebar entry" {
        $result = [xml](ConvertTo-WinUtilRedesignInterface -Xaml $upstreamXaml)
        $result.SelectSingleNode("//*[@Name='WPFTab6BT']") | Should -Not -BeNullOrEmpty
    }

    It "has no unique-name clash outside templates and no leftover slot" {
        $result = [xml](ConvertTo-WinUtilRedesignInterface -Xaml $upstreamXaml)
        $result.SelectNodes('//*[@Slot]').Count | Should -Be 0
        $windowLevel = '//*[@Name][not(ancestor::*[local-name()="ControlTemplate" or local-name()="DataTemplate"])]'
        $names = $result.SelectNodes($windowLevel) | ForEach-Object { $_.GetAttribute('Name') }
        ($names | Group-Object | Where-Object Count -gt 1) | Should -BeNullOrEmpty
    }

    It "keeps the compiled script ASCII by writing non-ASCII characters as references" {
        $result = ConvertTo-WinUtilRedesignInterface -Xaml $upstreamXaml
        $result -match '[^\u0000-\u007F]' | Should -BeFalse
    }

    It "fails the build when an upstream control it depends on disappears" {
        $broken = $upstreamXaml -replace 'Name="WPFTweaksProgressBar"', 'Name="WPFSomethingElse"'
        { ConvertTo-WinUtilRedesignInterface -Xaml $broken } | Should -Throw "*WPFTweaksProgressBar*"
    }
}

Describe "Redesign theme tokens" {
    It "override only keys that exist upstream, for both themes" {
        { ConvertTo-WinUtilRedesignThemes -Themes $themes } | Should -Not -Throw
        $result = ConvertTo-WinUtilRedesignThemes -Themes $themes
        $result.Dark.MainBackgroundColor | Should -Be '#0A0F1C'
        $result.Light.MainBackgroundColor | Should -Be '#0A0F1C'
    }

    It "does not modify the theme object it is given" {
        $before = $themes.Dark.MainBackgroundColor
        $null = ConvertTo-WinUtilRedesignThemes -Themes $themes
        $themes.Dark.MainBackgroundColor | Should -Be $before
    }
}

Describe "Redesign function wrapping" {
    It "renames the upstream definition exactly once and leaves the rest alone" {
        $source = "function Initialize-WinUtilTabContent {`n  'x'`n}`nfunction Other {`n}"
        $result = Convert-WinUtilRedesignFunctionSource -Source $source -Name 'Initialize-WinUtilTabContent'
        $result | Should -Match 'function Initialize-WinUtilTabContentUpstream \{'
        $result | Should -Match 'function Other \{'
    }

    It "refuses to wrap a function that is defined twice" {
        $source = "function A {`n}`nfunction A {`n}"
        { Convert-WinUtilRedesignFunctionSource -Source $source -Name 'A' } | Should -Throw "*more than once*"
    }

    It "wraps the two upstream functions the redesign overrides" {
        foreach ($name in 'Initialize-WinUtilTabContent', 'Find-TweaksByNameOrDescription') {
            $file = Get-ChildItem -Path (Join-Path $repoRoot 'functions') -Recurse -File | Where-Object { $_.BaseName -eq $name }
            $file | Should -Not -BeNullOrEmpty
            $text = Convert-WinUtilRedesignFunctionSource -Source (Get-Content -LiteralPath $file.FullName -Raw) -Name $name
            $text | Should -Match "function ${name}Upstream \{"
        }
    }
}

Describe "Redesign strings" {
    It "has the same UI keys in English and Italian" {
        $english = $strings.ui.en.PSObject.Properties.Name
        $italian = $strings.ui.it.PSObject.Properties.Name
        ($english | Where-Object { $_ -notin $italian }) | Should -BeNullOrEmpty
        ($italian | Where-Object { $_ -notin $english }) | Should -BeNullOrEmpty
    }

    It "describes every checkbox tweak in both languages, and only tweaks that exist" {
        ($cardTweaks | Where-Object { -not $strings.tweaks.$_ }) | Should -BeNullOrEmpty
        ($strings.tweaks.PSObject.Properties.Name | Where-Object { $_ -notin $cardTweaks }) | Should -BeNullOrEmpty
        foreach ($name in $cardTweaks) {
            foreach ($language in 'en', 'it') {
                foreach ($field in 'name', 'desc', 'what', 'eff') {
                    [string]$strings.tweaks.$name.$language.$field | Should -Not -BeNullOrEmpty -Because "$name.$language.$field is shown on the card"
                }
            }
        }
    }

    It "uses a valid category and a hexadecimal icon for every tweak" {
        foreach ($name in $cardTweaks) {
            $strings.tweaks.$name.cat | Should -BeIn @('privacy', 'system', 'advanced')
            $strings.tweaks.$name.icon | Should -Match '^[0-9A-Fa-f]{4}$'
        }
    }

    It "marks every tweak from upstream's CAUTION category as advanced" {
        foreach ($name in $cardTweaks) {
            if ([string]$tweaks.$name.category -like '*CAUTION*') {
                $strings.tweaks.$name.caution | Should -BeTrue -Because "$name is in upstream's CAUTION category"
            }
        }
    }
}

Describe "Compile.ps1 interface switch" {
    It "defaults to the upstream interface" {
        $compile = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'Compile.ps1') -Raw
        $compile | Should -Match "\[string\]\`$Interface = 'Upstream'"
    }
}
