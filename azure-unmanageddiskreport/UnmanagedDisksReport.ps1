<#
.NOTES
 	==================================================================================================================================================================
	Azure Managed Disks Program
	File:		UnmanagedDisksReport.ps1
	Purpose:	Generate a CSV report of unmanaged disk information for unmanaged ARM virtual machines
	Version: 	1.4
    Changes:    1.4 - Date Modified: 11/27/2018
                      Updated to support optional parameter of a specific virtual machine and to dump to CSV or simply display
                      Updated to use new Az PowerShell cmdlets
		      Added Lun for disk information displayed/reported
                1.3 - Updated to support multiple subscriptions. Added more error handling.
                1.2 - Updated for AzureRM version 6.*. Skip premium storage by default. Efficieny improvements. - June 2018
                1.1 - Fixed GetPageRanges timeout errors - Feb 2018
                1.0 - Original
 	==================================================================================================================================================================
 .SYNOPSIS
    Generate a CSV report for virtual machines using unmanaged disks
 .DESCRIPTION
    This script will gather information in an Azure subscription about unmanaged disks attached to ARM virtual machines 
    and at what capacity they are being used.
 .PARAMETERS
    SubscriptionIDs - Array of Azure subscription IDs to report on unmanaged ARM virtual machines
    ReportOutputFolder - Output location for the CSV generated in this script
    IncludePremium - Enable the switch to include gathering details on Premium unmanaged disks
 .EXAMPLE
    1. Run the script against 1 (one) subscription:
        .\UnmanagedDisksReport.ps1 -SubscriptionIDs @("xxxxx-xxxxxx-xxxxxxx-xxxxx") -ReportOutputFolder "C:\ScriptReports\"
    2. Run the script against more than 1 (one) subscription and include premium:
        .\UnmanagedDisksReport.ps1 -SubscriptionIDs @("xxxxx-xxxxxx-xxxxxxx-xxxxx", "xxxxx-xxxxxx-xxxxxxx-xxxxx") -ReportOutputFolder "C:\ScriptReports\" -IncludePremium
    3. Run the script against all subscriptions the account has access to:
        Login-AzureRmAccount
        $subIDs = Get-AzureRmSubscription | Select -ExpandProperty Id
        .\UnmanagedDisksReport.ps1 -SubscriptionIDs $subIDs -ReportOutputFolder "C:\ScriptReports\"
   ===================================================================================================================================================================
#>

param(
	[Parameter(Mandatory=$true)]
    [array]$SubscriptionIDs,
    [Parameter(Mandatory=$true)]
    [string]$ReportOutputFolder,
    [Parameter(Mandatory=$false)]
    [switch]$IncludePremium,
    [Parameter(Mandatory=$false)]
    [string]$VMName,
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup,
    [Parameter(Mandatory=$false)]
    [string]$ExportToCSV=$true
)

Write-Output "Script start`n"

##################################################
# Region: Validation and login to Azure
##################################################

# Validate output folder path exists
if(-not(Test-Path -Path $ReportOutputFolder) -and $ExportToCSV -eq $true){
    throw "The output folder specified does not exist at $ReportOutputFolder"
}

# Checking for Windows PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Windows PowerShell version 5.0 or above must be installed to use the latest Azure PowerShell modules." -ForegroundColor Red
    Exit -2
}

# Checking for Azure PowerShell module
$modlist = Get-Module -ListAvailable -Name 'Az.*' | Sort-Object Version -Descending | Select-Object -First 1
if ($modlist -eq $null){
    Write-Host "Please install the Azure Az Powershell modules." -ForegroundColor Red
    Write-Host "The latest Azure Powershell versions can be found in the following URL:" -ForegroundColor Red
    Write-Host "https://www.powershellgallery.com/packages/Az/" -ForegroundColor Red
    Exit -2
}

try{
    # login to Azure
    # to skip logging into Azure for already authenticated sessions, comment out the next 5 lines
    $account = Login-AzAccount
    if(!$account) {
        throw "Could not login to Azure"
    }
    Write-Host "Successfully logged into Azure`n"
}
catch{
    throw "Error logging into Azure"
}

$context = Get-AzContext
[array]$subscriptions = Get-AzSubscription | Select-Object -ExpandProperty Id

# Validate the account has access to each subscription
foreach($subscriptionId in $SubscriptionIDs){
    if(!$subscriptions.Contains($subscriptionId)){
        throw "Account '$($context.Account.Id)' does not have access to subscription '$subscriptionId'"
    }
}

