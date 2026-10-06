BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $repoRoot 'ui\redesign\ConvertTo-WinUtilRedesignInterface.ps1')
    $upstreamXaml = Get-Content -LiteralPath (Join-Path $repoRoot 'xaml\inputXML.xaml') -Raw
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

    It "fails the build when an upstream control it depends on disappears" {
        $broken = $upstreamXaml -replace 'Name="WPFTweaksProgressBar"', 'Name="WPFSomethingElse"'
        { ConvertTo-WinUtilRedesignInterface -Xaml $broken } | Should -Throw "*WPFTweaksProgressBar*"
    }
}

Describe "Compile.ps1 interface switch" {
    It "defaults to the upstream interface" {
        $compile = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'Compile.ps1') -Raw
        $compile | Should -Match "\[string\]\`$Interface = 'Upstream'"
    }
}
