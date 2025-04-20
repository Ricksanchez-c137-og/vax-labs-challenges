# post_deployment.ps1
# Script to run on primary DC after all resources are deployed
# This script creates OUs, groups, and users in the domain
param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName
)

# Configure error handling
$ErrorActionPreference = "Stop"
Start-Transcript -Path C:\post_deployment_log.txt -Append

function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Status] $Message"
    Add-Content -Path C:\post_deployment_log.txt -Value "[$timestamp] [$Status] $Message"
}

# Wait for AD DS to be ready
function Wait-ForADDS {
    $retry = 0
    $maxRetries = 30
    $retryInterval = 10
    
    Write-Log "Checking if Active Directory Domain Services are ready..."
    
    while ($retry -lt $maxRetries) {
        try {
            Get-ADDomain -Identity $DomainName -ErrorAction Stop
            Write-Log "Active Directory Domain Services are ready."
            return $true
        }
        catch {
            $retry++
            Write-Log "AD DS not ready yet. Waiting $retryInterval seconds... (Attempt $retry of $maxRetries)" -Status "Warning"
            Start-Sleep -Seconds $retryInterval
        }
    }
    
    Write-Log "AD DS not ready after maximum retries." -Status "Error"
    return $false
}

try {
    if (-not (Wait-ForADDS)) {
        Write-Log "Active Directory Domain Services are not ready. Exiting script." -Status "Error"
        exit 1
    }
    
    $domainDN = (Get-ADDomain -Identity $DomainName).DistinguishedName
    
    # Create Organizational Units
    Write-Log "Creating Organizational Units..."
    $departmentOUs = @("HR", "Finance", "IT", "Marketing", "Sales", "Legal", "Operations", "Research")
    $locationOUs = @("Headquarters", "EastOffice", "WestOffice", "RemoteWorkers")
    
    # Create main OUs
    New-ADOrganizationalUnit -Name "Departments" -Path $domainDN -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Locations" -Path $domainDN -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Security Groups" -Path $domainDN -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Service Accounts" -Path $domainDN -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Servers" -Path $domainDN -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Workstations" -Path $domainDN -ProtectedFromAccidentalDeletion $true
    
    # Create department OUs
    foreach ($dept in $departmentOUs) {
        New-ADOrganizationalUnit -Name $dept -Path "OU=Departments,$domainDN" -ProtectedFromAccidentalDeletion $true
    }
    
    # Create location OUs
    foreach ($loc in $locationOUs) {
        New-ADOrganizationalUnit -Name $loc -Path "OU=Locations,$domainDN" -ProtectedFromAccidentalDeletion $true
    }
    
    # Create security groups
    Write-Log "Creating security groups..."
    
    # Department groups
    foreach ($dept in $departmentOUs) {
        $groupName = "$dept-Users"
        New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path "OU=Security Groups,$domainDN" -Description "Members of $dept department"
        
        # Management group for department
        $mgmtGroupName = "$dept-Management"
        New-ADGroup -Name $mgmtGroupName -GroupScope Global -GroupCategory Security -Path "OU=Security Groups,$domainDN" -Description "Management of $dept department"
    }
    
    # Special access groups
    $specialGroups = @(
        @{Name = "FileServer-Admins"; Description = "Administrators for all file servers"},
        @{Name = "RemoteAccess-Users"; Description = "Users allowed remote access"},
        @{Name = "ITSupport-Level1"; Description = "Tier 1 IT Support Staff"},
        @{Name = "ITSupport-Level2"; Description = "Tier 2 IT Support Staff"},
        @{Name = "ITSupport-Level3"; Description = "Tier 3 IT Support Staff"},
        @{Name = "DomainAdmins-Auditors"; Description = "Users who can audit Domain Admin activities"}
    )
    
    foreach ($group in $specialGroups) {
        New-ADGroup -Name $group.Name -GroupScope Global -GroupCategory Security -Path "OU=Security Groups,$domainDN" -Description $group.Description
    }
    
    # Create sample users
    Write-Log "Creating sample users..."
    
    # Function to create a sample user
    function New-SampleUser {
        param(
            [string]$FirstName,
            [string]$LastName,
            [string]$Department,
            [string]$Title,
            [string]$Location,
            [bool]$IsManager = $false
        )
        
        $username = ($FirstName.Substring(0, 1) + $LastName).ToLower()
        $upn = "$username@$DomainName"
        $ou = "OU=$Department,OU=Departments,$domainDN"
        
        # Create the user
        $securePassword = ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force
        
        try {
            New-ADUser -Name "$FirstName $LastName" `
                -GivenName $FirstName `
                -Surname $LastName `
                -SamAccountName $username `
                -UserPrincipalName $upn `
                -Path $ou `
                -Enabled $true `
                -Department $Department `
                -Title $Title `
                -Office $Location `
                -Company "VaxLabs" `
                -AccountPassword $securePassword `
                -PasswordNeverExpires $true
            
            # Add to department group
            Add-ADGroupMember -Identity "$Department-Users" -Members $username
            
            # If manager, add to management group
            if ($IsManager) {
                Add-ADGroupMember -Identity "$Department-Management" -Members $username
            }
            
            # Add some users to special groups based on department
            if ($Department -eq "IT") {
                if ($Title -like "*Administrator*") {
                    Add-ADGroupMember -Identity "FileServer-Admins" -Members $username
                }
                
                # Assign to IT support level based on title
                if ($Title -like "*Level 1*") {
                    Add-ADGroupMember -Identity "ITSupport-Level1" -Members $username
                } elseif ($Title -like "*Level 2*") {
                    Add-ADGroupMember -Identity "ITSupport-Level2" -Members $username
                } elseif ($Title -like "*Level 3*" -or $Title -like "*Senior*") {
                    Add-ADGroupMember -Identity "ITSupport-Level3" -Members $username
                }
            }
            
            # Remote access for sales and management
            if ($Department -eq "Sales" -or $IsManager) {
                Add-ADGroupMember -Identity "RemoteAccess-Users" -Members $username
            }
            
            return $username
        }
        catch {
            Write-Log "Error creating user $username: $_" -Status "Error"
            return $null
        }
    }
    
    # Create users for each department
    $userSamples = @(
        # HR Department
        @{FirstName = "Alice"; LastName = "Johnson"; Department = "HR"; Title = "HR Director"; Location = "Headquarters"; IsManager = $true},
        @{FirstName = "Robert"; LastName = "Smith"; Department = "HR"; Title = "HR Specialist"; Location = "Headquarters"; IsManager = $false},
        @{FirstName = "Emma"; LastName = "Davis"; Department = "HR"; Title = "HR Coordinator"; Location = "Headquarters"; IsManager = $false},
        
        # Finance Department
        @{FirstName = "Michael"; LastName = "Brown"; Department = "Finance"; Title = "Finance Director"; Location = "Headquarters"; IsManager = $true},
        @{FirstName = "Sarah"; LastName = "Wilson"; Department = "Finance"; Title = "Senior Accountant"; Location = "Headquarters"; IsManager = $false},
        @{FirstName = "Thomas"; LastName = "Martin"; Department = "Finance"; Title = "Financial Analyst"; Location = "EastOffice"; IsManager = $false},
        
        # IT Department
        @{FirstName = "James"; LastName = "Anderson"; Department = "IT"; Title = "IT Director"; Location = "Headquarters"; IsManager = $true},
        @{FirstName = "David"; LastName = "Taylor"; Department = "IT"; Title = "Systems Administrator"; Location = "Headquarters"; IsManager = $false},
        @{FirstName = "Jennifer"; LastName = "White"; Department = "IT"; Title = "IT Support Level 1"; Location = "WestOffice"; IsManager = $false},
        @{FirstName = "Matthew"; LastName = "Harris"; Department = "IT"; Title = "IT Support Level 2"; Location = "EastOffice"; IsManager = $false},
        @{FirstName = "Lisa"; LastName = "Clark"; Department = "IT"; Title = "Senior Network Engineer"; Location = "Headquarters"; IsManager = $false},
        
        # Marketing Department
        @{FirstName = "Christopher"; LastName = "Lewis"; Department = "Marketing"; Title = "Marketing Director"; Location = "Headquarters"; IsManager = $true},
        @{FirstName = "Laura"; LastName = "Walker"; Department = "Marketing"; Title = "Marketing Manager"; Location = "WestOffice"; IsManager = $true},
        @{FirstName = "Brian"; LastName = "Hall"; Department = "Marketing"; Title = "Marketing Specialist"; Location = "WestOffice"; IsManager = $false},
        
        # Sales Department
        @{FirstName = "Daniel"; LastName = "Young"; Department = "Sales"; Title = "Sales Director"; Location = "Headquarters"; IsManager = $true},
        @{FirstName = "Michelle"; LastName = "King"; Department = "Sales"; Title = "Sales Manager"; Location = "EastOffice"; IsManager = $true},
        @{FirstName = "Kevin"; LastName = "Wright"; Department = "Sales"; Title = "Sales Representative"; Location = "EastOffice"; IsManager = $false},
        @{FirstName = "Susan"; LastName = "Lopez"; Department = "Sales"; Title = "Sales Representative"; Location = "WestOffice"; IsManager = $false},
        @{FirstName = "Mark"; LastName = "Hill"; Department = "Sales"; Title = "Sales Associate"; Location = "RemoteWorkers"; IsManager = $false},
        
        # Legal Department
        @{FirstName = "Richard"; LastName = "Scott"; Department = "Legal"; Title = "Legal Director"; Location = "Headquarters"; IsManager = $true},
        @{FirstName = "Patricia"; LastName = "Green"; Department = "Legal"; Title = "Corporate Counsel"; Location = "Headquarters"; IsManager = $false},
        @{FirstName = "Joseph"; LastName = "Adams"; Department = "Legal"; Title = "Legal Assistant"; Location = "Headquarters"; IsManager = $false},
        
        # Operations Department
        @{FirstName = "Barbara"; LastName = "Baker"; Department = "Operations"; Title = "Operations Director"; Location = "Headquarters"; IsManager = $true},
        @{FirstName = "William"; LastName = "Nelson"; Department = "Operations"; Title = "Operations Manager"; Location = "EastOffice"; IsManager = $true},
        @{FirstName = "Charles"; LastName = "Carter"; Department = "Operations"; Title = "Operations Analyst"; Location = "EastOffice"; IsManager = $false},
        
        # Research Department
        @{FirstName = "Elizabeth"; LastName = "Mitchell"; Department = "Research"; Title = "Research Director"; Location = "WestOffice"; IsManager = $true},
        @{FirstName = "Paul"; LastName = "Perez"; Department = "Research"; Title = "Senior Researcher"; Location = "WestOffice"; IsManager = $false},
        @{FirstName = "Sandra"; LastName = "Roberts"; Department = "Research"; Title = "Research Assistant"; Location = "RemoteWorkers"; IsManager = $false}
    )
    
    foreach ($user in $userSamples) {
        $username = New-SampleUser @user
        Write-Log "Created user: $username" 
    }
    
    # Create service accounts
    Write-Log "Creating service accounts..."
    $serviceAccounts = @(
        @{Name = "svc-backup"; Description = "Backup Service Account"},
        @{Name = "svc-monitor"; Description = "Monitoring Service Account"},
        @{Name = "svc-deploy"; Description = "Deployment Service Account"},
        @{Name = "svc-sql"; Description = "SQL Server Service Account"},
        @{Name = "svc-web"; Description = "Web Services Account"}
    )
    
    foreach ($account in $serviceAccounts) {
        $securePassword = ConvertTo-SecureString "ServiceP@ss123!" -AsPlainText -Force
        
        New-ADUser -Name $account.Name `
            -SamAccountName $account.Name `
            -UserPrincipalName "$($account.Name)@$DomainName" `
            -Path "OU=Service Accounts,$domainDN" `
            -Enabled $true `
            -Description $account.Description `
            -AccountPassword $securePassword `
            -PasswordNeverExpires $true
        
        Write-Log "Created service account: $($account.Name)"
    }
    
    # Move computer accounts to appropriate OUs
    Write-Log "Moving computer accounts to appropriate OUs..."
    
    # Move Domain Controllers to Domain Controllers OU (built-in)
    for ($i = 1; $i -le 12; $i++) {
        $dcName = "DC$i"
        try {
            Get-ADComputer $dcName | Move-ADObject -TargetPath "OU=Domain Controllers,$domainDN"
            Write-Log "Moved $dcName to Domain Controllers OU"
        } catch {
            Write-Log "Could not move $dcName: $_" -Status "Warning"
        }
    }
    
    # Move File Servers to Servers OU
    for ($i = 1; $i -le 8; $i++) {
        $fsName = "FS$i"
        try {
            Get-ADComputer $fsName | Move-ADObject -TargetPath "OU=Servers,$domainDN"
            Write-Log "Moved $fsName to Servers OU"
        } catch {
            Write-Log "Could not move $fsName: $_" -Status "Warning"
        }
    }
    
    # Move Client machines to Workstations OU
    for ($i = 1; $i -le 24; $i++) {
        $clientName = "Client$i"
        try {
            Get-ADComputer $clientName | Move-ADObject -TargetPath "OU=Workstations,$domainDN"
            Write-Log "Moved $clientName to Workstations OU"
        } catch {
            Write-Log "Could not move $clientName: $_" -Status "Warning"
        }
    }
    
    Write-Log "Post-deployment configuration completed successfully!"
    
} catch {
    Write-Log "An error occurred during post-deployment: $_" -Status "Error"
    throw
}