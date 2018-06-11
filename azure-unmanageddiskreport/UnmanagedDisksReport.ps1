<#
.NOTES
 	==================================================================================================================================================================
	Azure Managed Disks Program
	File:		UnmanagedDisksReport.ps1
	Purpose:	Generate a CSV report of unmanaged disk information for ARM virtual machines
	Version: 	1.2 
    Changes:    1.2 - Updated for AzureRM version 6.*. Skip premium storage by default. Efficieny improvements. - June 2018
                1.1 - Fixed GetPageRanges timeout errors - Feb 2018
                1.0 - Original
 	==================================================================================================================================================================
 .SYNOPSIS
    Generate a CSV report for virtual machines using unmanaged disks
 .DESCRIPTION
    This script will gather information in an Azure subscription about unmanaged disks attached to ARM virtual machines 
    and at what capacity they are being used.
 .PARAMTERS
    SubscriptionID - Azure subscription ID to run this script against
    ReportOutputFolder - Output location for the CSV generated in this script
    SkipPremium - Enable the switch to skip gathering details on Premium unmanaged disks
 .EXAMPLE
		UnmanagedDisksReport.ps1 -SubscriptionID "xxxxx-xxxxxx-xxxxxxx-xxxxx" -ReportOutputFolder "C:\ScriptReports\"
   ===================================================================================================================================================================
#>

param(
	[Parameter(Mandatory=$true)]
    [string]$SubscriptionID,
    [Parameter(Mandatory=$true)]
    [string]$ReportOutputFolder,
    [Parameter(Mandatory=$false)]
    [switch]$IncludePremium
)

Write-Output "Script start`n"

if(-not(Test-Path -Path $ReportOutputFolder)){
    throw "The output folder specified does not exist at $ReportOutputFolder"
}

# Checking for Windows PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Windows PowerShell version 5.0 or above must be installed to use the latest AzureRM PowerShell modules." -ForegroundColor Red
    Exit -2
}

# Checking for Azure PowerShell module
$modlist = Get-Module -ListAvailable -Name 'AzureRm'
if (($modlist -eq $null) -or ($modlist.Version.Major -lt 6)){
    Write-Host "Please install the AzureRM Powershell module, version 6.* or above." -ForegroundColor Red
    Write-Host "The latest Azure Powershell versions can be found in the following URL:" -ForegroundColor Red
    Write-Host "https://www.powershellgallery.com/packages/AzureRM/" -ForegroundColor Red
    Exit -2
}

try{
    # login to Azure
    # to skip logging into Azure for authenticated sessions, comment out the next 5 lines
    $account = Login-AzureRmAccount
    if(!$account) {
        Throw "Could not login to Azure"
    }
    Write-Output "Successfully logged into Azure"
    
    # set context to the subscription
    Select-AzureRMSubscription -SubscriptionName $SubscriptionID
    Write-Output "The subscription context is set to Subscription ID: $SubscriptionID`n"
}
catch{
    Write-Error "Error logging in subscription ID $SubscriptionID`n" -ErrorAction Stop
}

$timeStamp = Get-Date -Format yyyyMMddHHmm
$VmOutputPath = "$ReportOutputFolder\UnmanagedDisksResults-$timeStamp.csv"

