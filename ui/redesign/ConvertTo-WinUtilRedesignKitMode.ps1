function ConvertTo-WinUtilRedesignKitMode {
    <#
    .SYNOPSIS
        Adds the -Kit and -Installa parameters to the start and main scripts of a redesign build.

    .DESCRIPTION
        scripts/start.ps1 and scripts/main.ps1 are upstream files and stay as they are; the
        default build must not change. The redesign build gets three edits at compile time:
        the two parameters, the "wait for the elevated run" test that now also covers a kit, and
        ui/redesign/main-kit.ps1 in front of the part of main.ps1 that starts the window.
        Throws when an anchor is not found exactly once, so a change upstream fails the build
        instead of leaving the kit mode half wired.

    .PARAMETER StartScript
        The text of scripts/start.ps1.

    .PARAMETER MainScript
        The text of scripts/main.ps1.

    .PARAMETER KitBlock
        The text of ui/redesign/main-kit.ps1.

    .OUTPUTS
        An object with Start and Main, the edited texts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$StartScript,
        [Parameter(Mandatory)][string]$MainScript,
        [Parameter(Mandatory)][string]$KitBlock
    )

    # A match evaluator instead of a replacement string: the kit block is full of "$" that the
    # replacement syntax of .NET would read as group references
    function Edit-Once([string]$Text, [string]$Pattern, [scriptblock]$With, [string]$What) {
        $found = [regex]::Matches($Text, $Pattern).Count
        if ($found -ne 1) {
            throw "Kit mode: expected $What exactly once in the upstream script, found $found. Update ConvertTo-WinUtilRedesignKitMode."
        }
        $evaluator = [System.Text.RegularExpressions.MatchEvaluator]$With
        return [regex]::Replace($Text, $Pattern, $evaluator)
    }

    $start = Edit-Once -Text $StartScript -Pattern '\[switch\]\$Offline(\r?\n)\)' -With {
        param($match)
        $null = $match
        $newline = $match.Groups[1].Value
        '[switch]$Offline,' + $newline + '    [string]$Kit,' + $newline + '    [switch]$Installa' + $newline + ')'
    } -What 'the end of the param block'

    $start = Edit-Once -Text $start -Pattern '\$Config -or \$Preset\) \{' -With {
        param($match)
        $null = $match
        '$Config -or $Preset -or $Kit -or $Installa) {'
    } -What 'the headless wait test'

    $block = $KitBlock.TrimEnd() + "`r`n`r`n"
    $main = Edit-Once -Text $MainScript -Pattern '(?m)^#=+\r?\n# Start the interface on its own thread' -With {
        param($match)
        $null = $match
        $block + '#===========================================================================' + "`r`n" + '# Start the interface on its own thread'
    } -What 'the interface start section'

    return [pscustomobject]@{ Start = $start; Main = $main }
}
