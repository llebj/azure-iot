param location string = resourceGroup().location

param frontEndFunctionAppName string = 'fe-func-${uniqueString(resourceGroup().id)}'
param backEndFunctionAppName string = 'be-func-${uniqueString(resourceGroup().id)}'
param functionStorageAccountName string = 'st${uniqueString(resourceGroup().id)}'
param vnetName string = 'vnet-${uniqueString(resourceGroup().id)}'

param vnetAddressPrefix string = '10.100.0.0/16'

var queueDefinitionName string = 'readings'
var tableDefinitionName string = 'readings'
var frontEndFunctionAppStorageContainerName string = 'app-package-${frontEndFunctionAppName}'
var backEndFunctionAppStorageContainerName string = 'app-package-${backEndFunctionAppName}'

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: functionStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
  dependsOn: [
    vnet
  ]
}

resource functionStorageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: functionStorageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
}

resource frontEndFunctionStorageBlobStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: functionStorageBlobService
  name: frontEndFunctionAppStorageContainerName
  properties: {}
}

resource backEndFunctionStorageBlobStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: functionStorageBlobService
  name: backEndFunctionAppStorageContainerName
  properties: {}
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' = {
  parent: functionStorageAccount
  name: 'default'
}

resource queueDefinition 'Microsoft.Storage/storageAccounts/queueServices/queues@2024-01-01' = {
  parent: queueService
  name: queueDefinitionName
  properties: {}
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = {
  parent: functionStorageAccount
  name: 'default'
}

resource tableDefinition 'Microsoft.Storage/storageAccounts/tableServices/tables@2024-01-01' = {
  parent: tableService
  name: tableDefinitionName
  properties: {}
}
