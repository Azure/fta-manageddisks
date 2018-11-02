#Disk only needs to be created if source VHDs are in a different subscription
#Source VHDs must be in the same region as disks and image!!

$resourceGroupName = 'customimages-rg'
$diskName = "VMSSWindows_BaseIIS_southcentralus"
$vhdUri = "https://baseiissta.blob.core.windows.net/vhds/BaseIISVM20171126165309.vhd"
$storageId = '/subscriptions/9a5db7af-43bd-4143-81e3-0e57ae339b9f/resourceGroups/vmsststrg01/providers/Microsoft.Storage/storageAccounts/baseiissta'
$location = 'southcentralus'
$storageType = 'StandardLRS'
$imageName = 'VMSSWindows_BaseIIS_southcentralus'
$diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Import -SourceUri $vhdUri -StorageAccountId $storageId -DiskSizeGB 128
$osDisk = New-AzureRmDisk -DiskName $diskName -Disk $diskConfig -ResourceGroupName $resourceGroupName
$imageConfig = New-AzureRmImageConfig -Location $location
$imageConfig = Set-AzureRmImageOsDisk -Image $imageConfig -OsType Windows -OsState Generalized -ManagedDiskId $osDisk.Id
$image = New-AzureRmImage -ImageName $imageName -ResourceGroupName $resourceGroupName -Image $imageConfig   
