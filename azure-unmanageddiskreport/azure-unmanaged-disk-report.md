# Walkthrough: Generating Unmanaged Disks Report

## Table of Contents

* [Introduction](#introduction)
* [Learning objectives](#learning-objectives)
* [Prerequisites](#prerequisites)
* [Estimated time to complete this module](#estimated-time-to-complete-this-module)
* [Parameters](#parameters)
* [Generating the report](#generating-the-report)
* [Next steps](#next-steps)

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
**SubscriptionIDs** -  Array of Azure subscription IDs to report on unmanaged ARM virtual machine disks

**ReportOutputFolder** - Output location for the generated CSV report 

**IncludePremium** - (Optional) Enable the switch to include gathering details on Premium unmanaged disks

## Generating the Report

1. Open a PowerShell session with the Azure PowerShell modules loaded.
2. Note the parameters of the script, **SubscriptionIds** and **ReportOutputFolder**.
    > Note: Substitute the placeholder in the code with your subscription ID.
```powershell
# Run the script against 1 (one) subscription:
.\UnmanagedDisksReport.ps1 -SubscriptionIDs @("xxxxx-xxxxxx-xxxxxxx-xxxxx") -ReportOutputFolder "C:\ScriptReports\"

# Run the script against more than 1 (one) subscription and include premium:
.\UnmanagedDisksReport.ps1 -SubscriptionIDs @("xxxxx-xxxxxx-xxxxxxx-xxxxx", "xxxxx-xxxxxx-xxxxxxx-xxxxx") -ReportOutputFolder "C:\ScriptReports\" -IncludePremium

# Run the script against all subscriptions the account has access to:
Login-AzureRmAccount
$subIDs = Get-AzureRmSubscription | Select -ExpandProperty Id
.\UnmanagedDisksReport.ps1 -SubscriptionIDs $subIDs -ReportOutputFolder "C:\ScriptReports\"
```
3. The script will prompt to authenticate to Azure, set the context using the provided subscription ID, and iterate through each disk for each virtual machine using unmanaged disks. Below is an example of the standard output of the script.

```powershell
Script start

Successfully logged into Azure

Gathering virtual machine information...

The subscription context is set to: Production Subscription - xxxxx-xxxxxx-xxxxxxx-xxxxx

Progress Status:
[<Current Number> of <Total Number of Unmanaged VMs>] <VM Name>

[1 of 6] centos
[2 of 6] centos2
[3 of 6] centosDemo
[4 of 6] centosDocker
[5 of 6] opensuse
[6 of 6] opensuse2

The subscription context is set to: Nonproduction Subscription - xxxxx-xxxxxx-xxxxxxx-yyyyy

Progress Status:
[<Current Number> of <Total Number of Unmanaged VMs>] <VM Name>

[1 of 3] ubuntu
[2 of 3] ubuntu2
[3 of 3] Centos-ARMTemplate1

Exported unmanaged disk report at C:\ReportingResults\UnmanagedDisksResults-201808181524.csv

Script end
```

4. Below is a sample of the CSV output from the script. 

SubscriptionName | SubscriptionID | VmName| VmResourceGroup| Location| AvailabilitySet| VhdUri| StorageType (Standard/Premium)| DiskType (OS/Data)| ProvisionedSizeInGb| UsedSizeInGb| UsedDiskPercentage
|---|---|---|---|---|---|---|---|---|---|---|---|
Production Subscription|xxxxx-xxxxxx-xxxxxxx-xxxxx|centos|77488-OMS|eastus2|CENTOS-AVSET|https://77488oms5025.blob.core.windows.net/vhds/centos2016619201023.vhd|Standard|OS|30|2|0.06
Production Subscription|xxxxx-xxxxxx-xxxxxxx-xxxxx|centos2|77488-OMS|eastus2|CENTOS-AVSET|https://77488oms5025.blob.core.windows.net/vhds/centos22016615161542.vhd|Standard|OS|30|2|0.08
Production Subscription|xxxxx-xxxxxx-xxxxxxx-xxxxx|centosDemo|77488-OMS|eastus2|CENTOS-AVSET|https://4zrgvjrvxqy7wstandardsa.blob.core.windows.net/vhds/centosDemo20166208242.vhd|Standard|OS|30|2|0.05
Production Subscription|xxxxx-xxxxxx-xxxxxxx-xxxxx|centosDocker|77488-OMS|eastus2|CENTOS-AVSET|https://4zrgvjrvxqy7wstandardsa.blob.core.windows.net/vhds/centosDocker201662085852.vhd|Standard|OS|30|8|0.28
Production Subscription|xxxxx-xxxxxx-xxxxxxx-xxxxx|opensuse|77488-OMS|eastus2||https://77488oms5025.blob.core.windows.net/vhds/opensuse2016619201619.vhd|Standard|OS|30|2|0.07
Production Subscription|xxxxx-xxxxxx-xxxxxxx-xxxxx|opensuse2|77488-OMS|eastus2||https://77488oms5025.blob.core.windows.net/vhds/opensuse22016617124627.vhd|Standard|OS|30|7|0.23
Nonproduction Subscription|xxxxx-xxxxxx-xxxxxxx-yyyyy|ubuntu|77488-OMS|eastus2|UBUNTU-AVSET|https://77488oms5025.blob.core.windows.net/vhds/ubuntu201661371038.vhd|Standard|OS|29|3|0.09
Nonproduction Subscription|xxxxx-xxxxxx-xxxxxxx-yyyyy|ubuntu2|77488-OMS|eastus2|UBUNTU-AVSET|https://77488oms5025.blob.core.windows.net/vhds/ubuntu3201661923286.vhd|Standard|OS|29|20|0.69
Nonproduction Subscription|xxxxx-xxxxxx-xxxxxxx-yyyyy|Centos-ARMTemplate1|CUSTOMIMAGES-RG1|eastus2||http://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate1osDisk.vhd|Standard|OS|30|11|0.36
Nonproduction Subscription|xxxxx-xxxxxx-xxxxxxx-yyyyy|Centos-ARMTemplate1|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate1data.vhd|Standard|Data|30|3|0.11
Nonproduction Subscription|xxxxx-xxxxxx-xxxxxxx-yyyyy|Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||http://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2osDisk.vhd|Standard|OS|30|3|0.11
Nonproduction Subscription|xxxxx-xxxxxx-xxxxxxx-yyyyy|Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2data.vhd|Standard|Data|128|54|0.42
Nonproduction Subscription|xxxxx-xxxxxx-xxxxxxx-yyyyy|Centos-ARMTemplate2|CUSTOMIMAGES-RG1|eastus2||https://storcustomimages.blob.core.windows.net/vhds/Centos-ARMTemplate2wsb.vhd|Standard|Data|128|77|0.6

# Next Steps

The report can then be used in conjunction with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) to perform any cost analysis.