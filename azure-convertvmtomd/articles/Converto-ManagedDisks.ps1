<#
.NOTES
 	==================================================================================================================================================================
	Azure FastTrack - Managed Disks Program
	File:		Convertto-ManagedDisks.ps1	
	Purpose:	Updates unmanaged Azure VMs to managed VMs with target Data disks drives names.
	Version: 	1.0 - November 2017 - Alejandra Hernandez 
 	==================================================================================================================================================================
 .SYNOPSIS
	Updates unmanaged Azure VMs to managed VMs while keeping original data disks drives names.
 .DESCRIPTION
    This scripts updates: 
    1.) All VMs within an Availability Set, when the availability set parameter is specified
    OR
    2.) All VMs within a Resource Group that are not in an availability set when the availability set parameter is not specified

    Note:
        - The OS disk name will not be updated to the original naming convention! Otherwise, the VM would have to be re-provisioned
        and the VM will get its extensions configuration reset
        - There cannot be disk that are named the same within the same resource group, therefore this script will fail if there are
        disks with the same name in the resource group.
 .EXAMPLE
		Convertto-ManagedDisks `
		-SubscriptionID = "eaca98da-dead-4803-af35-f0edb23e0xxx" `
		-VMsResourceGroup = "AHTSTRGVMs" `
        -AvailabilitySetName = "AHTSTAS01" `
        -AvailabilitySetResourceGroup = "AHTSTRGVMs"
   =================================================================================================================================================================
#>

param(
	[Parameter(Mandatory=$true)][string]$SubscriptionID,
    [Parameter(Mandatory=$true)][string]$VMsResourceGroup,
    [Parameter(Mandatory=$false)][string]$AvailabilitySetName,
    [Parameter(Mandatory=$false)][string]$AvailabilitySetResourceGroup
)

try{
    #Login to Azure
    $Account = Login-AzureRmAccount
        if(!$Account) {
            Throw "Could not login to Azure"
        }
    Write-Output "Successfully logged into Azure"
     
    #Login to Subscription.
    Select-AzureRMSubscription -SubscriptionName $SubscriptionID
    Write-Output "The subscription context is set to Subscription ID: $SubscriptionID"
}
catch{
    Write-Error "Error logging in subscription ID $SubscriptionID" -ErrorAction Stop
}

$vmarray = @()
try{
    if($AvailabilitySetName){
        Write-Output "Availability Set parameter provided"
        # Convert Availability Set to support Managed Disks VMs
        $avSet = Get-AzureRmAvailabilitySet -ResourceGroupName $AvailabilitySetResourceGroup -Name $AvailabilitySetName
        Write-Output "Retrieving Availability Set: $AvailabilitySetName"
        Update-AzureRmAvailabilitySet -AvailabilitySet $avSet -Sku Aligned
        Write-Output "Successfully Converted Availability Set to support Managed Disks"
        $avSet = Get-AzureRmAvailabilitySet -ResourceGroupName $AvailabilitySetResourceGroup -Name $AvailabilitySetName
        # Collecting VM data from availability set
        Write-Output "Collecting VMs from Availability Set: $AvailabilitySetName"
        foreach($vmInfo in $avSet.VirtualMachinesReferences){
            $vmArray += (Get-AzureRmVM -ResourceGroupName $VMsResourceGroup | Where-Object {$_.Id -eq $vmInfo.id}).Name
        }
        Write-Output "Finished collecting VM data from Availability Set: $AvailabilitySetName"
        Write-Output "The following VMs will be converted to Managed Disks"
        foreach ($vmName in $vmArray){
            Write-Output $vmName
        }

    }
    else{
        Write-Output "No Availability Set parameter provided!"
        Write-Output "Collecting all VMs with no Availability Set from Resource Group: $VMsResourceGroup"
        $vmArrayTmp = Get-AzureRmVM -ResourceGroupName $VMsResourceGroup
        foreach($vmName in $vmArrayTmp){
            $VMObject = get-azurermvm -ResourceGroupName $VMsResourceGroup -Name $vmName.Name
            if($vmObject.AvailabilitySetReference -eq $null){
                $vmArray += $vmName.name
            }
        }
        Write-Output "Finished collecting VM data from Resource Group: $VMsResourceGroup"
        Write-Output "The following VMs will be converted to Managed Disks"
        foreach ($vmName in $vmArray){
            Write-Output $vmName
        }
    }
}
catch{
    Write-Error "Error collecting VM Data" -ErrorAction Stop
}

