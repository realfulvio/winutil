function Set-WinUtilRedesignFocus {
    <#
    .SYNOPSIS
        Puts a tweak in focus: highlights its card and shows it in the right panel.

    .PARAMETER Name
        The tweak key, for example WPFTweaksTelemetry.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $sync.RedesignFocus = $Name
    Update-WinUtilRedesignCardStates
    Update-WinUtilRedesignDetails
}
