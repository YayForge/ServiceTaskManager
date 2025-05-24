Import-Module ScheduledTasks -ErrorAction Stop
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-UnwantedServices {
    $results = @()
    $id = 1
    $targets = @("DiagTrack","diagnosticshub.standardcollector.service","wlidsvc","OneSyncSvc*","lfsvc",
        "MapsBroker","SharedAccess","RmSvc","CDPUserSvc*","WpnService*","SysMain","cbdhsvc*",
        "Xbox*","Feedback*","MicrosoftEdgeUpdate*","AeLookupSvc","AppHostSvc","AppIDSvc","Appinfo",
        "AudioEndpointBuilder","Audiosrv","BITS","BrokerInfrastructure","CertPropSvc","CoreMessagingRegistrar",
        "CryptSvc","DCOMLaunch","Dhcp","Dnscache","DPS","EapHost","EventLog","EventSystem","FontCache",
        "gpsvc","iphlpsvc","KeyIso","LanmanServer","LanmanWorkstation","LicenseManager","lmhosts","LSM",
        "Netman","NlaSvc","nsi","PlugPlay","Power","ProfSvc","RpcEptMapper","RpcSs","SamSs","Schedule",
        "SecurityHealthService","SENS","SessionEnv","ShellHWDetection","Spooler","StateRepository","StorSvc",
        "SystemEventsBroker","Themes","TimeBrokerSvc","TokenBroker","TrustedInstaller","tzautoupdate",
        "UserManager","UsoSvc","W32Time","WdiServiceHost","WdiSystemHost","WebClient","Wecsvc","WlanSvc",
        "WmiApSrv","Winmgmt","WindowsPushToInstall","wisvc","WerSvc","wuauserv","WpnUserService*","EventSystem",
        "WbioSrvc","AppXSvc","BFE","WinDefend","XblAuthManager","XblGameSave","XboxNetApiSvc")
    foreach ($svc in Get-Service | Where-Object { $_.Status -eq 'Running' }) {
        foreach ($name in $targets) {
            if ($svc.Name -like $name) {
                $results += [PSCustomObject]@{ID=$id;Type="Service";Name=$svc.Name;DisplayName=$svc.DisplayName;Path="-"}
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
    $keywords = @("Consolidator","CEIP","Appraiser","Feedback","Game","MediaSharing",
        "PushToInstall","CloudExperienceHost","Flighting","Telemetry","Maps",
        "MicrosoftEdgeUpdate","Xbl","Xbox","UsageData","usbceip")
    foreach ($task in Get-ScheduledTask | Where-Object { $_.State -in 'Ready','Running' }) {
        foreach ($keyword in $keywords) {
            if ($task.TaskName -like "*$keyword*") {
                $results += [PSCustomObject]@{ID=$id;Type="Task";Name=$task.TaskName;DisplayName="-";Path=$task.TaskPath}
                $id++
                break
            }
        }
    }
    return $results
}

function Disable-SelectedItems {
    param([int[]]$selectedIDs,[psobject[]]$items)
    foreach ($id in $selectedIDs) {
        $entry = $items | Where-Object { $_.ID -eq $id }
        if (-not $entry) { continue }
        if ($entry.Type -eq "Service") {
            Stop-Service -Name $entry.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $entry.Name -StartupType Disabled -ErrorAction SilentlyContinue
        } else {
            Unregister-ScheduledTask -TaskName $entry.Name -TaskPath $entry.Path -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

function Get-StoppedServices {
    $results = @()
    $id = 1
    foreach ($svc in Get-Service | Where-Object { $_.Status -eq 'Stopped' }) {
        $results += [PSCustomObject]@{ID=$id;Name=$svc.Name;DisplayName=$svc.DisplayName}
        $id++
    }
    return $results
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "ServiceTaskManager"
$form.Size = New-Object System.Drawing.Size(850,600)
$form.StartPosition = "CenterScreen"

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = "Fill"

$tab1 = New-Object System.Windows.Forms.TabPage
$tab1.Text = "Unwanted Items"
$tab2 = New-Object System.Windows.Forms.TabPage
$tab2.Text = "Stopped Services"

$search1 = New-Object System.Windows.Forms.TextBox
$search1.Width = 300
$search1.Location = New-Object System.Drawing.Point(10,10)

$listView = New-Object System.Windows.Forms.ListView
$listView.View = "Details"
$listView.FullRowSelect = $true
$listView.CheckBoxes = $true
$listView.Location = New-Object System.Drawing.Point(10,40)
$listView.Size = New-Object System.Drawing.Size(800,400)
$listView.Columns.Add("ID",50)|Out-Null
$listView.Columns.Add("Type",100)|Out-Null
$listView.Columns.Add("Name",200)|Out-Null
$listView.Columns.Add("Display Name",250)|Out-Null
$listView.Columns.Add("Path",180)|Out-Null

function RefreshList {
    $listView.Items.Clear()
    $all = Get-UnwantedServices + Get-UnwantedTasks
    foreach ($item in $all) {
        if ($search1.Text -and ($item.Name -notlike "*$($search1.Text)*") -and ($item.DisplayName -notlike "*$($search1.Text)*")) { continue }
        $lv = New-Object System.Windows.Forms.ListViewItem($item.ID)
        $lv.SubItems.Add($item.Type)|Out-Null
        $lv.SubItems.Add($item.Name)|Out-Null
        $lv.SubItems.Add($item.DisplayName)|Out-Null
        $lv.SubItems.Add($item.Path)|Out-Null
        $lv.Tag = $item
        $listView.Items.Add($lv)|Out-Null
    }
}

$search1.Add_TextChanged({ RefreshList })

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
    $sel = $listView.CheckedItems|ForEach-Object { [int]$_.Text }
    if ($sel.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one item.","Warning",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)|Out-Null
        return
    }
    $allItems = Get-UnwantedServices + Get-UnwantedTasks
    Disable-SelectedItems -selectedIDs $sel -items $allItems
    [System.Windows.Forms.MessageBox]::Show("Cleanup completed. A restart is recommended.","Info",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)|Out-Null
    RefreshList
})

$tab1.Controls.Add($search1)
$tab1.Controls.Add($listView)
$tab1.Controls.Add($btnRefresh)
$tab1.Controls.Add($btnClean)

$search2 = New-Object System.Windows.Forms.TextBox
$search2.Width = 300
$search2.Location = New-Object System.Drawing.Point(10,10)

$stoppedList = New-Object System.Windows.Forms.ListView
$stoppedList.View = "Details"
$stoppedList.FullRowSelect = $true
$stoppedList.CheckBoxes = $true
$stoppedList.Location = New-Object System.Drawing.Point(10,40)
$stoppedList.Size = New-Object System.Drawing.Size(800,400)
$stoppedList.Columns.Add("ID",50)|Out-Null
$stoppedList.Columns.Add("Service Name",250)|Out-Null
$stoppedList.Columns.Add("Display Name",480)|Out-Null

function RefreshStoppedList {
    $stoppedList.Items.Clear()
    $all = Get-StoppedServices
    foreach ($item in $all) {
        if ($search2.Text -and ($item.Name -notlike "*$($search2.Text)*") -and ($item.DisplayName -notlike "*$($search2.Text)*")) { continue }
        $lv = New-Object System.Windows.Forms.ListViewItem($item.ID)
        $lv.SubItems.Add($item.Name)|Out-Null
        $lv.SubItems.Add($item.DisplayName)|Out-Null
        $lv.Tag = $item
        $stoppedList.Items.Add($lv)|Out-Null
    }
}

$search2.Add_TextChanged({ RefreshStoppedList })

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Selected"
$btnStart.Width = 120
$btnStart.Location = New-Object System.Drawing.Point(320,460)
$btnStart.Add_Click({
    $sel = $stoppedList.CheckedItems|ForEach-Object { $_.SubItems[1].Text }
    if ($sel.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one service.","Warning",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)|Out-Null
        return
    }
    foreach ($svc in $sel) {
        Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service -Name $svc -ErrorAction SilentlyContinue
    }
    [System.Windows.Forms.MessageBox]::Show("Selected services started.","Info",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)|Out-Null
    RefreshStoppedList
})

$btnRefresh2 = New-Object System.Windows.Forms.Button
$btnRefresh2.Text = "Refresh"
$btnRefresh2.Width = 100
$btnRefresh2.Location = New-Object System.Drawing.Point(10,460)
$btnRefresh2.Add_Click({ RefreshStoppedList })

$tab2.Controls.Add($search2)
$tab2.Controls.Add($stoppedList)
$tab2.Controls.Add($btnRefresh2)
$tab2.Controls.Add($btnStart)

$tabControl.TabPages.Add($tab1)
$tabControl.TabPages.Add($tab2)
$form.Controls.Add($tabControl)

RefreshList
RefreshStoppedList
[void]$form.ShowDialog()
