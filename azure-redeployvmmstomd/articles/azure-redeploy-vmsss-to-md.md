# Redeploy a VMSS using Managed Disks

* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Script](#Script)

## Introduction
The goal of these ARM templates is to re-deploy a VMMS using managed disks. 

There exist three scenarios to consider: 
* VMSS from a custom image 
* VMSS with post-provisioning configs (DSC or custom script extensions) 
* VMSS with both custom image and post provisioning configs.

We will cover the first two scenarios, re-deploying a VMSS from a custom image and re-deploying a VMSS with post-provisioning configs using DSC.

At a high level, the following are the steps when re-deploying an existing unmanaged disks VMSS to a managed disks VMSS:

1. Modify existing or create new VMSS ARM template to support MD.
2. Modify template to deploy to an existing subnet. 
3. Update the load balancer configuration.

Considerations:
* The existing load balancer for the VMSS is non-modifiable. A new load balancer must be created for the new VMSS deployment.
* Unmanaged VMSS do not support data disks. Managed disks VMSS do support data disks.

## Prerequisites for deploying a managed disks VMSS from custom images
You must create a managed image for the VMSS to reference. The managed disk image must exist in the same subscription and same region as the VMSS.

The managed image must be created from a .VHD file which exist in the same region and subscription. You can follow the steps outlined in our documentation to [Create a Managed Image from a .VHD file](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/capture-image-resource#create-image-from-a-vhd-in-a-storage-account).

Alternatively, if you wish to create a managed image from a .VHD file which exist in a storage account in the same region but from a different subscription then you can use the workaround below. This workaround creates a managed disk resouce from the source .VHD file and then a managed image from this managed disks resource. The managed disk resource can be deleted once the managed image has been created successfully.

>Note: This workaround will only work as long as both subscriptions share the same Azure AD tenant and region.

1. Open a PowerShell session with the Azure PowerShell modules loaded.

2. Login to Azure and select the subscripton to create the policy. Substitute the placeholder in the code with the target subscription ID in which the managed image will be created.
```powershell
Login-AzureRmAccount

Select-AzureRmSubscription -SubscrpitionId xxxxxx-xxxxxx-xxxxxx-xxxxxx
```
3. Save the script locally and fill in the variables as appropriate for your environment:
```powershell
# Create-ManagedDiskImage.ps1
# Variables
$resourceGroupName = 'customimages-rg' # Target resource group name where the image will exist. Image must be created in the same region and subscription as the VMSS.
$diskName = "VMSSWindows_BaseIIS_southcentralus" # Name for the managed disk resource
$vhdUri = "https://baseiissta.blob.core.windows.net/vhds/BaseIISVM20171126.vhd" # URI for the source .VHD file.
$storageId = '/subscriptions/9a5db7af-43bd-4143-81e3-0e57ae33xxx/resourceGroups/vmsststrg01/providers/Microsoft.Storage/storageAccounts/baseiissta' # Resource ID for the storage account which contains the .VHD file.
$location = 'southcentralus' # Target region where the managed image will be deployed
$storageType = 'StandardLRS' # Managed Image storage type
$imageName = 'VMSSWindows_BaseIIS_southcentralus' # Managed Image Name

#Script Body
#Create managed disk from existing .VHD file
$diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Import -SourceUri $vhdUri -StorageAccountId $storageId -DiskSizeGB 128
$osDisk = New-AzureRmDisk -DiskName $diskName -Disk $diskConfig -ResourceGroupName $resourceGroupName
#Create managed image from managed disk.
$imageConfig = New-AzureRmImageConfig -Location $location
$imageConfig = Set-AzureRmImageOsDisk -Image $imageConfig -OsType Windows -OsState Generalized -ManagedDiskId $osDisk.Id
$image = New-AzureRmImage -ImageName $imageName -ResourceGroupName $resourceGroupName -Image $imageConfig   

```

## Modify/Create an ARM Template to deploy the Managed Disks VMSS from a custom managed image.

This ARM template was created by leveraging the following Azure documentation walkthroughs:
* [Convert a VMSS ARM Template to VMSS ARM template using Managed Disks](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-convert-template-to-md)
* [201-vmss-windows-customimage](https://github.com/Azure/azure-quickstart-templates/tree/master/201-vmss-windows-customimage)

## Modify/Create an ARM Template to deploy the Managed Disks VMSS with post provisioning DSC.

This ARM template was created by leveraging the following Azure documentation walkthroughs:
* [Convert a VMSS ARM Template to VMSS ARM template using Managed Disks](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-convert-template-to-md)
* [201-vmss-custom-script-windows](https://github.com/Azure/azure-quickstart-templates/tree/master/201-vmss-custom-script-windows), optional, for VMSS with post provisioning using custom scripts.
* [201-vmss-windows-webapp-dsc-autoscale](https://github.com/Azure/azure-quickstart-templates/tree/master/201-vmss-windows-webapp-dsc-autoscale)

## Modify the ARM Template to deploy the Managed Disks VMSS to an existing Vnet subnet.

Modify your ARM templates as follows:
1. Create the below new parameters in your parameters `<azuredeploy>`.parameters.json file and main Azure template `<azuredeploy>`.json file. 
    * Parameter for existing Vnet name
    * Parameter for existing subnet name
    * Parameter for existing Vnet Resource Group Name

Example, `<azuredeploy>`.paramteres.json file:
```json

    "existingVnetResourceGroupName": {
      "value": "vmsststrg04"
    },
    "existingVnetName": {
      "value": "vmssunm02vnet"
    },
    "existingSubnetName": {
      "value": "vmssunm02subnet"
    }

```

Example, `<azuredeploy>`.json file:
```json

    "existingVnetResourceGroupName": {
      "type": "string",
      "metadata": {
        "description": "Name of the resourceGroup for the existing virtual network to deploy the scale set into."
      }
    },
    "existingVnetName": {
      "type": "string",
      "metadata": {
        "description": "vName of the existing virtual network to deploy the scale set into."
      }
    },
    "existingSubnetName": {
      "type": "string",
      "metadata": {
        "description": "Name of the existing subnet to deploy the scale set into."
      }
    }

```
2. Remove any existing Vnet creation resource specified in your existing ARM `<azuredeploy>`.json template's resources section.
3. Update the existing subnet reference for the VMSS resource specified in your existing ARM `<azuredeply>`.json template's resource section to the ID of the existing subnet.

Example, `<azuredeploy>`.json file:
```json
...
    "properties": {
        "subnet": {
            "id": "[resourceId(parameters('existingVnetResourceGroupName'), 'Microsoft.Network/virtualNetworks/subnets', parameters('existingVnetName'), parameters('existingSubNetName'))]"
            },
...
```

## Modify the ARM Template to deploy the Managed Disks VMSS using same configurations as unmanaged disks VMSS.

Modify your ARM templates as follows:
1. Remove any existing storage account creation resource specified in your existing ARM `<azuredeploy>`.json template's resources section.
2. Update your VMSS storage profile properties to remove any references to a VHD     
```json
...
"storageProfile": {
            "imageReference": "[variables('imageReference')]",
            "osDisk": {
              "caching": "ReadWrite",
              "createOption": "FromImage"
            }
          },  
          "osProfile": {
            "computerNamePrefix": "[variables('namingInfix')]",
            "adminUsername": "[parameters('adminUsername')]",
            "adminPassword": "[parameters('adminPassword')]"
          },
          "networkProfile": {
...
```

## Update the internal Load Balancer Configuration
**Option 1:** Update DNS and other internal systems to point to new ILB DNS or IP (if static IP is used).

**Option 2:** Static IP ILB-  Set old VMSS ILB IP to unused IP from subnet. Then update new VMSS ILB IP to old IP address. You can configure the internal IP address as static for a VM through PowerShell [here](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-static-private-ip-arm-ps).


## Update the external Load Balancer Configuration
**Option 1:** Update external sources (Public DNS registrar or Traffic Manager) to new LB DNS or IP (if static IP is used). 

**Option 2:** Swap IP Front end configurations between old VMSS LB IP and new VMSS LB IP.
1. Navigate to the unmanaged VMSS load balancer front-end IP configuration and assign the unmanaged VMSS load balancer a Temp PIP.
2.  Navigate to the managed VMSS load balancer front-end IP configuration and assign the managed VMSS load balancer the old PIP that was assigned to the unmanaged VMSS.
3. You can delete the old unmanaged VMSS and load balancer as well as the two orphan public IPs.


# Additional Considerations
* VMSS Auto scale settings are the same between unmanaged VMSS and managed VMSS.
* VMSS Upgrade plan is the same: Automatic vs. Manual between unmanaged VMSS and managed VMSS.
* OS Disk caching is the same between unmanaged VMSS and managed VMSS.
* Load Balancing configuration (load balancing rules, NAT rules, etc.) between unmanaged VMSS and managed VMSS.
 

