<#
.SYNOPSIS
    Migrate-Image-From-Classic.ps1
.DESCRIPTION
    Migrates an image from the classic image store to RM
.PARAMETER ImageName
    Original image name
.PARAMETER TargetStorageAccount
    Target account to copy to
.PARAMETER TargetResourceGroup
    Resource group of the target storage account
.PARAMETER TargetContainer
    Target container to put the VHD
.PARAMETER TargetVirtualPath
    Virtual path to put the blob in.  If not specified, defaults to the virtual path of the source URI
.PARAMETER TargetBlobName
    Blob name to copy to.  If not specified, defaults to the blob name of the source URI
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$ImageName,
    [Parameter(Mandatory=$true)]
    [string]$TargetBlob,
    [Parameter(Mandatory=$true)]
    $TargetStorageAccount = $null
    [Parameter(Mandatory=$true)]
    [string]$TargetResourceGroup,
    [string]$TargetContainer = 'system',
    [Parameter(Mandatory=$true)]
    [string]$TargetVirtualPath = 'Microsoft.Compute/Images/custom'
)

# Ensure logged in
$ctx = Get-AzureRmContext
if (!$ctx) {
    Exit
}

# First find the VM image and determine what account it is in.
Write-Output "Looking up image $ImageName"
$image = Get-AzureVMImage $ImageName

if (!$image) {
    throw "Could not find $ImageName"
}

# Determine the current storage account location.
$vhdURI = $null
if ($image.MediaLink) {
    # Contains the media link URL in the image info, rather than the os disk config.  Parse this
    $vhdURI = $image.MediaLink
}
else {
    $vhdURI = $image.OSDiskConfiguration.MediaLink.AbsoluteUri
}

# Parse out the source URI info
$uriInfo = .\Parse-VHD-Uri.ps1 $vhdURI -ErrorAction Stop

$sourceStorageAccountName = $uriInfo.StorageAccount
$sourceStorageContainer = $uriInfo.ContainerName
$sourceStorageBlob = $uriInfo.Blob
$sourceStorageVirtualPath = $uriInfo.VirtualPath
                
Write-Output "Copy details:"
Write-Output "  Storage Account $sourceStorageAccountName -> $TargetStorageAccount"
Write-Output "  Container $sourceStorageContainer -> $TargetContainer"
if ($TargetVirtualPath -or $sourceStorageVirtualPath) {
    Write-Output "  Virtual Path $sourceStorageVirtualPath -> $TargetVirtualPath"
}
Write-Output "  Blob $sourceStorageBlob -> $TargetBlob"

# Validate that we got the storage account right
$storageAccount = Get-AzureStorageAccount $sourceStorageAccountName

if (!$storageAccount) {
    throw "Could not find storage account $sourceStorageAccountName"
}

# Generate the source and target contexts
$sourceKey = Get-AzureStorageKey -StorageAccountName $sourceStorageAccountName
$sourceContext = New-AzureStorageContext -StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceKey.Primary

# Grab the source blob
$sourceBlob = $null
if ($sourceStorageVirtualPath) {
    $sourceBlob = Get-AzureStorageBlob -Blob "$sourceStorageVirtualPath/$sourceStorageBlob" -Container $sourceStorageContainer -Context $sourceContext -ErrorAction SilentlyContinue
}
else {
    $sourceBlob = Get-AzureStorageBlob -Blob $sourceStorageBlob -Container $sourceStorageContainer -Context $sourceContext -ErrorAction SilentlyContinue
}
if (!$sourceBlob) {
    Write-Error "Could not locate source blob $sourceStorageBlob"
    Exit
}

if ($TargetVirtualPath) {
    $targetUri = "https://$TargetStorageAccount.blob.core.windows.net/$TargetContainer/$TargetVirtualPath/$TargetBlob"
}
else {
    $targetUri = "https://$TargetStorageAccount.blob.core.windows.net/$TargetContainer/$TargetBlob"
}

# Locate the storage account key for the target
$targetStorageAccountKeys = Get-AzureRmStorageAccountKey $TargetStorageAccount -ResourceGroupName $TargetResourceGroup -ErrorAction SilentlyContinue
if ($targetStorageAccountKeys) {
    if ($targetStorageAccountKeys[0]) {
        $targetStorageAccountKey = $targetStorageAccountKeys[0].Value
    }
    else {
        $targetStorageAccountKey = $targetStorageAccountKeys.Key1
    }
}
if (!$targetStorageAccountKey) {
    Write-Error "Could not find target storage account $TargetStorageAccount or locate the storage key, skipping"
    Exit
}

# Create a storage context for the target
$targetContext = New-AzureStorageContext -StorageAccountName $TargetStorageAccount -StorageAccountKey $targetStorageAccountKey

# Ensure that the container is created if not existing
$existingContainer = Get-AzureStorageContainer -Context $targetContext -Name $TargetContainer -ErrorAction SilentlyContinue

if (!$existingContainer) {
    Write-Output "Target storage container $TargetContainer doesn't exist, creating"
    New-AzureStorageContainer -Context $targetContext -Name $TargetContainer
}

$fullTargetBlobName = $TargetBlob
if ($TargetVirtualPath) {
    $fullTargetBlobName = "$TargetVirtualPath/$TargetBlob"
}

$blobCopy = Start-AzureStorageBlobCopy -CloudBlob $sourceBlob.ICloudBlob -Context $sourceContext -DestContext $targetContext -DestContainer $TargetContainer -DestBlob $fullTargetBlobName

Write-Output "Started $vhdURI -> $targetUri"

# Waiting till all copies done
$allFinished = $false
while (!$allFinished) {
    $allFinished = $true
    $blobCopyState = $blobCopy | Get-AzureStorageBlobCopyState
    if ($blobCopyState.Status -eq "Pending")
    {
        $allFinished = $false
        $percent = ($blobCopyState.BytesCopied * 100) / $blobCopyState.TotalBytes
        $percent = [math]::round($percent,2)
        $blobCopyName = $blobCopyState.CopyId
        Write-Progress -Id 0 -Activity "Copying from classic... " -PercentComplete $percent -CurrentOperation "Copying $blobCopyName"
    }
    Start-Sleep -s 30
}

Write-Output "All operations complete"