$timeStamp = Get-Date -Format yyyyMMddHHmm
$VmOutputPath = "$ReportOutputFolder\UnmanagedDisksResults-$timeStamp.csv"

# End Region

##################################################
# Function: This function will gather detailed 
#           information about an unmanaged disk
##################################################
function GetUnmanagedDiskDetails{

    param(
        [Parameter(Mandatory=$true)] 
        [string]$vhduri,
        [Parameter(Mandatory=$true)] 
        [array]$storageAccounts
    )

    $diskUri = New-Object System.Uri($vhduri)

    # Parse storage information
    $storageAccount =  $diskUri.Host.Split('.')[0]
    $vhdFileName = $diskUri.Segments[$diskUri.Segments.Length-1]
    $container = $diskUri.Segments[1].Trim('/')

    $rg = ($storageAccounts | Where-Object { $_.Name -eq $storageAccount }).ResourceGroupName

    $type = (Get-AzStorageAccount -Name $storageAccount -ResourceGroupName $rg).Sku.Tier

    # Skip gathering information on premium unmanaged disks based on IncludePremium switch
    if(($type -eq "Premium") -and !$IncludePremium)
    {
        return New-Object psobject -Property @{Uri=$vhduri;StorageType=$type;ProvisionedSize="Skipped";UsedSize="Skipped";UsedDiskPercentage="Skipped"}
    }

    $storageAccountKey = (Get-AzStorageAccountKey -Name $storageAccount -ResourceGroupName $rg)[0].Value
    $storageAccountContext = New-AzStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccountKey 

    try
    {
        $blob = Get-AzStorageBlob -Blob $vhdFileName -Container $container -Context $storageAccountContext -ErrorAction Stop
    }
    # Catching any errors for getting the storage blob
    catch [Microsoft.WindowsAzure.Commands.Storage.Common.ResourceNotFoundException]
    {
        Write-Host -ForegroundColor Yellow "There was an error while accessing the blob $vhduri"
        Write-Host -ForegroundColor Red $_.Exception
        
        $provisionedSizeInGib = -1
        $usedSizeInGiB = -1
        $usedDiskPercentage = -1
        return New-Object psobject -Property @{StorageType=$type;ProvisionedSize=$provisionedSizeInGib;UsedSize=$usedSizeInGiB;UsedDiskPercentage=$usedDiskPercentage}
    }

    # Calculate provisioned size GB
    $provisionedSizeInGib = [math]::Round($($blob.Length)/1GB)

    if ($Type -eq "Premium")
    {
        $usedDiskPercentage = 1
        $usedSizeInGiB = $provisionedSizeInGib
    }
    elseif ($provisionedSizeInGib -eq 0)
    {
        $usedSizeInGiB = 0
        $usedDiskPercentage = 0
    }
    else
    {
        # Base + blob name 
        $blobSizeInBytes = 124 + $blob.Name.Length * 2 
  
        # Get size of metadata 
        $metadataEnumerator = $blob.ICloudBlob.Metadata.GetEnumerator() 
        while ($metadataEnumerator.MoveNext()) { 
            $blobSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + $metadataEnumerator.Current.Value.Length 
        } 

        $iPageRangeSuccessRetries = 2

        while($iPageRangeSuccessRetries -ge 1)
        {
            try
            { 
                $StartTime = Get-Date
               
                # True if this is the first attempt and call GetPageRanges without a page range
                if($iPageRangeSuccessRetries -eq 2){
                    $Blob.ICloudBlob.GetPageRanges() | ForEach-Object { $blobSizeInBytes += (13 + $_.EndOffset - $_.StartOffset) } 
                }
                # This is the second attempt to GetPageRanges, adding a range size to reduce timeouts. This is much slower
                else{

                    # It is recommended to keep the range size to 150MB to reduce the chance of a server timeout for highly fragmented disks
                    [int64]$rangeSize = 150MB
                    [int64]$start = 0; 
        
                    While ($start -lt $blob.Length){ 
                        if (($start + $rangeSize) -gt $blob.Length) {
                            $rangeSize = $blob.Length - $start
                        }

                        $Blob.ICloudBlob.GetPageRanges($start, $rangeSize) | `
                            ForEach-Object { $blobSizeInBytes += (13 + $_.EndOffset - $_.StartOffset) }

                      $start += $rangeSize
                    } 
                }
            
                $iPageRangeSuccessRetries = 0
            }
            catch [System.Management.Automation.MethodInvocationException]
            {
                $ErrorTime = Get-Date

                # There was a timeout error during the GetPageRanges call
                Write-Host -ForegroundColor Yellow "There was a server timeout while accessing the blob $vhduri"
                Write-Host -ForegroundColor Yellow "Attempt $(3 - $iPageRangeSuccessRetries) of 2."
                
                # Retry the GetPageRanges call using the range size parameter. Higher likelihood of success but significantly slower.
                if($iPageRangeSuccessRetries -eq 2) { Write-Host -ForegroundColor Yellow "Retrying using range size parameter..." }

                Write-Host -ForegroundColor Red $_.Exception

                #reset to original value to avoid page ranges to be added multiple times in a retry
                $blobSizeInBytes = 124 + $blob.Name.Length * 2 

                Start-Sleep -Seconds 2
            }
            finally
            {
                $iPageRangeSuccessRetries -= 1
            }
        }

        if($iPageRangeSuccessRetries -eq -1)
        {
            # Calculate used size in GB
            $usedSizeInGiB = $blobSizeInBytes/(1GB)

            # Calculate percentage of used disk space rounding to 2 decimals
            $usedDiskPercentage = [math]::Round($usedSizeInGiB/$provisionedSizeInGib,2)
            $usedSizeInGiB = [math]::Round($usedSizeInGiB)
        }
        else
        {
            Write-Host -ForegroundColor Red "Failed to retrieve used space for the blob $vhduri"
            $usedSizeInGiB = -1
            $usedDiskPercentage = -1
        }
                
    }

    return New-Object psobject -Property @{StorageType=$type;ProvisionedSize=$provisionedSizeInGib;UsedSize=$usedSizeInGiB;UsedDiskPercentage=$usedDiskPercentage}
}
# End Function

##################################################
# Region: Gather unmanaged disk information 
#         across all subscriptions
##################################################

Write-Host "Gathering virtual machine information...`n"

$unmanDisks = New-Object -TypeName System.Collections.ArrayList

# Loop through each subscription
foreach($subscriptionId in $SubscriptionIDs){

    # Set context to the subscription
    Select-AzSubscription -SubscriptionId $subscriptionID | Out-Null
    $context = Get-AzContext
    Write-Host "The subscription context is set to: $($context.Name)`n"

    # Determine if we should get a single VM or Multiple
    if([string]::IsNullOrEmpty($VMname)){
        # Validate I have all the parameters
        if($VMName -eq $null){
            while([string]::IsNullOrEmpty($VMName)){
                $VMName = Read-Host -Prompt "Please enter a Virtual Machine Name"
            }
        }

        if([string]::IsNullOrEmpty($ResourceGroup)){
            while([string]::IsNullOrEmpty($ResourceGroup)){
                $ResourceGroup = Read-Host -Prompt "Please enter the Resource Group for your Virtual Machine"
            }
        }

        # Finish code to the virtual machine
        $vms = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName
        
        # Check if the VM exists
        if(!$vms){
            Write-Host -ForegroundColor Red "The subscription '$($context.Name)' does not contain Virtual Machine '$($VMName)' OR the account '$($context.Account.Id)' does not have appropriate RBAC permissions to view the requested Virtual Machine."
            continue
        }
        
        # Check if the VM is using managed or unmanaged disks
        if($vms.StorageProfile.OsDisk.ManagedDisk){        
            Write-Host -ForegroundColor Red "The subscription '$($context.Name)' contains Virtual Machine '$($VMName)', however the Virtual Machine is already using Managed Disks."
            continue
        }

    }else{
        # Get all unmanaged ARM virtual machines and storage accounts 
        $vms = Get-AzVM | Where-Object {$_.StorageProfile.OsDisk.ManagedDisk -eq $null}
        # Check if any unmanaged ARM virtual machines exist within the subscription
        if(!$vms){
            Write-Host -ForegroundColor Red "The subscription '$($context.Name)' does not contain any unmanaged ARM virtual machines OR the account '$($context.Account.Id)' does not have appropriate RBAC permissions to view them."
            continue
        }
    }    

    $storageAccounts = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts'
    # Check the account can access storage accounts within the subscription
    if(!$storageAccounts){
        Write-Host -ForegroundColor Red "Account '$($context.Account.Id)' does not have access to any storage accounts in subscription '$($context.Name)' but the following unmanaged ARM virtual machines exist:"
        $vms | Format-Table ResourceGroupName, Name, Location
        continue
    }
    
    Write-Host "Progress Status:"
    Write-Host "[<Current Number> of <Total Number of Unmanaged VMs>] <VM Name>`n"
    [int]$i = 1

    # Loop through each virtual machine and gather disk information
    foreach($vm in $vms){

        Write-Host "[$i of $($vms.Count)] $($vm.Name)"
        $i++

        if($vm.StorageProfile.OsDisk.Vhd){

            # Gather unmnaged disk details and store as a PS custom object
            $osDiskDetails = GetUnmanagedDiskDetails -vhduri $vm.StorageProfile.OsDisk.Vhd.Uri -storageAccounts $storageAccounts

            $DiskObject = [PSCustomObject]@{
                SubscriptionName = $context.Subscription.Name
                SubscrpitionID = $context.Subscription.Id
                VMName = $VM.Name
                VMResourceGroup = $VM.ResourceGroupName
                Location = $VM.Location
                AvailabilitySet = ""
                VHDUri = $vm.StorageProfile.OsDisk.Vhd.Uri
                StorageType = $osDiskDetails.StorageType
                DiskType = "OS"
                Lun = "N/A"
                ProvisionedSizeInGB = $osDiskDetails.ProvisionedSize
                UsedSizeInGB = $osDiskDetails.UsedSize
                UsedDiskPercentage = $osDiskDetails.UsedDiskPercentage
            }

            # Add availability set, if applicable
            if($vm.AvailabilitySetReference.Id){
                $DiskObject.AvailabilitySet = ($vm.AvailabilitySetReference.Id | Split-Path -Leaf )                    
            }   

            [void]$unmanDisks.add($DiskObject)
        }

        foreach($disk in $vm.StorageProfile.DataDisks)
        {
            if($disk.Vhd){
                
                # Gather unmnaged disk details and store as a PS custom object
                $dataDiskDetails = GetUnmanagedDiskDetails -vhduri $disk.Vhd.Uri -storageAccounts $storageAccounts

                $DiskObject = [PSCustomObject]@{
                    SubscriptionName = $context.Subscription.Name
                    SubscrpitionID = $context.Subscription.Id
                    VMName = $VM.Name
                    VMResourceGroup = $VM.ResourceGroupName
                    Location = $VM.Location
                    AvailabilitySet = ""
                    VHDUri = $disk.Vhd.Uri
                    StorageType = $dataDiskDetails.StorageType
                    DiskType = "Data"
                    Lun = $disk.Lun
                    ProvisionedSizeInGB = $dataDiskDetails.ProvisionedSize
                    UsedSizeInGB = $dataDiskDetails.UsedSize
                    UsedDiskPercentage = $dataDiskDetails.UsedDiskPercentage
                }

                # Add availability set, if applicable
                if($vm.AvailabilitySetReference.Id){
                    $DiskObject.AvailabilitySet = ($vm.AvailabilitySetReference.Id | Split-Path -Leaf )                    
                }
                
                [void]$unmanDisks.add($DiskObject)   
            }
        }

    }
}

# If any unmanaged VMs exist, output results to CSV
if($unmanDisks){

    # Output to CSV
    if($ExportToCSV -eq $true){
        $unmanDisks | Export-Csv -Path $VmOutputPath -NoTypeInformation
        Write-Output "`nExported unmanaged disk report at $VmOutputPath`n"
    }else{
        foreach($disk in $unmanDisks){
            Write-Host "------------------------------------------------------"
            Write-Host ("Disk details for VM: {0}" -f $disk.VMName)
            Write-Host "------------------------------------------------------"
            Write-Host ("Subscription Name: {0}" -f $disk.SubscriptionName)
            Write-Host ("Subscription ID: {0}" -f $disk.SubscrpitionID)
            Write-Host ("Location: {0}" -f $disk.Location)
            Write-Host ("Availability Set: {0}" -f $disk.AvailabilitySet)
            Write-Host ("VHD Uri: {0}" -f $disk.VHDUri)
            Write-Host ("StorageType: {0}" -f $disk.StorageType)
            Write-Host ("Disk Type: {0}" -f $disk.DiskType)
            Write-Host ("Lun: {0}" -f $disk.Lun)
            Write-Host ("Provisioned Size In GB: {0}" -f $disk.ProvisionedSizeInGB)
            Write-Host ("Used Size In GB: {0}" -f $disk.UsedSizeInGB)
            Write-Host ("Used Disk Percentage: {0}" -f $disk.UsedDiskPercentage)
        }
    }

}
else{
    Write-Output "`nNo virtual machines with unmanaged disks were found`n"
}

# End Region

Write-Output "Script end"
