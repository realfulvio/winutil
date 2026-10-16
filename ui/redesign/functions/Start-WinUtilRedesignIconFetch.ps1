function Start-WinUtilRedesignIconFetch {
    <#
    .SYNOPSIS
        Downloads, in the background, the icons the cache does not have yet.

    .DESCRIPTION
        Four workers of the redesign's own pool (not the one jobs run on, so an install never waits for
        icons and closing the window never waits for them either) take the programs one by one
        from a queue. Each finished icon is handed to the interface thread, which swaps it into
        the card. Nothing happens offline, and a program that was tried within the last week and
        had no usable icon is not tried again.

    .PARAMETER Items
        The programs to look for, as Get-WinUtilRedesignProgramItems returns them.
    #>
    param(
        [Parameter(Mandatory)]
        [object[]]$Items
    )

    if ($PARAM_OFFLINE -or $sync.RedesignIconFetchStarted) {
        return
    }

    $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    foreach ($item in $Items) {
        $name = $item.Short.ToLowerInvariant()
        if ($item.Link -and -not $sync.RedesignIconFiles.ContainsKey($name) -and -not $sync.RedesignIconMisses.ContainsKey($name)) {
            $queue.Enqueue([pscustomobject]@{ Key = $item.Key; Name = $name; Link = $item.Link })
        }
    }
    if ($queue.IsEmpty) {
        return
    }
    $sync.RedesignIconFetchStarted = $true
    $folder = Get-WinUtilRedesignIconFolder -Create

    try {
        $pool = Get-WinUtilRedesignBackgroundPool
    } catch {
        Write-WinUtilLog -Level 'WARN' -Component 'Icons' -Message "Could not start the icon downloads: $($_.Exception.Message)"
        return
    }
    Write-WinUtilLog -Component 'Icons' -Message "Downloading $($queue.Count) program icon(s) in the background."

    $worker = {
        param($Queue, $Folder)

        # A parameter of its own, because a worker runs in a runspace with no window: the
        # assemblies the downloader and the decoder use are loaded here
        Add-Type -AssemblyName System.Net.Http, PresentationCore, WindowsBase
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromSeconds(10)
        $null = $client.DefaultRequestHeaders.TryAddWithoutValidation('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WinUtilIcons/1.0')
        $null = $client.DefaultRequestHeaders.TryAddWithoutValidation('Accept-Language', 'en,it;q=0.8')
        try {
            $entry = $null
            while (-not $sync.ShuttingDown -and -not $sync.RedesignIconStop -and $Queue.TryDequeue([ref]$entry)) {
                $path = Save-WinUtilRedesignOfficialIcon -Key $entry.Name -Link $entry.Link -Folder $Folder -Client $client
                if ($path) {
                    Invoke-WPFUIThread -Async -Parameters @{ Key = $entry.Key; Name = $entry.Name; Path = $path } -ScriptBlock {
                        param($Key, $Name, $Path)
                        $sync.RedesignIconFiles[$Name] = $Path
                        Set-WinUtilRedesignCardIcon -Key $Key
                    }
                }
            }
        } finally {
            $client.Dispose()
        }
    }

    $sync.RedesignIconWorkers = @()
    foreach ($number in 1..4) {
        $shell = [powershell]::Create()
        $shell.RunspacePool = $pool
        $null = $shell.AddScript($worker.ToString()).AddArgument($queue).AddArgument($folder)
        $sync.RedesignIconWorkers += [pscustomobject]@{ Shell = $shell; Handle = $shell.BeginInvoke() }
    }

    # The workers are background threads and end with the process; this only stops them taking
    # new programs once the window is closed
    $sync.Form.Add_Closed({ $sync.RedesignIconStop = $true })
}
