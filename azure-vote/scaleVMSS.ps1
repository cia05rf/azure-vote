<#
    .DESCRIPTION
        A runbook that will scale up the Virtual Machine Scale Set instances

    .NOTES
        AUTHOR: Azure Compute Team
        LAST EDIT: March 27, 2019
#>

param (
	[parameter(Mandatory = $false)]
    [object]$WebhookData,
    
	[parameter(Mandatory = $false)]
    [string]$ScaleType="up"
)

if ($WebhookData -ne $null) {  
	
    # Allow to testing from pane
    try
    {
        if (-Not $WebhookData.RequestBody){
            $WebhookData = (ConvertFrom-Json -InputObject $WebhookData)
        }
    }
    catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
	
	# Collect properties of WebhookData.
	$WebhookBody    =   $WebhookData.RequestBody
    
	# Obtain the WebhookBody containing the AlertContext
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookBody)
    Write-Output "WebhookBody $WebhookBody"
    Write-Output "WebhookBody.status $($WebhookBody.status)"

	
	if ($WebhookBody.status -eq "Activated") {
		
		$connectionName = "AzureRunAsConnection"
		try
		{
		    # Get the connection "AzureRunAsConnection"
		    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
		
		    "Logging in to Azure..."
            Write-Output "TenantId $($servicePrincipalConnection.TenantId)"
            Write-Output "ApplicationId $($servicePrincipalConnection.ApplicationId)"
            Write-Output "CertificateThumbprint $($servicePrincipalConnection.CertificateThumbprint)"
		    Add-AzureRmAccount `
		        -ServicePrincipal `
		        -TenantId $servicePrincipalConnection.TenantId `
		        -ApplicationId $servicePrincipalConnection.ApplicationId `
		        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
		}
		catch {
		    if (!$servicePrincipalConnection)
		    {
		        $ErrorMessage = "Connection $connectionName not found."
		        throw $ErrorMessage
		    } else{
		        Write-Error -Message $_.Exception
		        throw $_.Exception
		    }
		}
		
		# Obtain the AlertContext
		$AlertContext = [object]$WebhookBody.context
		
		$ResourceGroupName = $AlertContext.resourceGroupName
		$VmssName = $AlertContext.resourceName
		
		$noResize = "noresize"
		
		$scaleUp = @{ 
            # B-Series 
            "Standard_B1ls"    = "Standard_B1s" 
            "Standard_B1s"     = "Standard_B2s" 
            "Standard_B2s"     = $noResize
            "Standard_B1ms"    = "Standard_B2ms" 
            "Standard_B2ms"    = "Standard_B4ms" 
            "Standard_B4ms"    = "Standard_B8ms"
            "Standard_B8ms"    = $noResize      
        } 
		
		$scaleDown = @{ 
            # B-Series 
            "Standard_B1ls"    = $noResize 
            "Standard_B1s"     = "Standard_B1ls" 
            "Standard_B2s"     = "Standard_B1s"
            "Standard_B1ms"    = $noResize
            "Standard_B2ms"    = "Standard_B1ms" 
            "Standard_B4ms"    = "Standard_B2ms"
            "Standard_B8ms"    = "Standard_B4ms"
        } 
		
		try {
            Write-Output "$ResourceGroupName -> $VmssName"
		    $vmss = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName -ErrorAction Stop
		} catch {
		    Write-Error "Virtual Machine Scale Set not found"
            Write-Error -Message $_.Exception
            throw $_.Exception
		    exit
		}
		
		$currentVmssSize = $vmss.Sku.Name
		
		Write-Output "`nFound the specified Virtual Machine Scale Set: $VmssName"
		Write-Output "Current size: $currentVmssSize"
		Write-Output "Scale type: $ScaleType"
		
		$newVmssSize = ""
		if($ScaleType -eq "up"){
            $newVmssSize = $scaleUp[$currentVmssSize]
        }elseif($ScaleType -eq "down"){
            $newVmssSize = $scaleDown[$currentVmssSize]
        }else{
            $ErrorMessage = "ScaleType must be 'up' or 'down', '$ScaleType' given"
            throw $ErrorMessage
        }
		Write-Output "New size: $newVmssSize"
		
		if($newVmssSize -eq $noResize -or [string]::IsNullOrEmpty($newVmssSize)) {
		    Write-Output "Sorry the current Virtual Machine Scale Set size $currentVmssSize can't be scaled $ScaleType to $newVmssSize. You'll need to recreate the specified Virtual Machine Scale Set with your requested size"
		} else {
		    Write-Output "`nNew size will be: $newVmssSize"

			$vmss.Sku.Name = $newVmssSize
		    Update-AzureRmVmss -ResourceGroupName $ResourceGroupName -Name $VmssName -VirtualMachineScaleSet $vmss
			Update-AzureRmVmssInstance -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName -InstanceId "*"
				
		    $updatedVmss = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VmssName
		    $updatedVmssSize = $updatedVmss.Sku.Name

		    Write-Output "`nSize updated to: $updatedVmssSize"
		}
	} else {
		Write-Output "`nAlert not activated"
		exit
	}
}
else 
{
    Write-Error "This runbook is meant to only be started from a webhook." 
}