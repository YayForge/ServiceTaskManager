Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-UnwantedServices {
    $results = @()
    $id = 1
    $targets = @(
        "DiagTrack","diagnosticshub.standardcollector.service","wlidsvc","OneSyncSvc*","lfsvc",
        "MapsBroker","SharedAccess","RmSvc","CDPUserSvc*","WpnService*","SysMain","cbdhsvc*",
        "Xbox*","Feedback*","MicrosoftEdgeUpdate*"
    )
    foreach ($svc in Get-Service | Where-Object { $_.Status -eq 'Running' }) {
        foreach ($name in $targets) {
            if ($svc.Name -like $name) {
                $results += [PSCustomObject]@{
                    ID   = $id
                    Type = "Service"
                    Name = $svc.Name
                    Path = "-"
                }
                $id++
                break
            }
        }
    }
    return $results
}

function Get-UnwantedTasks {
    $results = @()
    $id = 100
    $keywords = @(
        "Consolidator","CEIP","Appraiser","Feedback","Game","MediaSharing",
        "PushToInstall","CloudExperienceHost","Flighting","Telemetry","Maps",
        "MicrosoftEdgeUpdate","Xbl","Xbox","UsageData","usbceip"
    )
    foreach ($task in Get-ScheduledTask | Where-Object { $_.State -in 'Ready','Running' }) {
        foreach ($keyword in $keywords) {
            if ($task.TaskName -like "*$keyword*") {
                $results += [PSCustomObject]@{
                    ID   = $id
                    Type = "Task"
                    Name = $task.TaskName
                    Path = $task.TaskPath
                }
                $id++
                break
            }
        }
    }
    return $results
}

function Disable-SelectedItems {
    param(
        [int[]]     $selectedIDs,
        [psobject[]]$items
    )
    foreach ($id in $selectedIDs) {
        $entry = $items | Where-Object { $_.ID -eq $id }
        if (-not $entry) { continue }
        if ($entry.Type -eq "Service") {
            Stop-Service   -Name $entry.Name -Force -ErrorAction SilentlyContinue
            Set-Service    -Name $entry.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }
        else {
            Unregister-ScheduledTask -TaskName $entry.Name -TaskPath $entry.Path -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Unwanted Services and Tasks Manager"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"

$listView = New-Object System.Windows.Forms.ListView
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.CheckBoxes = $true
$listView.Dock = "Top"
$listView.Height = 450
$listView.Columns.Add("ID",50)    | Out-Null
$listView.Columns.Add("Type",100) | Out-Null
$listView.Columns.Add("Name",250) | Out-Null
$listView.Columns.Add("Path",350) | Out-Null

function RefreshList {
    $listView.Items.Clear()
    $all = Get-UnwantedServices + Get-UnwantedTasks
    foreach ($item in $all) {
        $lv = New-Object System.Windows.Forms.ListViewItem($item.ID)
        $lv.SubItems.Add($item.Type) | Out-Null
        $lv.SubItems.Add($item.Name) | Out-Null
        $lv.SubItems.Add($item.Path) | Out-Null
        $lv.Tag = $item
        $listView.Items.Add($lv) | Out-Null
    }
}

RefreshList

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Width = 100
$btnRefresh.Location = New-Object System.Drawing.Point(10,460)
$btnRefresh.Add_Click({ RefreshList })

$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text = "Clean"
$btnClean.Width = 100
$btnClean.Location = New-Object System.Drawing.Point(120,460)
$btnClean.Add_Click({
    $sel = $listView.CheckedItems | ForEach-Object { [int]$_.Text }
    if ($sel.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select at least one item.","Warning",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    $allItems = Get-UnwantedServices + Get-UnwantedTasks
    Disable-SelectedItems -selectedIDs $sel -items $allItems
    [System.Windows.Forms.MessageBox]::Show(
        "Cleanup completed. A restart is recommended.","Info",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    RefreshList
})

$form.Controls.Add($listView)
$form.Controls.Add($btnRefresh)
$form.Controls.Add($btnClean)
[void]$form.ShowDialog()
