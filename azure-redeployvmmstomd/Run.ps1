
# Deploy VMSS from custom image to existing subnet
$Templatepath= "C:\Users\mahernan\OneDrive - Microsoft\Desktop\ManagedDisksVMSS\Custom Image\azuredeploy-custommanagedvmss.json"
$ParamTemplatepath= "C:\Users\mahernan\OneDrive - Microsoft\Desktop\ManagedDisksVMSS\Custom Image\azuredeploy-custommanagedvmss.parameters.json"
$RGName = "vmsststrg01"

#New-AzureRmResourceGroup -Name $RGName -Location "southcentralus"
Test-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -Mode Incremental -TemplateParameterFile $ParamTemplatepath -TemplateFile $Templatepath -Debug -Verbose
New-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -Mode Incremental -TemplateParameterFile $ParamTemplatepath -TemplateFile $Templatepath -Debug -Verbose

# Deploy VMSS with post-prov. to existing subnet
$Templatepath= "C:\Users\mahernan\OneDrive - Microsoft\Desktop\ManagedDisksVMSS\Post-Provisioning Config\azuredeploy-managedvmss.json"
$ParamTemplatepath= "C:\Users\mahernan\OneDrive - Microsoft\Desktop\ManagedDisksVMSS\Post-Provisioning Config\azuredeploy-managedvmss.parameters.json"
$RGName = "vmsststrg04"

New-AzureRmResourceGroup -Name $RGName -Location "southcentralus"
Test-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -Mode Incremental -TemplateParameterFile $ParamTemplatepath -TemplateFile $Templatepath -Debug -Verbose
New-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -Mode Incremental -TemplateParameterFile $ParamTemplatepath -TemplateFile $Templatepath -Debug -Verbose