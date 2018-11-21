[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Resource Group Location")] [string] $location,
    [Parameter(Mandatory = $true, HelpMessage = "Resource Group Name")]  [string] $resourceGroupName,
    [Parameter(Mandatory = $true, HelpMessage = "Storage Account Name")]  [string] $storageAccount,
    [Parameter(Mandatory = $true, HelpMessage = "Azure Function name")]  [string] $functionAppName,
    [Parameter(Mandatory = $true, HelpMessage = "Path proxies.json file")]  [string] $proxesfilePath
)

#Login
Login-AzureRmAccount

#Create Resource Group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location -force

#Create Storage Account
New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccount -Location $location -SkuName "Standard_LRS"

#Create Azure Function
New-AzureRmResource -ResourceType 'Microsoft.Web/Sites' `
    -ResourceName $functionAppName -kind 'functionapp' `
    -Location $location -ResourceGroupName $resourceGroupName `
    -Properties @{} -force

#Get Azure function app credential.
$credentials = Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Web/Sites/config" `
    -ResourceName $functionAppName/publishingcredentials -Action list -ApiVersion 2015-08-01 -Force
$username = $credentials.Properties.PublishingUserName
$password = $credentials.Properties.PublishingPassword 

#Create temp zip file
Compress-Archive "$proxesfilePath\proxies.json" -DestinationPath "proxies.zip"

#Deploy proxies.json file zip format
$apiUrl = "https://$functionAppName.scm.azurewebsites.net/api/zipdeploy"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
$userAgent = "powershell/1.0"
Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)} `
    -UserAgent $userAgent -Method POST -InFile "proxies.zip" -ContentType "multipart/form-data"

#Remove Zip file
Remove-Item -Path "proxies.zip"