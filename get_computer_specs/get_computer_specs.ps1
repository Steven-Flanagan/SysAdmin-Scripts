Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Define output file path
$outputFile = "$env:USERPROFILE\Documents\Computer-Specs.csv"

# Get computer name
$hostName = $env:COMPUTERNAME

# Retrieve CPU information using Get-CimInstance
$cpuInfo = Get-CimInstance -ClassName Win32_Processor
$cpuName = $($cpuInfo.Name)
$cpuCores = $($cpuInfo.NumberOfCores)
$cpuLogicalProcessors = $($cpuInfo.NumberOfLogicalProcessors)
$cpuClockSpeed = $($cpuInfo.MaxClockSpeed)

# Retrieve Operating System information
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$osName = $($osInfo.Caption)
$osVersion = $($osInfo.Version)
$osArchitecture = $($osInfo.OSArchitecture)

# Retrieve Motherboard information
$motherboardInfo = Get-CimInstance -ClassName Win32_BaseBoard
$mbManufacturer = $($motherboardInfo.Manufacturer)
$mbProduct = $($motherboardInfo.Product)

# Retrieve RAM information
$ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory
$totalRAM = ($ramInfo.Capacity | Measure-Object -Sum).Sum / 1GB
$memorySlotsUsed = $ramInfo.Length
$memorySlotsAvailable = (Get-WmiObject -Class "Win32_PhysicalMemoryArray").MemoryDevices

# Concatenate RAM types using SMBIOSMemoryType and speeds
$ramType = ($ramInfo | ForEach-Object {
    Switch ($_.SMBIOSMemoryType) {
        20 { "DDR" }
        21 { "DDR2" }
        24 { "DDR3" }
        26 { "DDR4" }
        30 { "DDR5" }
        Default { "Unknown" }
    }
}) -join ", "

$ramSpeed = ($ramInfo | ForEach-Object { $_.Speed }) -join ", "

# Retrieve Storage Information
$diskInfo = Get-CimInstance -ClassName Win32_DiskDrive
$volumes = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"

$totalStorage = ($volumes.Size | Measure-Object -Sum).Sum / 1GB
$usedStorage = (($volumes.Size - $volumes.FreeSpace) | Measure-Object -Sum).Sum / 1GB
$diskModel = $($diskInfo.Model)
$diskMediaType = $($diskInfo.MediaType)

# Check if NVMe or SSD
$diskType = if ($diskInfo.InterfaceType -eq 'NVMe') {
    "NVMe"
} elseif ($diskMediaType -match "SSD") {
    "SSD"
} else {
    "HDD"
}

# Create a custom object with all computer information
$computerInfo = [pscustomobject]@{
    "Hostname" = $hostName
    "Operating System" = $osName
    "OS Version" = $osVersion
    "OS Architecture" = $osArchitecture
    "Motherboard Manufacturer" = $mbManufacturer
    "Motherboard Model" = $mbProduct
    "CPU" = $cpuName
    "Number of Cores" = $cpuCores
    "Logical Processors" = $cpuLogicalProcessors
    "Clock Speed (MHz)" = $cpuClockSpeed
    "Total RAM (GB)" = [math]::round($totalRAM, 2)
    "RAM Type" = $ramType
    "RAM Speed (MHz)" = $ramSpeed
    "Memory Slots Used" = $memorySlotsUsed
    "Memory Slots Available" = $memorySlotsAvailable
    "Drive Model" = $diskModel
    "Drive Type" = $diskType
    "Total Storage (GB)" = [math]::round($totalStorage, 2)
    "Used Storage (GB)" = [math]::round($usedStorage, 2)
}

# Export to CSV file
$computerInfo | Export-Csv -Path $outputFile -NoTypeInformation

# Output the file location
Write-Host "Computer information has been exported to $outputFile"