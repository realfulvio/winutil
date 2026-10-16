#===========================================================================
# Tests - Redesign program catalog and custom kits
#===========================================================================

Describe "Redesign program catalog and kits" {

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $redesignRoot = Join-Path $script:repoRoot "ui\redesign"
    foreach ($name in "Get-WinUtilKitFolder", "Get-WinUtilKitPackageId", "Resolve-WinUtilKitApps", "Read-WinUtilKitFile",
        "Export-WinUtilKit", "Import-WinUtilKit", "Save-WinUtilKit", "Remove-WinUtilKit", "Get-WinUtilKits",
        "Invoke-WinUtilKitHeadless", "Get-WinUtilRedesignText") {
        . (Join-Path $redesignRoot "functions\$name.ps1")
    }
    . (Join-Path $redesignRoot "ConvertTo-WinUtilRedesignKitMode.ps1")

    $script:applications = Get-Content -LiteralPath (Join-Path $script:repoRoot "config\applications.json") -Raw | ConvertFrom-Json
    $script:programs = Get-Content -LiteralPath (Join-Path $redesignRoot "programs.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:icons = Get-Content -LiteralPath (Join-Path $redesignRoot "icons.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:strings = Get-Content -LiteralPath (Join-Path $redesignRoot "strings.json") -Raw -Encoding UTF8 | ConvertFrom-Json

    # What Compile.ps1 and main.ps1 give the functions: the catalog keyed WPFInstall<key>
    $hashtable = @{}
    foreach ($property in $script:applications.PSObject.Properties) {
        $hashtable["WPFInstall$($property.Name)"] = $property.Value
    }
    $global:sync = [Hashtable]::Synchronized(@{})
    $sync.configs = @{
        applicationsHashtable = $hashtable
        redesignprograms      = $script:programs
        redesignstrings       = $script:strings
    }
    $sync.preferences = @{ language = "en" }

    function global:Write-WinUtilLog { param($Message, $Level, $Component) $null = $Message, $Level, $Component }

    $script:realAppData = $env:APPDATA
}

BeforeEach {
    # TestDrive lasts for the whole block, so each test gets a folder of its own
    $env:APPDATA = Join-Path $TestDrive ("appdata-" + [guid]::NewGuid().ToString("N"))
    $sync.preferences.language = "en"
}

AfterAll {
    $env:APPDATA = $script:realAppData
    foreach ($name in "Write-WinUtilLog", "Update-WinUtilSelections", "Invoke-WinUtilAutoRun", "Write-WinUtilAutoRunSummary") {
        Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue
    }
    Remove-Variable -Name sync, KitTestSelected, KitTestRan -Scope Global -ErrorAction SilentlyContinue
}

Describe "Program catalog data" {
    It "describes every application in Italian, and only applications that exist" {
        $catalog = $script:applications.PSObject.Properties.Name
        $described = $script:programs.apps.PSObject.Properties.Name
        ($catalog | Where-Object { $_ -notin $described }) | Should -BeNullOrEmpty
        ($described | Where-Object { $_ -notin $catalog }) | Should -BeNullOrEmpty
        foreach ($name in $catalog) {
            [string]$script:programs.apps.$name.it | Should -Not -BeNullOrEmpty -Because "$name is shown with that line"
            $script:programs.apps.$name.it.Length | Should -BeLessOrEqual 90 -Because "$name must fit a card"
        }
    }

    It "names a category for every category the catalog uses" {
        $used = $script:applications.PSObject.Properties.Value.category | Sort-Object -Unique
        foreach ($category in $used) {
            $script:programs.categories.$category | Should -Not -BeNullOrEmpty -Because "$category is a chip"
            $script:programs.categories.$category.it | Should -Not -BeNullOrEmpty
            $script:programs.categories.$category.en | Should -Not -BeNullOrEmpty
            $script:programs.categories.$category.glyph | Should -Match '^[0-9A-Fa-f]{4}$'
        }
    }

    It "points every icon slug at an outline that is bundled" {
        foreach ($property in $script:programs.apps.PSObject.Properties) {
            $slug = $property.Value.icon
            if ($slug) {
                $script:icons.$slug | Should -Not -BeNullOrEmpty -Because "$($property.Name) uses $slug"
            }
        }
    }

    It "holds only well-formed brand outlines" {
        foreach ($property in $script:icons.PSObject.Properties) {
            $property.Value.hex | Should -Match '^[0-9A-Fa-f]{6}$'
            $property.Value.path | Should -Match '^M[\d\s\-\.,a-zA-Z]+$'
        }
    }

    It "builds the built-in kits from applications the catalog has" {
        $kits = Get-WinUtilKits -Language en
        $kits.Count | Should -Be 3
        ($kits | ForEach-Object Name) | Should -Be @("Office", "Development", "Gaming")
        foreach ($kit in $kits) {
            $kit.Custom | Should -BeFalse
            foreach ($key in $kit.AppKeys) {
                $sync.configs.applicationsHashtable.ContainsKey($key) | Should -BeTrue
            }
        }
        (Get-WinUtilKits -Language it | ForEach-Object Name) | Should -Be @("Ufficio", "Sviluppo", "Gaming")
    }

    It "leaves out silently a built-in kit application the catalog no longer has" {
        $original = $sync.configs.redesignprograms
        $copy = $original | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $copy.kits[0].apps = @("libreoffice", "does-not-exist")
        $sync.configs.redesignprograms = $copy
        try {
            $kit = Get-WinUtilKits | Where-Object Id -eq "office"
            $kit.AppKeys | Should -Be @("WPFInstalllibreoffice")
        } finally {
            $sync.configs.redesignprograms = $original
        }
    }
}

Describe "Kit package IDs" {
    It "prefers the WinGet ID, then the Chocolatey one" {
        Get-WinUtilKitPackageId -App ([pscustomobject]@{ winget = "7zip.7zip"; choco = "7zip" }) | Should -Be "7zip.7zip"
        Get-WinUtilKitPackageId -App ([pscustomobject]@{ winget = "na"; choco = "somepackage" }) | Should -Be "somepackage"
        Get-WinUtilKitPackageId -App ([pscustomobject]@{ winget = ""; choco = "somepackage" }) | Should -Be "somepackage"
        Get-WinUtilKitPackageId -App ([pscustomobject]@{ winget = "na"; choco = "na" }) | Should -BeNullOrEmpty
    }

    It "gives every catalog application an ID" {
        foreach ($entry in $sync.configs.applicationsHashtable.GetEnumerator()) {
            Get-WinUtilKitPackageId -App $entry.Value | Should -Not -BeNullOrEmpty -Because "$($entry.Key) must be exportable"
        }
    }

    It "resolves IDs back to the same applications, ignoring case" {
        $ids = "7zip.7zip", "VIDEOLAN.VLC"
        $resolved = Resolve-WinUtilKitApps -PackageIds $ids
        $resolved.AppKeys | Should -Be @("WPFInstall7zip", "WPFInstallvlc")
        $resolved.Skipped | Should -Be 0
    }

    It "counts the IDs it does not know and lists an application once" {
        $resolved = Resolve-WinUtilKitApps -PackageIds @("7zip.7zip", "No.Such.Package", "7zip.7zip", "another.missing")
        $resolved.AppKeys | Should -Be @("WPFInstall7zip")
        $resolved.Skipped | Should -Be 2
    }
}

Describe "Custom kits" {
    It "saves a kit in the kits folder and lists it with the built-in ones" {
        $saved = Save-WinUtilKit -Name "Front desk" -Description "Standard apps" -Color 3 -AppKeys @("WPFInstall7zip", "WPFInstallvlc")
        $saved.Custom | Should -BeTrue
        $saved.Name | Should -Be "Front desk"
        $saved.Color | Should -Be 3
        $saved.AppKeys | Should -Be @("WPFInstall7zip", "WPFInstallvlc")
        $saved.Path | Should -Be (Join-Path (Join-Path (Join-Path $env:APPDATA "WinUtil") "kits") "front-desk.json")
        Test-Path -LiteralPath $saved.Path | Should -BeTrue

        $names = Get-WinUtilKits | ForEach-Object Name
        $names | Should -Be @("Office", "Development", "Gaming", "Front desk")
    }

    It "stores IDs, not display names" {
        $saved = Save-WinUtilKit -Name "IDs" -AppKeys @("WPFInstall7zip")
        $file = Get-Content -LiteralPath $saved.Path -Raw -Encoding UTF8 | ConvertFrom-Json
        $file.formato | Should -Be "winutil-kit"
        $file.versione | Should -Be 1
        @($file.programmi) | Should -Be @("7zip.7zip")
    }

    It "needs a name and at least one program" {
        { Save-WinUtilKit -Name "   " -AppKeys @("WPFInstall7zip") } | Should -Throw
        try { Save-WinUtilKit -Name "   " -AppKeys @("WPFInstall7zip") } catch { $_.Exception.Data["KitError"] | Should -Be "NoName" }
        try { Save-WinUtilKit -Name "Empty" -AppKeys @("WPFInstallnope") } catch { $_.Exception.Data["KitError"] | Should -Be "NoPrograms" }
    }

    It "replaces a kit saved again under the same name" {
        $null = Save-WinUtilKit -Name "Same" -AppKeys @("WPFInstall7zip")
        $null = Save-WinUtilKit -Name "Same" -AppKeys @("WPFInstallvlc", "WPFInstall7zip")
        $custom = @(Get-WinUtilKits | Where-Object Custom)
        $custom.Count | Should -Be 1
        $custom[0].AppKeys.Count | Should -Be 2
    }

    It "keeps two names that give the same file name apart" {
        $first = Save-WinUtilKit -Name "My kit" -AppKeys @("WPFInstall7zip")
        $second = Save-WinUtilKit -Name "My-kit!" -AppKeys @("WPFInstallvlc")
        $first.Path | Should -Not -Be $second.Path
        @(Get-WinUtilKits | Where-Object Custom).Count | Should -Be 2
    }

    It "accepts accented names" {
        $name = "Postazione Ufficio Tributi $([char]0xE8) cos$([char]0xEC)"
        $saved = Save-WinUtilKit -Name $name -AppKeys @("WPFInstall7zip")
        (Get-WinUtilKits | Where-Object Custom | Select-Object -First 1).Name | Should -Be $name
        Test-Path -LiteralPath $saved.Path | Should -BeTrue
    }

    It "deletes a custom kit and nothing outside the kits folder" {
        $saved = Save-WinUtilKit -Name "To delete" -AppKeys @("WPFInstall7zip")
        Remove-WinUtilKit -Kit $saved
        Test-Path -LiteralPath $saved.Path | Should -BeFalse

        $outside = Join-Path $TestDrive "outside.json"
        Set-Content -LiteralPath $outside -Value "{}"
        { Remove-WinUtilKit -Kit ([pscustomobject]@{ Custom = $true; Path = $outside; Name = "x" }) } | Should -Throw
        Test-Path -LiteralPath $outside | Should -BeTrue
        { Remove-WinUtilKit -Kit (Get-WinUtilKits | Select-Object -First 1) } | Should -Throw
    }

    It "skips a damaged kit file and still lists the others" {
        $null = Save-WinUtilKit -Name "Good" -AppKeys @("WPFInstall7zip")
        Set-Content -LiteralPath (Join-Path (Get-WinUtilKitFolder) "broken.json") -Value "{ not json"
        $custom = @(Get-WinUtilKits | Where-Object Custom)
        $custom.Count | Should -Be 1
        $custom[0].Name | Should -Be "Good"
    }
}

Describe "Kit export and import" {
    It "writes the documented format with package IDs" {
        $kit = Save-WinUtilKit -Name "Export me" -Description "d" -AppKeys @("WPFInstall7zip", "WPFInstallvlc")
        $target = Join-Path $TestDrive "export-me.winutil-kit.json"
        Export-WinUtilKit -Kit $kit -Path $target | Should -Be $target
        $json = Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json
        @($json.PSObject.Properties.Name) | Should -Be @("formato", "versione", "nome", "descrizione", "programmi")
        $json.formato | Should -Be "winutil-kit"
        $json.versione | Should -Be 1
        $json.nome | Should -Be "Export me"
        $json.descrizione | Should -Be "d"
        @($json.programmi) | Should -Be @("7zip.7zip", "VideoLAN.VLC")
        [System.IO.File]::ReadAllBytes($target)[0] | Should -Not -Be 0xEF -Because "no byte order mark"
    }

    It "round-trips: what one PC exports another imports" {
        # Escapes, not the letters: Windows PowerShell reads a script without a byte order mark as ANSI
        $name = "Round trip $([char]0xE8) $([char]0x20AC)"
        $kit = Save-WinUtilKit -Name $name -Description "Descrizione" -Color 2 -AppKeys @("WPFInstall7zip", "WPFInstallvlc", "WPFInstallfirefox")
        $target = Join-Path $TestDrive "trip.winutil-kit.json"
        $null = Export-WinUtilKit -Kit $kit -Path $target

        $imported = Import-WinUtilKit -Path $target
        $imported.Name | Should -Be $name
        $imported.Description | Should -Be "Descrizione"
        $imported.AppKeys | Should -Be $kit.AppKeys
        $imported.Skipped | Should -Be 0
        $imported.Color | Should -BeIn @(0, 1, 2, 3, 4)
    }

    It "exports a built-in kit too" {
        $office = Get-WinUtilKits | Where-Object Id -eq "office"
        $target = Join-Path $TestDrive "office.winutil-kit.json"
        $null = Export-WinUtilKit -Kit $office -Path $target
        (Import-WinUtilKit -Path $target).AppKeys | Should -Be $office.AppKeys
    }

    It "refuses a folder that does not exist" {
        $kit = Get-WinUtilKits | Select-Object -First 1
        { Export-WinUtilKit -Kit $kit -Path (Join-Path $TestDrive "no\such\folder\kit.winutil-kit.json") } | Should -Throw
    }

    It "skips programs the catalog does not have and says how many" {
        $path = Join-Path $TestDrive "partial.winutil-kit.json"
        '{"formato":"winutil-kit","versione":1,"nome":"Partial","descrizione":"","programmi":["7zip.7zip","Vendor.Unknown","Other.Missing","VideoLAN.VLC"]}' | Set-Content -LiteralPath $path -Encoding UTF8
        $imported = Import-WinUtilKit -Path $path
        $imported.AppKeys | Should -Be @("WPFInstall7zip", "WPFInstallvlc")
        $imported.Skipped | Should -Be 2
    }

    It "reports a kit whose programs are all unknown" {
        $path = Join-Path $TestDrive "unknown.winutil-kit.json"
        '{"formato":"winutil-kit","versione":1,"nome":"Unknown","descrizione":"","programmi":["Vendor.Unknown"]}' | Set-Content -LiteralPath $path -Encoding UTF8
        try { Import-WinUtilKit -Path $path; throw "should have failed" } catch { $_.Exception.Data["KitError"] | Should -Be "Empty" }
    }

    It "reads a file saved with a byte order mark" {
        $path = Join-Path $TestDrive "bom.winutil-kit.json"
        [System.IO.File]::WriteAllText($path, '{"formato":"winutil-kit","versione":1,"nome":"Bom","descrizione":"","programmi":["7zip.7zip"]}', [System.Text.UTF8Encoding]::new($true))
        (Import-WinUtilKit -Path $path).Name | Should -Be "Bom"
    }
}

Describe "Invalid kit files" {
    It "rejects <Why> with the code <Code>" -ForEach @(
        @{ Why = "not JSON";              Code = "InvalidJson"; Body = "this is not json" }
        @{ Why = "an empty file";         Code = "InvalidJson"; Body = "" }
        @{ Why = "a JSON array";          Code = "BadFormat";   Body = '["7zip.7zip"]' }
        @{ Why = "another format";        Code = "BadFormat";   Body = '{"formato":"other","versione":1,"nome":"x","programmi":["7zip.7zip"]}' }
        @{ Why = "no format field";       Code = "BadFormat";   Body = '{"versione":1,"nome":"x","programmi":["7zip.7zip"]}' }
        @{ Why = "a newer version";       Code = "BadVersion";  Body = '{"formato":"winutil-kit","versione":2,"nome":"x","programmi":["7zip.7zip"]}' }
        @{ Why = "no version";            Code = "BadVersion";  Body = '{"formato":"winutil-kit","nome":"x","programmi":["7zip.7zip"]}' }
        @{ Why = "a blank name";          Code = "NoName";      Body = '{"formato":"winutil-kit","versione":1,"nome":"  ","programmi":["7zip.7zip"]}' }
        @{ Why = "no programs";           Code = "NoPrograms";  Body = '{"formato":"winutil-kit","versione":1,"nome":"x","programmi":[]}' }
        @{ Why = "programs not a list";   Code = "NoPrograms";  Body = '{"formato":"winutil-kit","versione":1,"nome":"x","programmi":"7zip.7zip"}' }
        @{ Why = "a program that is not an ID"; Code = "BadFormat"; Body = '{"formato":"winutil-kit","versione":1,"nome":"x","programmi":["7zip.7zip",42]}' }
    ) {
        $path = Join-Path $TestDrive "bad.winutil-kit.json"
        Set-Content -LiteralPath $path -Value $Body -Encoding UTF8
        $thrown = $null
        try { $null = Import-WinUtilKit -Path $path } catch { $thrown = $_ }
        $thrown | Should -Not -BeNullOrEmpty
        $thrown.Exception.Data["KitError"] | Should -Be $Code
    }

    It "rejects a file that is not there" {
        try { $null = Import-WinUtilKit -Path (Join-Path $TestDrive "missing.winutil-kit.json"); throw "should have failed" } catch { $_.Exception.Data["KitError"] | Should -Be "NotFound" }
    }
}

Describe "Kit mode from the command line" {
    BeforeAll {
        # Doubles for the upstream pieces the headless run drives; they change nothing
        function global:Update-WinUtilSelections { param([string[]]$flatJson, [switch]$Replace) $global:KitTestSelected = $flatJson; $null = $Replace }
        function global:Invoke-WinUtilAutoRun { $global:KitTestRan = $true; [pscustomobject]@{ Steps = @([pscustomobject]@{ Name = "Applications"; Items = 1; Seconds = 0; Errors = 0; Warnings = 0; TimedOut = $false }); Failed = 0; TimedOut = 0; Errors = 0; Warnings = 0 } }
        function global:Write-WinUtilAutoRunSummary { param($Summary) $null = $Summary; 0 }
        $script:kitFile = Join-Path $TestDrive "cli.winutil-kit.json"
        '{"formato":"winutil-kit","versione":1,"nome":"Postazione","descrizione":"","programmi":["7zip.7zip","Vendor.Unknown","VideoLAN.VLC"]}' | Set-Content -LiteralPath $script:kitFile -Encoding UTF8
    }

    BeforeEach {
        $global:KitTestSelected = $null
        $global:KitTestRan = $false
    }

    It "installs nothing without -Installa" {
        $code = Invoke-WinUtilKitHeadless -Path $script:kitFile 6>$null
        $code | Should -Be 0
        $global:KitTestRan | Should -BeFalse
        $global:KitTestSelected | Should -BeNullOrEmpty
    }

    It "selects the programs of the kit and runs the install with -Installa" {
        $code = Invoke-WinUtilKitHeadless -Path $script:kitFile -Install 6>$null
        $code | Should -Be 0
        $global:KitTestRan | Should -BeTrue
        $global:KitTestSelected | Should -Be @("WPFInstall7zip", "WPFInstallvlc")
    }

    It "fails with 1 on a kit that cannot be read, without running anything" {
        $bad = Join-Path $TestDrive "cli-bad.winutil-kit.json"
        Set-Content -LiteralPath $bad -Value "nope"
        (Invoke-WinUtilKitHeadless -Path $bad -Install 6>$null) | Should -Be 1
        $global:KitTestRan | Should -BeFalse
    }

    It "fails with 2 when -Installa has no kit" {
        (Invoke-WinUtilKitHeadless -Install 6>$null) | Should -Be 2
    }

    It "speaks Italian when the interface language is Italian" {
        $sync.preferences.language = "it"
        $text = Invoke-WinUtilKitHeadless -Path $script:kitFile 6>&1 | Out-String
        $text | Should -Match "non sono nel catalogo"
        $text | Should -Match "Aggiungi -Installa"
    }
}

Describe "Kit mode in the compiled script" {
    BeforeAll {
        $script:startText = Get-Content -LiteralPath (Join-Path $script:repoRoot "scripts\start.ps1") -Raw
        $script:mainText = Get-Content -LiteralPath (Join-Path $script:repoRoot "scripts\main.ps1") -Raw
        $script:blockText = Get-Content -LiteralPath (Join-Path $script:repoRoot "ui\redesign\main-kit.ps1") -Raw
    }

    It "adds -Kit and -Installa, the elevation wait and the kit block, and keeps everything else" {
        $result = ConvertTo-WinUtilRedesignKitMode -StartScript $script:startText -MainScript $script:mainText -KitBlock $script:blockText
        $result.Start | Should -Match '\[switch\]\$Offline,\s+\[string\]\$Kit,\s+\[switch\]\$Installa\s+\)'
        $result.Start | Should -Match ([regex]::Escape('if ($Config -or $Preset -or $Kit -or $Installa) {'))
        $result.Main | Should -Match ([regex]::Escape('Invoke-WinUtilKitHeadless -Path $Kit -Install:$Installa'))
        $result.Main.IndexOf('Invoke-WinUtilKitHeadless') | Should -BeLessThan $result.Main.IndexOf('# Start the interface on its own thread')
        # The block is inserted verbatim: dollar signs in it must survive
        $result.Main | Should -Match ([regex]::Escape('$global:LASTEXITCODE = $kitExitCode'))
        $result.Main | Should -Match ([regex]::Escape('Write-WinUtilErrorRecord -ErrorRecord $_ -Component "Kits"'))
        $result.Main | Should -Match '(?m)^# Start the interface on its own thread'
    }

    It "leaves the originals alone" {
        $null = ConvertTo-WinUtilRedesignKitMode -StartScript $script:startText -MainScript $script:mainText -KitBlock $script:blockText
        $script:startText | Should -Not -Match 'Installa'
        $script:mainText | Should -Not -Match 'Invoke-WinUtilKitHeadless'
    }

    It "fails the build when an anchor of the upstream scripts disappears" {
        { ConvertTo-WinUtilRedesignKitMode -StartScript ($script:startText -replace '\[switch\]\$Offline', '[switch]$Elsewhere') -MainScript $script:mainText -KitBlock $script:blockText } | Should -Throw "*param block*"
        { ConvertTo-WinUtilRedesignKitMode -StartScript ($script:startText -replace '\$Config -or \$Preset\) \{', 'x') -MainScript $script:mainText -KitBlock $script:blockText } | Should -Throw "*headless wait*"
        { ConvertTo-WinUtilRedesignKitMode -StartScript $script:startText -MainScript ($script:mainText -replace 'Start the interface on its own thread', 'Elsewhere') -KitBlock $script:blockText } | Should -Throw "*interface start*"
    }
}

}
