# setup_additional_dc.ps1
# Script to set up additional domain controllers
param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUser,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword
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
    Write-Log "Starting Additional Domain Controller setup for domain: $DomainName"
    
    # Install necessary Windows features
    Write-Log "Installing AD DS and DNS features..."
    Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
    
    # Configure networking for static IP
    Write-Log "Configuring network settings..."
    $netAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    $currentIP = (Get-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4).IPAddress
    $currentPrefix = (Get-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4).PrefixLength
    $gateway = (Get-NetRoute -InterfaceIndex $netAdapter.ifIndex -DestinationPrefix "0.0.0.0/0").NextHop
    
    # Try to resolve the primary DC IP
    $primaryDcIp = $null
    try {
        $primaryDcIp = [System.Net.Dns]::GetHostAddresses("DC1.$DomainName") | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString -First 1
    } catch {
        Write-Log "Could not resolve primary DC. Trying alternative methods..." -Status "Warning"
    }
    
    # Set DNS to point to the primary DC or itself if primary DC not found
    if ($primaryDcIp) {
        Write-Log "Setting DNS to primary DC: $primaryDcIp"
        Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses $primaryDcIp
    } else {
        Write-Log "Primary DC not found. Setting temporary DNS to 127.0.0.1" -Status "Warning"
        Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses "127.0.0.1"
    }
    
    # Wait for the domain to be reachable
    if (-not (Wait-ForDomain -DomainName $DomainName)) {
        Write-Log "Domain $DomainName not reachable after timeout. Continuing anyway, but might fail." -Status "Warning"
    }
    
    # Remove DHCP and set static IP
    Remove-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4 -Confirm:$false
    New-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4 -IPAddress $currentIP -PrefixLength $currentPrefix -DefaultGateway $gateway
    
    # Create credential object for domain join
    $securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("$DomainName\$AdminUser", $securePassword)
    
    # Join the domain first without promoting to DC
    Write-Log "Joining domain $DomainName..."
    Add-Computer -DomainName $DomainName -Credential $credential -Restart:$false -Force
    
    Start-Sleep -Seconds 10
    
    # Promote the server to a domain controller
    Write-Log "Promoting server to additional domain controller..."
    Install-ADDSDomainController `
        -DomainName $DomainName `
        -Credential $credential `
        -InstallDns:$true `
        -DatabasePath "C:\Windows\NTDS" `
        -LogPath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -SafeModeAdministratorPassword $securePassword `
        -NoRebootOnCompletion:$false `
        -Force:$true
    
    # The computer will restart automatically after promotion
    
} catch {
    Write-Log "An error occurred during setup: $_" -Status "Error"
    throw
}