# For each VM convert VMs to Managed Disks
foreach($vmName in $vmArray)
{
  try{
    $Vm = get-azurermvm -ResourceGroupName $VMsResourceGroup -Name $vmName
    Write-Output "Stopping VM: $VMName"
    Stop-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
    Write-Output "VM: $VMName has been stopped"

    # Get old disk info
    Write-Output "Collecting current unmanaged data disks info VM: $VMName"
    $vmolddatadisks = $vm.StorageProfile.DataDisks
    Write-Output "Finished collecting current unmanaged data disks info for VM: $VMName"

    # Convert to Managed Disk TODO - ADD RETRY OPERATION
    Write-Output "Converting VM: $VMName to Managed Disks"
    ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name
    Stop-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
    Write-Output "Finished converting VM: $VMName to Managed Disks"
    
    # Collect New auto-generated MD Data Disks Names Data
    Write-Output "Collecting current managed data disks info VM: $VMName"
    $vm = Get-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -VMName $VMName
    $vmnewdatadisks = $vm.StorageProfile.DataDisks
    Write-Output "Finished collecting current managed data disks info for VM: $VMName"

    $count = 0
    Foreach($disk in $vmnewdatadisks){
            
            # Create a new managed disk with target naming convention
            $DiskName = $disk.Name
            $oldDiskName = ($vmolddatadisks[$count]).Name
            if($DiskName -ne $oldDiskName){
                Write-Output "Updating managed disk from name $oldDiskName to name: $diskName for VM: $VMName"
                $currentMDDisk = get-azurermdisk -ResourceGroupName $vm.ResourceGroupName -DiskName $disk.name
                $diskConfig = New-AzureRmDiskConfig -SourceResourceId $currentMDDisk.Id -Location $currentMDDisk.Location -CreateOption Copy 
                New-AzureRmDisk -Disk $diskConfig -DiskName (($vmolddatadisks[$count]).name) -ResourceGroupName $vm.ResourceGroupName
                # De-attach old Disks from VM
                Remove-AzureRmVMDataDisk -VM $vm -Name $disk.name
                Update-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -VM $vm
                # Delete old managed disk
                Remove-AzureRmDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $disk.Name -force
                # Re-attach new Disks to VM 
                $currentTargetDisk = Get-AzureRmDisk -ResourceGroupName $vm.ResourceGroupName -DiskName (($vmolddatadisks[$count]).Name)
                $vm = Add-AzureRmVMDataDisk -CreateOption Attach -DiskSizeInGB (($vmolddatadisks[$count]).DiskSizeGB) -Caching (($vmolddatadisks[$count]).Caching) -Lun (($vmolddatadisks[$count]).Lun) -VM $vm -ManagedDiskId $currentTargetDisk.Id
                Update-AzureRmVM -VM $vm -ResourceGroupName $vm.ResourceGroupName
                Write-Output "Finished updating managed disk from name $oldDiskName to name: $diskName for VM: $VMName"
            }
            $Count = $count+1
    }
    #Restart VMs
    Write-Output "Starting VM: $VMName"
    Start-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
    Write-Output "VM: $VMName has started"
    }
    catch{
        $VMName = $vm.Name
        Write-error "There was an error converting VM: $VMName to Managed Disks, moving onto the next VM" -ErrorAction Stop
    }
}

Write-Output "Script has ended"










