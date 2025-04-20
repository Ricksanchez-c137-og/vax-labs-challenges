# setup_file_server.ps1
# Script to set up a file server and join it to the domain
param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUser,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory=$true)]
    [int]$ServerNumber
)

# Configure error handling
$ErrorActionPreference = "Stop"
Start-Transcript -Path C:\setup_log.txt -Append

function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Status] $Message"
    Add-Content -Path C:\setup_log.txt -Value "[$timestamp] [$Status] $Message"
}

function Wait-ForDomain {
    param(
        [string]$DomainName,
        [int]$Timeout = 300
    )
    
    Write-Log "Waiting for domain $DomainName to become available..."
    $start = Get-Date
    $end = $start.AddSeconds($Timeout)
    
    while ((Get-Date) -lt $end) {
        try {
            if (Test-Connection -ComputerName $DomainName -Count 1 -Quiet) {
                return $true
            }
        } catch {
            # Ignore and continue waiting
        }
        
        Start-Sleep -Seconds 10
    }
    
    return $false
}

try {
    Write-Log "Starting File Server setup for server FS$ServerNumber"
    
    # Install necessary Windows features
    Write-Log "Installing File Server features..."
    Install-WindowsFeature -Name FS-FileServer, FS-DFS-Namespace, FS-DFS-Replication, RSAT-DFS-Mgmt-Con -IncludeManagementTools
    
    # Create directory for file shares
    $shareRoot = "D:\"
    if (-not (Test-Path -Path $shareRoot)) {
        # If D: doesn't exist, use C:
        $shareRoot = "C:\Shares"
        New-Item -Path $shareRoot -ItemType Directory -Force | Out-Null
    }
# Create departments shares
$departments = @("HR", "Finance", "IT", "Marketing", "Sales", "Legal", "Operations", "Research")

foreach ($dept in $departments) {
    $sharePath = Join-Path -Path $shareRoot -ChildPath $dept
    New-Item -Path $sharePath -ItemType Directory -Force | Out-Null
    
    Write-Log "Creating share for $dept department..."
    $shareName = "$dept-FS$ServerNumber"
    New-SmbShare -Name $shareName -Path $sharePath -FullAccess "BUILTIN\Administrators" -ChangeAccess "DOMAIN\Domain Users" -Description "$dept Department Files (Server $ServerNumber)" | Out-Null
    
    # Create sample files
    $sampleFilePath = Join-Path -Path $sharePath -ChildPath "Welcome.txt"
    Set-Content -Path $sampleFilePath -Value "Welcome to the $dept department share on FS$ServerNumber`r`nThis is part of the VaxLabs Active Directory lab environment."
}

# Configure networking for static IP
Write-Log "Configuring network settings..."
$netAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
$currentIP = (Get-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4).IPAddress
$currentPrefix = (Get-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4).PrefixLength
$gateway = (Get-NetRoute -InterfaceIndex $netAdapter.ifIndex -DestinationPrefix "0.0.0.0/0").NextHop

# Try to resolve a DC IP
$dcIp = $null
try {
    $dcIp = [System.Net.Dns]::GetHostAddresses("DC1.$DomainName") | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString -First 1
    if (-not $dcIp) {
        $dcIp = [System.Net.Dns]::GetHostAddresses("DC2.$DomainName") | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString -First 1
    }
} catch {
    Write-Log "Could not resolve any DC. Trying alternative methods..." -Status "Warning"
}

# Set DNS to point to a domain controller
if ($dcIp) {
    Write-Log "Setting DNS to domain controller: $dcIp"
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses $dcIp
} else {
    Write-Log "No DC found. Setting temporary DNS to 127.0.0.1" -Status "Warning"
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses "127.0.0.1"
}

# Wait for the domain to be reachable
if (-not (Wait-ForDomain -DomainName $DomainName)) {
    Write-Log "Domain $DomainName not reachable after timeout. Continuing anyway, but might fail." -Status "Warning"
}

# Create credential object for domain join
$securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$DomainName\$AdminUser", $securePassword)

# Join the domain
Write-Log "Joining domain $DomainName..."
Add-Computer -DomainName $DomainName -Credential $credential -Restart -Force

} catch {
    Write-Log "An error occurred during setup: $_" -Status "Error"
    throw
}