# Walkthrough: Generating Unmanaged Disks Report

## Table of Contents

* [Introduction](#introduction)
* [Learning objectives](#learning-objectives)
* [Prerequisites](#prerequisites)
* [Estimated time to complete this module](#estimated-time-to-complete-this-module)
* [Parameters](#parameters)
* [Generating the report](#generating-the-report)
* [Next steps](#nextsteps)

## Introduction

The purpose of this PowerShell script is to provide a detailed report as a CSV on unmanaged disk information. This is targeted to identify the provisioned and used disk space for all virtual machines using unmanaged disks. 

## Learning Objectives

After completing the exercises in this walkthrough, you will be able to view the provisioned and used disk space for all virtual machines using unmanaged disks

## Prerequisites

To genereate this report, you will need:
* You must have access to Microsoft Azure Subscription.
* It is recommended to run this script as Contributor or Owner of the subscription. At a minimum, Reader and Storage Contributor permissions for the subscription are required.
* Latest AzureRM PowerShell modules. They can be [downloaded here](https://www.powershellgallery.com/packages/AzureRM/).
* Download the PowerShell script [UnmanagedDisksReport.ps1](./UnmanagedDisksReport.ps1).

## Estimated Time to Complete this Module

The script runtime will vary based on the number of unmanaged disks in the subscription. 

## Parameters
**SubscriptionID** - Microsoft Azure Subscription ID to generate the report against

**ReportOutputFolder** - Output location for the generated CSV report 

**IncludePremium** - Enable the switch to include gathering details on Premium unmanaged disks

## Generating the Report

1. Open a PowerShell session with the Azure PowerShell modules loaded.
2. Note the parameters of the script, **SubscriptionId** and **ReportOutputFolder**.
    > Note: Substitute the placeholder in the code with your subscription ID.
```powershell
.\UnmanagedDisksReport.ps1 -SubscrpitionId xxxxxx-xxxxxx-xxxxxx-xxxxxx -ReportOutputFolder C:\UnmanagedDisksReport
```
3. The script will prompt to authenticate to Azure, set the context using the provided subscription ID, and iterate through each disk for each virtual machine using unmanaged disks. Below is an example of the standard output of the script.

```powershell
Script start

Successfully logged into Azure


Name             : <AzureSubscriptionName> - xxxxxx-xxxxxx-xxxxxx-xxxxxx
Account          : first.last@microsoft.com
SubscriptionName : <AzureSubscriptionName>
TenantId         : xxxxxx-xxxxxx-xxxxxx-xxxxxx
Environment      : AzureCloud

The subscription context is set to Subscription ID: xxxxxx-xxxxxx-xxxxxx-xxxxxx

Gathering virtual machine information...

Progress Status:
[<Current Number> of <Total Number of Unmanaged VMs>] <VM Name>

[1 of 9] centos
[2 of 9] centos2
[3 of 9] centosDemo
[4 of 9] centosDocker
[5 of 9] opensuse
[6 of 9] opensuse2
[7 of 9] ubuntu
[8 of 9] ubuntu2
[9 of 9] Centos-ARMTemplate1

Exported unmanaged disk report at C:\Users\jabec\Desktop\ReportingResults\UnmanagedDisksResults-201806181524.csv

Script end
```

4. Below is a sample of the CSV output from the script. 

VmName| VmResourceGroup| Location| AvailabilitySet| VhdUri| StorageType (Standard/Premium)| DiskType (OS/Data)| ProvisionedSizeInGb| UsedSizeInGb| UsedDiskPercentage
|---|---|---|---|---|---|---|---|---|---|
centos|77488-OMS|eastus2|CENTOS-AVSET|https://77488oms5025.blob.core.windows.net/vhds/centos2016619201023.vhd|Standard|OS|30|2|0.06
centos2|77488-OMS|eastus2|CENTOS-AVSET|https://77488oms5025.blob.core.windows.net/vhds/centos22016615161542.vhd|Standard|OS|30|2|0.08
centosDemo|77488-OMS|eastus2|CENTOS-AVSET|https://4zrgvjrvxqy7wstandardsa.blob.core.windows.net/vhds/centosDemo20166208242.vhd|Standard|OS|30|2|0.05
centosDocker|77488-OMS|eastus2|CENTOS-AVSET|https://4zrgvjrvxqy7wstandardsa.blob.core.windows.net/vhds/centosDocker201662085852.vhd|Standard|OS|30|8|0.28
opensuse|77488-OMS|eastus2||https://77488oms5025.blob.core.windows.net/vhds/opensuse2016619201619.vhd|Standard|OS|30|2|0.07
opensuse2|77488-OMS|eastus2||https://77488oms5025.blob.core.windows.net/vhds/opensuse22016617124627.vhd|Standard|OS|30|7|0.23
ubuntu|77488-OMS|eastus2|UBUNTU-AVSET|https://77488oms5025.blob.core.windows.net/vhds/ubuntu201661371038.vhd|Standard|OS|29|3|0.09
ubuntu2|77488-OMS|eastus2|UBUNTU-AVSET|https://77488oms5025.blob.core.windows.net/vhds/ubuntu3201661923286.vhd|Standard|OS|29|20|0.69
Centos-ARMTemplate1|CUSTOMIMAGES-RG1|eastus2||http://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate1osDisk.vhd|Standard|OS|30|11|0.36
Centos-ARMTemplate1|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate1data.vhd|Standard|Data|30|3|0.11
Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||http://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2osDisk.vhd|Standard|OS|30|3|0.11
Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2data.vhd|Standard|Data|128|54|0.42
Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2wsb.vhd|Standard|Data|128|77|0.6

# Next Steps

The report can then be used in conjunction with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) to perform any cost analysis.