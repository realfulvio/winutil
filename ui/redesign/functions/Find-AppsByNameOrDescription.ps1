function Find-AppsByNameOrDescription {
    <#
    .SYNOPSIS
        Filters the program cards by the search text.

    .DESCRIPTION
        The upstream function is renamed to Find-AppsByNameOrDescriptionUpstream when the redesign
        is compiled (see Convert-WinUtilRedesignFunctionSource); it filters upstream's own list,
        which the redesigned window does not show. Upstream's search box, tab switch and render
        loop still call this name, so it is answered here.

    .PARAMETER SearchString
        The text to look for. Matching is literal.

    .PARAMETER Categories
        Not used: the redesign filters by category with its own chips.
    #>
    param(
        [string]$SearchString = "",

        [string[]]$Categories = @()
    )
    $null = $Categories

    Update-WinUtilRedesignProgramFilter -SearchString $SearchString
}
