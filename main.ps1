param(
    [parameter(Mandatory = $true)]
    [string]$SrcPath,

    [parameter(Mandatory = $true)]
    [string]$DestPath,

    [int]$PageSize = [Console]::WindowHeight - 7
)

function Get-Records {
    # Read records
    $records = Get-Content -LiteralPath $SrcPath

    if ($PageSize -lt 1) {
        throw "PageSaze must be greater than zero"
    }

    [PSCustomObject]@{
        Records = $records
    }
}

function Show-SelectionUI {
    param(
        [string[]]$Records,
        [bool[]]$Selected
    )

    # Current cursor
    $cursor = 0

    $done = $false
    $cancelled = $false


    #Calculate page information
    function Get-PageCount {
        return [Math]::Ceiling($Records.Count / [double]$PageSize)
    }

    function Draw-SelectionUI {
        [Console]::Clear()

        $page = [Math]::Floor($cursor / $PageSize)
        $start = $page * $PageSize
        $end = [Math]::Min($start + $PageSize, $Records.Count)

        Write-Host "Select records"
        Write-Host "--------------"

        for ($i = $start; $i -lt (($page + 1) * $PageSize); $i++) {
            if ($i -ge $end) {
                Write-Host ""
                continue
            }
            $marker = if ($Selected[$i]) { "X" } else { " " }
            $prefix = if ($i -eq $cursor) { ">" } else { " " }

            $line = "{0} [{1}] {2}| {3}" -f $prefix, $marker, ($i + 1).ToString().PadLeft(4), $Records[$i]

            if ($i -eq $cursor) {
                [Console]::BackgroundColor = [ConsoleColor]::DarkBlue
                [Console]::ForegroundColor = [ConsoleColor]::White
            }
            elseif ($Selected[$i]) {
                [Console]::BackgroundColor = [ConsoleColor]::DarkGreen
                [Console]::ForegroundColor = [ConsoleColor]::White
            }

            Write-Host $line

            [Console]::ResetColor()
        }

        $selectedCount = @($Selected | Where-Object { $_ }).Count

        Write-Host ""
        Write-Host ("Page {0} / {1} | Selected: {2}" -f ($page + 1), (Get-PageCount), $selectedCount)

        Write-Host ""
        Write-Host "Up/Down: Move | Right/Left: Pages | Space: Select | A: Select all/none | Enter: Confirm | Esc: Exit"
    }

    try {
        # [Console]::Clear()

        while (-not $done) {

            Draw-SelectionUI

            $key = [Console]::ReadKey($true)

            switch ($key.Key) {

                "UpArrow" {
                    if ($cursor -gt 0) {
                        $cursor--
                    }
                }

                "DownArrow" {
                    if ($cursor -lt $Records.Count - 1) {
                        $cursor++
                    }
                }

                "LeftArrow" {
                    $cursor = [Math]::Max(0, $cursor - $PageSize)
                }

                "RightArrow" {
                    $cursor = [Math]::Min($Records.Count - 1, $cursor + $PageSize)
                }

                "Spacebar" {
                    $Selected[$cursor] = -not $Selected[$cursor]
                }

                "A" {
                    if ($Selected -notcontains $false) {
                        for ($i = 0; $i -lt $Selected.Count; $i++) {
                            $Selected[$i] = $false
                        }
                    } else {
                        for ($i = 0; $i -lt $Selected.Count; $i++) {
                            if ($Selected[$i]) {
                                $count++
                            }
                            $Selected[$i] = $true
                        }
                    }
                }

                "Enter" {
                    $done = $true
                }

                "Escape" {
                    $cancelled = $true
                    $done = $true
                }

            }

#            if ($key.Key -eq "Enter") {
#                break
#            }

        }

    }
    finally {
        [console]::ResetColor()
        [console]::CursorVisible = $true
    }

    [PSCustomObject]@{
        Cancelled = $cancelled
        Selected = @($Selected)
    }
}

function Show-SelectedUI {
    param (
        [string[]]$Records,
        [bool[]]$Selected
    )

    $done = $false
    $cancelled = $false
    $next = $null

    function Draw-SelectedUI {
        [Console]::Clear()

        Write-Host "Selected records"
        Write-Host "----------------"

        for ($i = 0; $i -lt $Records.Count; $i++) {
            if ($Selected[$i]) {
                Write-Host ("{0}| {1}" -f ($i + 1).ToString().PadLeft(4), $Records[$i])
            }
        }

        Write-Host ""
        Write-Host "S: Save to File | B: Back to Selection | Esc: Exit"
    }

    while (-not $done) {

        Draw-SelectedUI

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "Escape" {
                $done = $true
                $cancelled = $true
            }

            "S" {
                $done = $true
                $next = "File"
            }

            "B" {
                $done = $true
                $next = "SelectionUI"
            }
        }
    }

    [PSCustomObject]@{
        Cancelled = $cancelled
        Next = $next
    }
}

function Save-File {
    param (
        [string[]]$Records,
        [bool[]]$Selected
    )

    $cancelled = $false
    $next = $null

    [Console]::Clear()
    Write-Host "Writing the selected records to a file..."

    $lines = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Records.Count; $i++) {
        if ($Selected[$i]) {
            $lines.Add($Records[$i])
        }
    }

    # Save to file
    Set-Content -Path $DestPath -Value $lines

    [Console]::Clear()
    Write-Host "Generated a file with the selected records."

    [PSCustomObject]@{
        Cancelled = $cancelled
        Next = $next
    }
}


# Hide Cursor
[Console]::CursorVisible = $false

$context = [PSCustomObject]@{
    Records = [string[]]::new(0)
    Selected = [bool[]]::new(0)
    Current = "Records"
}

$result = [PSCustomObject]@{
    Cancelled = $false
}

while ($context.Current -ne $null) {
    switch ($context.Current) {

        "Records" {
            $result = Get-Records
            $context.Records = $result.Records
            $context.Selected = [bool[]]::new($context.Records.Count)

            if ($context.Records.Count -eq 0) {
                Write-Host "No records found."
                $context.Current = $null
                continue
            }

            $context.Current = "SelectionUI"
        }

        "SelectionUI" {
            $result = Show-SelectionUI -Records $context.Records -Selected $context.Selected
            $context.Selected = $result.Selected

            $context.Current = "SelectedUI"
        }

        "SelectedUI" {
            $result = Show-SelectedUI $context.Records $context.Selected

            $context.Current = $result.Next
        }

        "File" {
            $result = Save-File $context.Records $context.Selected

            $context.Current = $result.Next
        }
    }

    if ($result.Cancelled) {
        [Console]::Clear()
        Write-Host "Cancelled"
        return
    }
}


