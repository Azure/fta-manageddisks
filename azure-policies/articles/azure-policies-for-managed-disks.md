# Azure Policies for Managed Disks

* [Introduction](#introduction)
* [Prerequisites](#prerequisites)
* [Create Azure Policies for Managed Disks with Azure PowerShell](#create-azure-policies-for-managed-disks-with-azure-powershell)
* [Removing Azure Policies with PowerShell](#removing-azure-policies-with-powershell)
* [Create Azure Policies for Managed Disks with the Azure CLI](#create-azure-policies-for-managed-disks-with-the-azure-cli)
* [Removing Azure Policies with the Azure CLI](#removing-azure-policies-with-the-azure-cli)

## Introduction
The goal of these solutions is to provide you a walkthrough to deploy Azure Policies in your subscription to audit and prevent the deployment of Virtual Machines and Virtual Machine Scale Sets not leveraging Managed Disks.

## Prerequisites
To complete this walkthrough, you will need:
* You must have access and be able to deploy into a Microsoft Azure Subscription
* Access to either the Azure PowerShell modules or the Azure CLI

##  Create Azure Policies for Managed Disks with Azure PowerShell
1. Open a PowerShell session with the Azure PowerShell modules loaded.

2. Login to Azure and select the subscripton to create the policy.
    > Note: Substitute the placeholder in the code with your subscription ID.
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

## Removing Azure Policies with PowerShell
7. Remove the policy assignment. This will stop the enforcement of the policy but it will not remove the policy definition from the subscription. 
```powershell
Remove-AzureRmPolicyAssignment -Name $assignmentName -Scope $sub
```

8. Remove the policy definition. A policy definition can only be removed after all assignments of the definition have been removed.
```powershell
Remove-AzureRmPolicyDefinition -Name $policyName
```

## Create Azure Policies for Managed Disks with the Azure CLI
1. Open a command line session where the Azure CLI has been installed.

2. Login to Azure and select the subscripton to create the policy.

```azurecli
az login

az account set -s xxxxxx-xxxxxx-xxxxxx-xxxxxx
```

3. Create the policy definition with name the policy definition, the policy description, and the policy rule included. The policy rule in this walkthrough is set to **deny** the creation of VMs and VM Scale Sets not leveraging managed disks. If you want to **audit** the creation of VMs and VM Scale Sets not leveraging managed disks, simply replace *deny* with *audit* in the policy definition.
```azurecli
az policy definition create --name DenyUnmanagedDisks --description "This policy will deny the creation of VMs and VMSSs that do not use managed disks" --rules '
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

4. Create the policy assignment. After this completes successfully, the policy will be enforced in the specified scope.
    > Note: Substitute `{subscription_id}` in the code with your subscription ID.
```azurecli
az policy assignment create --name DenyUnmanagedDisksAssignment --policy DenyUnmanagedDisks --scope /subscriptions/{subscription_id}
```

5. View the policy assignment.
```azurecli
az policy assignment show --name DenyUnmanagedDisksAssignment
```

## Removing Azure Policies with the Azure CLI
6. Remove the policy assignment. This will stop the enforcement of the policy but it will not remove the policy definition from the subscription. 
```azurecli
az policy assignment delete --name DenyUnmanagedDisksAssignment
```

7. Remove the policy definition. A policy definition can only be removed after all assignments of the definition have been removed.
```azurecli
az policy definition delete --name DenyUnmanagedDisksAssignment
```