# This function will gather detailed information about unmanaged disks
function GetUnmanagedDiskDetails{

    param(
        [Parameter(Mandatory=$true)] $vhduri,
        [Parameter(Mandatory=$true)] $storageAccounts
        )

    $diskUri = New-Object System.Uri($vhduri)

    $storageAccount =  $diskUri.Host.Split('.')[0]
    $vhdFileName = $diskUri.Segments[$diskUri.Segments.Length-1]
    $container = $diskUri.Segments[1].Trim('/')

    $rg = ($storageAccounts | Where-Object { $_.Name -eq $storageAccount }).ResourceGroupName

    $type = (Get-AzureRmStorageAccount -Name $storageAccount -ResourceGroupName $rg).Sku.Tier

    # Skip gathering information on premium unmanaged disks based on IncludePremium switch
    if(($type -eq "Premium") -and !$IncludePremium){
        return New-Object psobject -Property @{Uri=$vhduri;StorageType=$type;ProvisionedSize="Skipped";UsedSize="Skipped";UsedDiskPercentage="Skipped"}
    }

    $storageAccountKey = (Get-AzureRMStorageAccountKey -Name $storageAccount -ResourceGroupName $rg)[0].Value
    $storageAccountContext = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageAccountKey 

    try{
        $blob = Get-AzureStorageBlob -Blob $vhdFileName -Container $container -Context $storageAccountContext -ErrorAction Stop
    }
    # Catching any errors for getting the storage blob
    catch{
        Write-Host -ForegroundColor Red "There was an error while accessing the blob with the URI: $vhduri"
        Write-Host -ForegroundColor Red $_.Exception
        
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
            catch
            {
                $ErrorTime = Get-Date
                $Timeout = $ErrorTime - $StartTime

                Write-Host -ForegroundColor Yellow "Timeout In Seconds: $($Timeout.TotalSeconds)"
                Write-Host -ForegroundColor Yellow "There was likely a GetPageRanges timeout while accessing the blob with the URI: $vhduri"
                Write-Host -ForegroundColor Yellow "Attempt $(3 - $iPageRangeSuccessRetries) of 2"
                
                if($iPageRangeSuccessRetries -eq 2) { Write-Host -ForegroundColor Yellow "Retrying using range size parameter..." }

                Write-Host -ForegroundColor Red $_.Exception

                #reset to original value to avoid page ranges to be added multiple times in a retry
                $blobSizeInBytes = 124 + $blob.Name.Length * 2 

                Sleep -Seconds 2
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
            Write-Host -ForegroundColor Red "Failed to retrieve used space for $vhduri"
            $usedSizeInGiB = -1
            $usedDiskPercentage = -1
        }
                
    }

    return New-Object psobject -Property @{StorageType=$type;ProvisionedSize=$provisionedSizeInGib;UsedSize=$usedSizeInGiB;UsedDiskPercentage=$usedDiskPercentage}
}

# Region Gather Unmanaged Disk Information

Write-Host "Gathering virtual machine information...`n"
Write-Host "Progress Status:"
Write-Host "[<Current Number> of <Total Number of Unmanaged VMs>] <VM Name>`n"

# Get all ARM virtual machines and storage accounts
$vms = Get-AzureRmVM | where {$_.StorageProfile.OsDisk.ManagedDisk -eq $null}
$storageAccounts = Get-AzureRmResource -ResourceType 'Microsoft.Storage/storageAccounts'  
$unmanDisks = New-Object -TypeName System.Collections.ArrayList
[int]$i = 1

# Loop through each virtual machine and gather disk information for unmanaged disks only
foreach($vm in $vms){

    Write-Host "[$i of $($vms.Count)] $($vm.Name)"
    $i++

    if($vm.StorageProfile.OsDisk.Vhd){

        # Gather unmnaged disk details and store as a PS custom object
        $osDiskDetails = GetUnmanagedDiskDetails -vhduri $vm.StorageProfile.OsDisk.Vhd.Uri -storageAccounts $storageAccounts

        $DiskObject = [PSCustomObject]@{
            VMName = $VM.Name
            VMResourceGroup = $VM.ResourceGroupName
            Location = $VM.Location
            AvailabilitySet = ""
            VHDUri = $vm.StorageProfile.OsDisk.Vhd.Uri
            StorageType = $osDiskDetails.StorageType
            DiskType = "OS"
            ProvisionedSizeInGB = $osDiskDetails.ProvisionedSize
            UsedSizeInGB = $osDiskDetails.UsedSize
            UsedDiskPercentage = $osDiskDetails.UsedDiskPercentage
        }

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
                VMName = $VM.Name
                VMResourceGroup = $VM.ResourceGroupName
                Location = $VM.Location
                AvailabilitySet = ""
                VHDUri = $disk.Vhd.Uri
                StorageType = $dataDiskDetails.StorageType
                DiskType = "Data"
                ProvisionedSizeInGB = $dataDiskDetails.ProvisionedSize
                UsedSizeInGB = $dataDiskDetails.UsedSize
                UsedDiskPercentage = $dataDiskDetails.UsedDiskPercentage
            }

            if($vm.AvailabilitySetReference.Id){
                $DiskObject.AvailabilitySet = ($vm.AvailabilitySetReference.Id | Split-Path -Leaf )                    
            }
            
            [void]$unmanDisks.add($DiskObject)   
        }
    }

}

# If any unmanaged VMs exist, output results to CSV
if($unmanDisks){

    # Output to CSV
    $unmanDisks | Export-Csv -Path $VmOutputPath -NoTypeInformation
    Write-Output "`nExported unmanaged disk report at $VmOutputPath`n"
}
else{

    Write-Output "`nNo virtual machines with unmanaged disks were found`n"
}

# End Region

Write-Output "Script end"