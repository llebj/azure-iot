param location string = resourceGroup().location
param vnetAddressPrefix string = '10.100.0.0/16'
param frontendSubnetAddressPrefix string = '10.100.1.0/24'
param backendSubnetAddressPrefix string = '10.100.2.0/24'

var uniqueSuffix = uniqueString(resourceGroup().id)
var vnetName = 'vnet-${uniqueSuffix}'
var frontEndSubnetName = 'snet-frontend'
var backEndSubnetName = 'snet-backend'
var functionStorageAccountName = 'st${uniqueSuffix}'
var applicationInsightsName = 'appi-${uniqueSuffix}'
var frontEndFunctionAppName = 'func-frontend-${uniqueSuffix}'
var backEndFunctionAppName = 'func-backend-${uniqueSuffix}'

var queueDefinitionName = 'readings'
var tableDefinitionName = 'readings'
var storageServiceName = 'default'

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: frontEndSubnetName
        properties: {
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          addressPrefix: frontendSubnetAddressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
        }
      }
      {
        name: backEndSubnetName
        properties: {
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          addressPrefix: backendSubnetAddressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
        }
      }
    ]
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
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, frontEndSubnetName)
          action: 'Allow'
          state: 'Succeeded'
        }
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, backEndSubnetName)
          action: 'Allow'
          state: 'Succeeded'
        }
      ]
    }
  }
  dependsOn: [
    vnet
  ]
}

resource functionStorageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: functionStorageAccount
  name: storageServiceName
  properties: {
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' = {
  parent: functionStorageAccount
  name: storageServiceName
}

resource queueDefinition 'Microsoft.Storage/storageAccounts/queueServices/queues@2024-01-01' = {
  parent: queueService
  name: queueDefinitionName
  properties: {}
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = {
  parent: functionStorageAccount
  name: storageServiceName
}

resource tableDefinition 'Microsoft.Storage/storageAccounts/tableServices/tables@2024-01-01' = {
  parent: tableService
  name: tableDefinitionName
  properties: {}
}

resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

module frontendModule '../modules/frontend.bicep' = {
  name: 'frontend-deployment'
  params: {
    location: location
    functionAppName: frontEndFunctionAppName
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, frontEndSubnetName)
    storageAccountName: functionStorageAccountName
    storageAccountId: functionStorageAccount.id
    storageServiceName: storageServiceName
    queueName: queueDefinitionName
    applicationInsightsConnectionString: applicationInsight.properties.ConnectionString
  }
  dependsOn: [
    functionStorageBlobService
    vnet
  ]
}

module backendModule '../modules/backend.bicep' = {
  name: 'backend-deployment'
  params: {
    location: location
    functionAppName: backEndFunctionAppName
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, backEndSubnetName)
    storageAccountName: functionStorageAccountName
    storageAccountId: functionStorageAccount.id
    storageServiceName: storageServiceName
    tableName: tableDefinitionName
    applicationInsightsConnectionString: applicationInsight.properties.ConnectionString
  }
  dependsOn: [
    functionStorageBlobService
    vnet
  ]
}
