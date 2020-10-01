
Write-Information "Empieza a las $(Get-Date)"
############ LOGIN ############
$tenantId = "tenantid"
$pass = "pass"
$appId = "app_id"
$suscription = "subscriptionid"

$password = ConvertTo-SecureString $pass -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential -ArgumentList ($appId, $password)
Connect-AzAccount -Credential $psCred -TenantId $tenantId -ServicePrincipal -SubscriptionId $suscription
$storagesToCopy = 'storage1','storage2','storage3'

# Lista todos los StorageAcounts a hacer backup
$storagesOrigen = Get-AzStorageAccount |
   Where-Object {$storagesToCopy -Contains $_.StorageAccountName} |
   Select-Object StorageAccountName,ResourceGroupName

############ DESCARGAMOS AZ COPY ############
Invoke-WebRequest -Uri https://aka.ms/downloadazcopy-v10-windows -OutFile .\azcopy.zip
Expand-Archive -Path .\azcopy.zip -DestinationPath .
cd .\azcopy_windows_amd64_10.6.0\

############ COPIAR UN CONTAINER ORIGEN EN UN CONTAINER/BLOB DESTINO ############
$env:AZCOPY_SPA_CLIENT_SECRET=$pass
.\azcoy login --service-principal --application-id $appId --tenant-id=$tenantId

$id=1
foreach ($storageActual in $storagesOrigen) {
   $origen="https://$($storageActual.StorageAccountName).blob.core.windows.net/"
   $destino="https://[storage_dest].blob.core.windows.net/$($storageActual.StorageAccountName)"

   # Fijar el storage account
   $key = Get-AzStorageAccountKey -ResourceGroupName $storageActual.ResourceGroupName -AccountName $storageActual.StorageAccountName
   $ctx = New-AzStorageContext -StorageAccountName $storageActual.StorageAccountName -StorageAccountKey $key[0].Value
   $sas = New-AzStorageAccountSASToken -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "racwdlup" -Context $ctx

   Write-Progress "Copiando storage $origen ($id de $($storagesOrigen.Length))"
   .\azcoy make $destino
   .\azcoy cp $($origen+$sas) $destino --log-level ERROR --recursive
   $id++
}

Write-Information "Termina OK a las $(Get-Date)"