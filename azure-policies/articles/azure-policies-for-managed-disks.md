# Azure Policies for Managed Disks

* [Introduction](#introduction)
* [Prerequisites](#prerequisites)

## Introduction
The goal of these solutions is to provide you a walkthrough to deploy Azure Policies in your subscription to audit and prevent the deployment of Virtual Machines and Virtual Machine Scale Sets not leveraging Managed Disks.

## Prerequisites
To complete this walkthrough, you will need:
* You must have access and be able to deploy into a Microsoft Azure Subscription
* Access to either the Azure PowerShell modules or the Azure CLI

## Create Azure Polices for Managed Disks with Azure PowerShell
1. Open a PowerShell session with the Azure PowerShell modules loaded.

2. Login to Azure and select the subscripton to create the policy.

```powershell
Login-AzureRmAccount

Select-AzureRmAccount -SubscrpitionId xxxxxx-xxxxxx-xxxxxx-xxxxxx
```

3. Define the variables to name the policy definition, the policy description, and the policy rule. The policy rule in this walkthrough is set to **deny** the creation of VMs and VM Scale Sets not leveraging managed disks. If you want to **audit** the creation of VMs and VM Scale Sets not leveraging managed disks, simply replace *deny* with *audit* in the policy definition.
```powershell
$policyName = "DenyUnmanagedDisks"
$policyDescription = "This policy will deny the creation of VMs and VMSSs that do not use naged disks"

$policyRule = '
{
  "if": {
    "anyOf": [
      {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Compute/virtualMachines"
          },
          {
            "field": "Microsoft.Compute/virtualMachines/osDisk.uri",
            "exists": "True"
          }
        ]
      },
      {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Compute/VirtualMachineScaleSets"
          },
          {
            "anyOf": [
              {
                "field": "Microsoft.Compute/VirtualMachineScaleSets/osDisk.vhdContainers",
                "exists": "True"
              },
              {
                "field": "Microsoft.Compute/VirtualMachineScaleSets/osdisk.imageUrl",
                "exists": "True"
              }
            ]
          }
        ]
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}'
```

4. Create the policy definition. This is only creating the definition of the policy and it is not being enforced.
```powershell
New-AzureRmPolicyDefinition -Name $policyName -Description $policyDescription -Policy $policyRule
```

5. Prepare variables to create a policy assignment where the scope is the entire subscription.
```powershell
$policyDefinition = Get-AzureRmPolicyDefinition -Name $policyName
$sub = "/subscriptions/" + (Get-AzureRmContext).Subscription.Id
$assignmentName = "DenyUnmanagedDisksAssignment"
```

6. Create the policy assignment. After this completes successfully, the policy will be enforced in the specified scope.
```powershell
New-AzureRmPolicyAssignment -Name $assignmentName -Scope $sub -PolicyDefinition $policyDefinition -Description $policyDescription
```

