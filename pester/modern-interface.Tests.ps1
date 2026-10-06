BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    . "$script:root/ui/modern/ConvertTo-WinUtilModernInterface.ps1"
    $script:originalXaml = Get-Content "$script:root/xaml/inputXML.xaml" -Raw
    $script:originalThemes = Get-Content "$script:root/config/themes.json" -Raw | ConvertFrom-Json
    $script:modern = ConvertTo-WinUtilModernInterface -Xaml $script:originalXaml -Themes $script:originalThemes
    $script:original = [xml]$script:originalXaml
    $script:transformed = [xml]$script:modern.Xaml
    Add-Type -AssemblyName PresentationFramework
}

Describe 'Personal interface compatibility boundary' {
    It 'preserves every named control and its WPF type' {
        $before = @($script:original.SelectNodes('//*[@Name]') | ForEach-Object { "$($_.LocalName):$($_.GetAttribute('Name'))" }) | Sort-Object
        $after = @($script:transformed.SelectNodes('//*[@Name]') | ForEach-Object { "$($_.LocalName):$($_.GetAttribute('Name'))" }) | Sort-Object
        Compare-Object $before $after | Should -BeNullOrEmpty
    }

    It 'preserves all six tabs and their complete feature content' {
        $before = $script:original.SelectSingleNode('//*[@Name="WPFTabNav"]')
        $after = $script:transformed.SelectSingleNode('//*[@Name="WPFTabNav"]')
        $before.SelectNodes('./*[local-name()="TabItem"]').Count | Should -Be 6
        $after.InnerXml | Should -BeExactly $before.InnerXml
    }

    It 'does not mutate the input themes and retains all theme keys' {
        $disk = Get-Content "$script:root/config/themes.json" -Raw | ConvertFrom-Json
        ($script:originalThemes | ConvertTo-Json -Depth 10) | Should -BeExactly ($disk | ConvertTo-Json -Depth 10)
        foreach ($group in $disk.PSObject.Properties) {
            Compare-Object @($group.Value.PSObject.Properties.Name) @($script:modern.Themes.($group.Name).PSObject.Properties.Name) | Should -BeNullOrEmpty
        }
    }

    It 'loads both complete variants through the real WPF XAML reader' {
        foreach ($markup in @($script:originalXaml, $script:modern.Xaml)) {
            $window = [System.Windows.Markup.XamlReader]::Parse($markup)
            try {
                $window.FindName('WPFTabNav').Items.Count | Should -Be 6
                $window.FindName('SearchBar') | Should -Not -BeNullOrEmpty
                $window.FindName('WPFUndoall') | Should -Not -BeNullOrEmpty
            } finally { $window.Close() }
        }
    }

    It 'rejects incompatible upstream shell changes instead of producing a partial interface' {
        { ConvertTo-WinUtilModernInterface -Xaml ($script:originalXaml.Replace('Name="NavDockPanel"', 'Name="ChangedPanel"')) -Themes $script:originalThemes } | Should -Throw '*shell contract changed*'
    }

    It 'compiles both variants without modifying original UI inputs or shipping adapter functions' {
        Push-Location $script:root
        try {
            $sourceHashes = @(Get-FileHash xaml/inputXML.xaml, config/themes.json | ForEach-Object Hash)
            ./Compile.ps1 -Interface Upstream
            $upstream = Get-Content winutil.ps1 -Raw
            $upstream.Contains($script:originalXaml) | Should -BeTrue
            ./Compile.ps1 -Interface Modern
            $compiled = Get-Content winutil.ps1 -Raw
            $compiled.Contains($script:modern.Xaml) | Should -BeTrue
            $compiled.Contains('function ConvertTo-WinUtilModernInterface') | Should -BeFalse
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseInput($compiled, [ref]$tokens, [ref]$errors) | Out-Null
            $errors | Should -BeNullOrEmpty
            Compare-Object $sourceHashes @(Get-FileHash xaml/inputXML.xaml, config/themes.json | ForEach-Object Hash) | Should -BeNullOrEmpty
        } finally { Pop-Location }
    }
}
