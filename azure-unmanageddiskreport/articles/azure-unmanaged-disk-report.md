# Azure Unmanaged Disks Report Script

* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Parameters](#parameters)
* [Output](#output)
* [Generating the Report](#generating-the-report)

## Introduction
The purpose of this script is to provide a detailed report as a CSV on unmanaged disk information. This is targeted to identify the provisioned and used disk space for all virtual machines using unmanaged disks. 

## Prerequisites
To genereate this report, you will need:
* Download the [UnmanagedDisksReport.ps1](./UnmanagedDisksReport.ps1).
* You must have access to Microsoft Azure Subscription.
* It is recommended to run this script as Contributor or Owner of the subscription. At a minimum, Reader and Storage Contributor permissions for the subscription are required.
* Access to either the latest Azure PowerShell modules. They can be [downloaded here](https://www.powershellgallery.com/packages/AzureRM/).

## Paramaters
**SubscriptionID** - Microsoft Azure Subscription ID to generate the report against
**ReportOutputFolder** - Output location for the generated CSV report 
 
 ## Output
 The script will generate a CSV file to easily view the detailed unmanaged disk information. The table below is an example report and this [can be downloaded as a CSV](./VMUnmanagedDisk-201802091328.csv).

VmName| VmResourceGroup| Location| AvailabilitySet| VhdUri| StorageType (Standard/Premium)| DiskType (OS/Data)| ProvisionedSizeInGb| UsedSizeInGb| UsedDiskPercentage
|---|---|---|---|---|---|---|---|---|---|
OMScentos|77488-OMS|eastus2|CENTOS-AVSET|https://77488oms5025.blob.core.windows.net/vhds/OMScentos2016619201023.vhd|Standard|OS|30|2|0.06
OMScentos2|77488-OMS|eastus2|CENTOS-AVSET|https://77488oms5025.blob.core.windows.net/vhds/OMScentos22016615161542.vhd|Standard|OS|30|2|0.08
OMScentosDemo|77488-OMS|eastus2|CENTOS-AVSET|https://4zrgvjrvxqy7wstandardsa.blob.core.windows.net/vhds/OMScentosDemo20166208242.vhd|Standard|OS|30|2|0.05
OMScentosDocker|77488-OMS|eastus2|CENTOS-AVSET|https://4zrgvjrvxqy7wstandardsa.blob.core.windows.net/vhds/OMScentosDocker201662085852.vhd|Standard|OS|30|8|0.28
OMSopensuse|77488-OMS|eastus2||https://77488oms5025.blob.core.windows.net/vhds/OMSopensuse2016619201619.vhd|Standard|OS|30|2|0.07
OMSopensuse2|77488-OMS|eastus2||https://77488oms5025.blob.core.windows.net/vhds/OMSopensuse22016617124627.vhd|Standard|OS|30|7|0.23
OMSubuntu|77488-OMS|eastus2|UBUNTU-AVSET|https://77488oms5025.blob.core.windows.net/vhds/OMSubuntu201661371038.vhd|Standard|OS|29|3|0.09
OMSubuntu2|77488-OMS|eastus2|UBUNTU-AVSET|https://77488oms5025.blob.core.windows.net/vhds/OMSubuntu3201661923286.vhd|Standard|OS|29|29|0.99
Centos-ARMTemplate1|CUSTOMIMAGES-RG1|eastus2||http://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate1osDisk.vhd|Standard|OS|30|11|0.36
Centos-ARMTemplate1|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate1data.vhd|Standard|Data|30|3|0.11
Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||http://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2osDisk.vhd|Standard|OS|30|3|0.11
Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2data.vhd|Standard|Data|30|5|0.16
Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2wsb.vhd|Standard|Data|30|10|0.33


##  Generating the Report
1. Open a PowerShell session with the Azure PowerShell modules loaded.

2. Note the parameters of the script, **SubscriptionId** and **ReportOutputFolder**.
    > Note: Substitute the placeholder in the code with your subscription ID.
```powershell
.\UnmanagedDisksReport.ps1 -SubscrpitionId xxxxxx-xxxxxx-xxxxxx-xxxxxx -ReportOutputFolder C:\UnmanagedDisksReport
```
3. The script will prompt to authenticate to Azure, set the context using the provided subscription ID, and iterate through each disk for each virtual machine using unmanaged disks. Below is an example of the standard output of the script and there is a CSV example above.
    >Note: The script will print each virtual machine name, managed and unmanaged, to illustrate progress but only virtual machines with unmanaged disks will be reported.
```powershell
Script start

Successfully logged into Azure

Name             : [email@microsoft.com, xxxxxx-xxxxxx-xxxxxx-xxxxxx]
Account          : email@microsoft.com
SubscriptionName : SubscriptionName
TenantId         : xxxxxx-xxxxxx-xxxxxx-xxxxxx
Environment      : AzureCloud

The subscription context is set to Subscription ID: xxxxxx-xxxxxx-xxxxxx-xxxxxx

Gathering virtual machine information...

Progress Status:
[<Current Number> of <Total Number of VMs>] <VM Name>

[1 of 24] MyUbuntuVM
[2 of 24] OMScentos
[3 of 24] OMScentos2
[4 of 24] OMScentosDemo
[5 of 24] OMScentosDocker
[6 of 24] OMSopensuse
[7 of 24] OMSopensuse2
[8 of 24] OMSubuntu
[9 of 24] OMSubuntu2
[10 of 24] OMSubuntu3
[11 of 24] OMSubuntuDemo
[12 of 24] Centos-ARMTemplate1
[13 of 24] Centos-ARMTemplate2
[14 of 24] Centos-ARMTemplate5
[15 of 24] Centos-CLI1
[16 of 24] Centos-CLI2
[17 of 24] Centos-Cli6
[18 of 24] Centos-CLI7
[19 of 24] Centos-PS
[20 of 24] Centos-PS1
[21 of 24] DockerVM01
[22 of 24] DSC-CentOS67-1
[23 of 24] DSC-CentOS71-1
[24 of 24] DSC-PullServer

Exported unmanaged disk report at C:\UnmanagedDisksReport\VMUnmanagedDisk-201802140734.csv

Script end
```