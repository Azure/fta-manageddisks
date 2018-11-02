# Convert a VM to Managed Disks using Powershell

## Table of Contents

* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Script](#script)

## Introduction
The goal of this script is to convert an existing VM (single instance or in an Availability Set) to use managed disks. 

The script will convert the VM to managed disks while keeping all VM diagnostics, VM extensions and VM OS and data disks names. Optionally, you can change the names of the OS disks
and data disks if desired during the conversion.

We've encountered customer scenarios where running the ConvertTo-AzureRmVMManagedDisk causes the new disks names to be auto-renamed using a long cryptic GUID name, which often times breaks customer's naming conventions. This script should assist in providing guidance around converting VMs to managed disks while keeping prior OS and data disks naming convention.

This script will not delete any storage accounts, VHDs, or managed disks after it's done running. Please VM disks integrity prior to deleting old unmanaged and managed disks.

Important: Managed Disks requires that all disks names within the same resource group be unique.

## Prerequisites
To run this script successfully, you will need:
* You must have access and be able to deploy into a Microsoft Azure Subscription
* Access to Azure PowerShell modules which support the ConvertTo-AzureRmVMManagedDisk cmdlet.
* Data disks names for all VMs within the resource group are unique

##  Convert existing VM to Managed Disks with Azure PowerShell
1. Open a PowerShell session with the Azure PowerShell modules loaded.

2. Login to Azure and select the subscripton to create the policy.
    > Note: Substitute the placeholder in the code with your subscription ID.
```powershell
Login-AzureRmAccount

Select-AzureRmSubscription -SubscrpitionId xxxxxx-xxxxxx-xxxxxx-xxxxxx
```

3. Save the script locally and run using the following cmdlets with desired parameter values:
If you don't specify the "AvailabilitySetName" and "AvailabilitySetResourceGroup" parameters the script will loop for all VMs in the resource group which are not in an availability set and convert them to managed disks
```powershell

Converto-ManagedDisks.ps1 `
        -subscriptionid "9a5db7af-43bd-4143-81e3-0e57ae3xxxx" `
        -VMsResourceGroup "ConvertToMD-RG"
```

If you don't specify the "NewDiskNames" array parameter the script will keep the original names for the OS and data disks
```powershell

Converto-ManagedDisks.ps1 `
        -subscriptionid "9a5db7af-43bd-4143-81e3-0e57ae3xxxx" `
        -VMsResourceGroup "ConvertToMD-RG" `
        -AvailabilitySetName "MDVMAS01" `
        -AvailabilitySetResourceGroup "ConvertToMD-ASRG" 
```
If you specify the "NewDiskNames" array parameter to rename the OS and data disks. The array is of dynamic size and expect the following format: "VMName01", "VMName01OSDisk", "VMName01DataDisk1", "VMName01DataDisk2", "VMName01DataDiskN...", "VMName02", "VMName02OSDisk", "VMName02DataDiskN..."
```powershell

Converto-ManagedDisks.ps1 `
        -subscriptionid "9a5db7af-43bd-4143-81e3-0e57ae3xxxx" `
        -VMsResourceGroup "ConvertToMD-RG" `
        -AvailabilitySetName "MDVMAS01" `
        -AvailabilitySetResourceGroup "ConvertToMD-ASRG" `
        -NewDiskNames "MDVM01", "newvm01osdisk","newvm01datadisk01","newvm01datadisk02", "MDVM02", "newvm02osdisk","newvm02datadisk01"
```

## Script
The following is the script source code. Script workflow was created by leveraging the following Azure documentation walkthroughs:
* [Convert Unmanaged to Managed Disks](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/convert-unmanaged-to-managed-disks)
* [Copy Managed Disks to same or different subscription](https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-copy-managed-disks-to-same-or-different-subscription)
* [Attach a Managed Disks to a VM](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/attach-disk-ps)
* [Swap VM OS Disk](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/os-disk-swap)
```powershell
<#
.NOTES
 	==================================================================================================================================================================
	Azure FastTrack - Managed Disks Program
	File:		Convertto-ManagedDisks.ps1	
	Purpose:	Updates unmanaged Azure VMs to managed VMs with target OS and Data disks drives names.
	Version: 	2.0 - October 2018 - FastTrack for Azure 
 	==================================================================================================================================================================
 .SYNOPSIS
	Updates unmanaged Azure VMs to managed VMs while keeping original OS and data disks names. Optionally, you can specify new names for the OS and data disks.
 .DESCRIPTION
    This scripts updates: 
    1.) All VMs within an Availability Set, when the availability set parameter is specified
    OR
    2.) All VMs within a Resource Group that are not in an availability set when the availability set parameter is not specified
    3.) Keeps the existin names for both OS and data disks when the "NewDiskNames" parameter is not specified.

    Note:
        - There cannot be disk that are named the same within the same resource group, therefore this script will fail if there are
        disks with the same name in the resource group.
 
 .EXAMPLE
		.\Converto-ManagedDisks.ps1 `
        -subscriptionid "9a5db7af-43bd-4143-81e3-0e57ae3xxxx" `
        -VMsResourceGroup "ConvertToMD-RG" `
        -AvailabilitySetName "MDVMAS01" `
        -AvailabilitySetResourceGroup "ConvertToMD-ASRG" `
        -NewDiskNames "MDVM01", "newvm01osdisk","newvm01datadisk01","newvm01datadisk02", "MDVM02", "newvm02osdisk","newvm02datadisk01"
   =================================================================================================================================================================
#>

param(
	[Parameter(Mandatory=$true)][string]$SubscriptionID,
    [Parameter(Mandatory=$true)][string]$VMsResourceGroup,
    [Parameter(Mandatory=$false)][string]$AvailabilitySetName,
    [Parameter(Mandatory=$false)][string]$AvailabilitySetResourceGroup,
    [Parameter(Mandatory=$false)][string[]]$NewDiskNames
)

$vmarray = @()
$diskcount = 0
$count = 0

try{
    #Login to Azure
    $Account = Login-AzureRmAccount
        if(!$Account) {
            Throw "Could not login to Azure"
        }
    Write-Host "Successfully logged into Azure" -ForegroundColor Green
     
    #Login to Subscription.
    Select-AzureRMSubscription -SubscriptionName $SubscriptionID
    write-host "The subscription context is set to Subscription ID: $SubscriptionID" -ForegroundColor Green
}
catch{
    Write-Error "Error logging in subscription ID $SubscriptionID" -ErrorAction Stop -ForegroundColor Green
}


try{
    if($AvailabilitySetName){
        write-host "Availability Set parameter provided" -ForegroundColor Green
        # Convert Availability Set to support Managed Disks VMs
        $avSet = Get-AzureRmAvailabilitySet -ResourceGroupName $AvailabilitySetResourceGroup -Name $AvailabilitySetName
        write-host "Retrieving Availability Set: $AvailabilitySetName" -ForegroundColor Green
        Update-AzureRmAvailabilitySet -AvailabilitySet $avSet -Sku Aligned
        write-host "Successfully Converted Availability Set to support Managed Disks" -ForegroundColor Green
        $avSet = Get-AzureRmAvailabilitySet -ResourceGroupName $AvailabilitySetResourceGroup -Name $AvailabilitySetName
        # Collecting VM data from availability set
        write-host "Collecting VMs from Availability Set: $AvailabilitySetName" -ForegroundColor Green
        foreach($vmInfo in $avSet.VirtualMachinesReferences){
            $vmArray += (Get-AzureRmVM -ResourceGroupName $VMsResourceGroup | Where-Object {$_.Id -eq $vmInfo.id}).Name
        }
        write-host "Finished collecting VM data from Availability Set: $AvailabilitySetName" -ForegroundColor Green
        write-host "The following VMs will be converted to Managed Disks" -ForegroundColor Green
        foreach ($vmName in $vmArray){
            write-host $vmName -ForegroundColor Green
        }

    }
    else{
        write-host "No Availability Set parameter provided!" -ForegroundColor Green
        write-host "Collecting all VMs with no Availability Set from Resource Group: $VMsResourceGroup" -ForegroundColor Green
        $vmArrayTmp = Get-AzureRmVM -ResourceGroupName $VMsResourceGroup
        foreach($vmName in $vmArrayTmp){
            $VMObject = get-azurermvm -ResourceGroupName $VMsResourceGroup -Name $vmName.Name
            if($vmObject.AvailabilitySetReference -eq $null){
                $vmArray += $vmName.name
            }
        }
        write-host "Finished collecting VM data from Resource Group: $VMsResourceGroup" -ForegroundColor Green
        write-host "The following VMs will be converted to Managed Disks" -ForegroundColor Green
        foreach ($vmName in $vmArray){
            write-host $vmName -ForegroundColor Green
        }
    }
}
catch{
    Write-Error "Error collecting VM Data" -ErrorAction Stop
}

# For each VM convert VMs to Managed Disks
foreach($vmName in $vmArray){
  try{
    $Vm = get-azurermvm -ResourceGroupName $VMsResourceGroup -Name $vmName
    write-host "Stopping VM: " $VM.Name -ForegroundColor Green
    Stop-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
    write-host "VM: " $VM.name " has been stopped" -ForegroundColor Green

    # Get old disk info
    write-host "Collecting current unmanaged disks info VM: " $VM.Name -ForegroundColor Green
    $vmoldosdisk = $vm.StorageProfile.OsDisk
    $vmolddatadisks = $vm.StorageProfile.DataDisks
    write-host "Finished collecting current unmanaged disks info for VM: " $VM.Name -ForegroundColor Green

    for($i=0; $i -lt 3; $i++){
        # Convert to Managed Disk 
        write-host "Attempting to convert VM: " $Vm.name " to Managed Disks" -ForegroundColor Green
        ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $vm.ResourceGroupName -VMName $vmName -ErrorAction SilentlyContinue | Out-Null
        Stop-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
    }

    write-host "Finished converting VM: " $VM.Name " to Managed Disks" -ForegroundColor Green 

    if($NewDiskNames){
        #Create new OS Managed Disk with target naming convention
        $Vm = get-azurermvm -ResourceGroupName $VMsResourceGroup -Name ($NewDiskNames[$diskcount])
        $currentMDOSDisk = get-azurermdisk -ResourceGroupName $vm.ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
        $OSdiskConfig = New-AzureRmDiskConfig -SourceResourceId $currentMDOSDisk.Id -Location $currentMDOSDisk.Location -CreateOption Copy 
        # Move to OS Disk Info
        $diskcount++
        write-host "Updating managed OS disk to name: " $NewDiskNames[$diskcount] " for VM: " $VM.Name -ForegroundColor Green
        $newMDOSDisk = New-AzureRmDisk -Disk $OSDiskConfig -DiskName ($NewDiskNames[$diskcount]) -ResourceGroupName $vm.ResourceGroupName
        write-host "Finished updating managed OS disk to name: " $NewDiskNames[$diskcount] " for VM: " $VM.Name -ForegroundColor Green
    }else{
        #Create new OS Managed Disk with target naming convention
        $Vm = get-azurermvm -ResourceGroupName $VMsResourceGroup -Name $VM.Name
        $currentMDOSDisk = get-azurermdisk -ResourceGroupName $vm.ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
        $OSdiskConfig = New-AzureRmDiskConfig -SourceResourceId $currentMDOSDisk.Id -Location $currentMDOSDisk.Location -CreateOption Copy 

        write-host "Updating managed OS disk to name: " $vmoldosdisk.Name " for VM: " $VM.Name -ForegroundColor Green
        $newMDOSDisk  = New-AzureRmDisk -Disk $OSDiskConfig -DiskName $vmoldosdisk.Name -ResourceGroupName $vm.ResourceGroupName 
        write-host "Finished updating managed OS disk to name: " $vmoldosdisk.Name " for VM: " $VM.Name -ForegroundColor Green
    }
    
    #Swap OS Disk 
    write-host "Swaping OS Disk to new target replica OS Disk" -ForegroundColor Green
    Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $newMDOSDisk.Id -Name $newMDOSDisk.Name
    Update-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -VM $vm

    # Collect New auto-generated MD Data Disks Names Data
    write-host "Collecting current managed data disks info VM: " $VM.Name -ForegroundColor Green
    $vm = Get-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -VMName $VM.Name
    $vmnewdatadisks = $vm.StorageProfile.DataDisks
    write-host "Finished collecting current managed data disks info for VM: " $VM.Name -ForegroundColor Green

    #Move to Data Disk Info
    $diskcount++

    if($vmolddatadisks){
        Foreach($disk in $vmnewdatadisks){            
                # Create a new managed disk with target naming convention
                $oldDiskName = ($vmolddatadisks[$count]).Name
                if($NewDiskNames){
                    write-host "Updating managed disk to name: " $NewDiskNames[$diskcount] " for VM: " $VM.Name -ForegroundColor Green
                    $currentMDDisk = get-azurermdisk -ResourceGroupName $vm.ResourceGroupName -DiskName $disk.name
                    $diskConfig = New-AzureRmDiskConfig -SourceResourceId $currentMDDisk.Id -Location $currentMDDisk.Location -CreateOption Copy 
                    New-AzureRmDisk -Disk $diskConfig -DiskName ($NewDiskNames[$diskcount]) -ResourceGroupName $vm.ResourceGroupName
                    # De-attach old Disks from VM
                    Remove-AzureRmVMDataDisk -VM $vm -Name $disk.name
                    Update-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -VM $vm
                    # Re-attach new Disks to VM 
                    $currentTargetDisk = Get-AzureRmDisk -ResourceGroupName $vm.ResourceGroupName -DiskName ($NewDiskNames[$diskcount])
                    $vm = Add-AzureRmVMDataDisk -CreateOption Attach -DiskSizeInGB (($vmolddatadisks[$count]).DiskSizeGB) -Caching (($vmolddatadisks[$count]).Caching) -Lun (($vmolddatadisks[$count]).Lun) -VM $vm -ManagedDiskId $currentTargetDisk.Id
                    Update-AzureRmVM -VM $vm -ResourceGroupName $vm.ResourceGroupName
                    write-host "Finished updating managed disk to name: " $NewDiskNames[$diskcount] " for VM: " $VM.Name -ForegroundColor Green
                    
                                
                }else{
                    write-host "Updating managed disk to name: " $disk.name " for VM: " $VM.Name -ForegroundColor Green
                    $currentMDDisk = get-azurermdisk -ResourceGroupName $vm.ResourceGroupName -DiskName $disk.name
                    $diskConfig = New-AzureRmDiskConfig -SourceResourceId $currentMDDisk.Id -Location $currentMDDisk.Location -CreateOption Copy 
                    New-AzureRmDisk -Disk $diskConfig -DiskName (($vmolddatadisks[$count]).name) -ResourceGroupName $vm.ResourceGroupName
                    # De-attach old Disks from VM
                    Remove-AzureRmVMDataDisk -VM $vm -Name $disk.name
                    Update-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -VM $vm
                    # Re-attach new Disks to VM 
                    $currentTargetDisk = Get-AzureRmDisk -ResourceGroupName $vm.ResourceGroupName -DiskName (($vmolddatadisks[$count]).Name)
                    $vm = Add-AzureRmVMDataDisk -CreateOption Attach -DiskSizeInGB (($vmolddatadisks[$count]).DiskSizeGB) -Caching (($vmolddatadisks[$count]).Caching) -Lun (($vmolddatadisks[$count]).Lun) -VM $vm -ManagedDiskId $currentTargetDisk.Id
                    Update-AzureRmVM -VM $vm -ResourceGroupName $vm.ResourceGroupName
                    write-host "Finished updating managed disk to name: " $disk.name " for VM: " $VM.Name -ForegroundColor Green
                }
                $diskcount++
                $count++ 
        }
        
    }
    #Restart VMs
    write-host "Starting VM: " $VM.Name -ForegroundColor Green
    Start-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
    write-host "VM: " $VM.name " has started" -ForegroundColor Green
    }
    catch{
        $VMName = $vm.Name
        Write-error "There was an error converting VM: " $VM.name " to Managed Disks, moving onto the next VM" -ErrorAction Stop
    }
}

<<<<<<< HEAD:azure-convertvmtomd/articles/azure-convert-vms-to-md.md
write-host "Script has ended" -ForegroundColor Green































=======
Write-Output "Script has ended"
>>>>>>> 87d8c543a4476984cf3de8e17fc7f2d0585965fb:azure-convertvmtomd/azure-convert-vms-to-md.md
