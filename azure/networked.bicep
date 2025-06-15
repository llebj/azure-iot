param location string = resourceGroup().location

param frontEndFunctionAppName string = 'fe-func-${uniqueString(resourceGroup().id)}'
param backEndFunctionAppName string = 'be-func-${uniqueString(resourceGroup().id)}'
param serverFarmName string = 'asp-${uniqueString(resourceGroup().id)}'
param functionStorageAccountName string = 'st${uniqueString(resourceGroup().id)}'
param vnetName string = 'vnet-${uniqueString(resourceGroup().id)}'
param frontEndFunctionSubnetName string = 'fe-sn'
param backEndFunctionSubnetName string = 'be-sn'
param applicationInsightsName string = 'appi-${uniqueString(resourceGroup().id)}'

param vnetAddressPrefix string = '10.100.0.0/16'
param frontEndFunctionSubnetAddressPrefix string = '10.100.0.0/24'
param backEndFunctionSubnetAddressPrefix string = '10.100.1.0/24'

var queueDefinitionName string = 'readings'
var tableDefinitionName string = 'readings'
var frontEndFunctionAppStorageContainerName string = 'app-package-${frontEndFunctionAppName}'
var frontEndFunctionAppStorageEndpoint string = 'https://${functionStorageAccountName}.blob.${environment().suffixes.storage}/${frontEndFunctionAppStorageContainerName}'
var backEndFunctionAppStorageContainerName string = 'app-package-${backEndFunctionAppName}'
var backEndFunctionAppStorageEndpoint string = 'https://${functionStorageAccountName}.blob.${environment().suffixes.storage}/${backEndFunctionAppStorageContainerName}'

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
        name: frontEndFunctionSubnetName
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
          addressPrefix: frontEndFunctionSubnetAddressPrefix
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
        name: backEndFunctionSubnetName
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
          addressPrefix: backEndFunctionSubnetAddressPrefix
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
      bypass: 'None'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, frontEndFunctionSubnetName)
          action: 'Allow'
          state: 'Succeeded'
        }
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, backEndFunctionSubnetName)
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

resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: serverFarmName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
    size: 'FC1'
    family: 'FC'
    capacity: 0
  }
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 4
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }
}

resource frontEndFunctionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: frontEndFunctionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarm.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: frontEndFunctionAppStorageEndpoint
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
    }
    siteConfig: {
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsight.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: functionStorageAccountName
        }
        {
          name: 'Storage_Uri'
          value: '${functionStorageAccount.properties.primaryEndpoints.queue}${queueDefinitionName}'
        }
      ]
    }
  }
}

resource frontEndNetworkConfig 'Microsoft.Web/sites/networkConfig@2024-11-01' = {
  parent: frontEndFunctionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, frontEndFunctionSubnetName)
    swiftSupported: true
  }
  dependsOn: [
    vnet
  ]
}

resource backEndFunctionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: backEndFunctionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: serverFarm.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: backEndFunctionAppStorageEndpoint
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
    }
    siteConfig: {
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsight.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: functionStorageAccountName
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: functionStorageAccount.properties.primaryEndpoints.queue
        }
        {
          name: 'Storage_Uri'
          value: functionStorageAccount.properties.primaryEndpoints.table
        }
        {
          name: 'Storage_TableName'
          value: tableDefinitionName
        }
      ]
    }
  }
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2024-11-01' = {
  parent: backEndFunctionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, backEndFunctionSubnetName)
    swiftSupported: true
  }
  dependsOn: [
    vnet
  ]
}

// Storage Blob Data Contributor 
resource blobContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource frontEndBlobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: functionStorageAccount
  name: guid(functionStorageAccount.id, frontEndFunctionApp.id, blobContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: blobContributorRoleDefinition.id
    principalId: frontEndFunctionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource backEndBlobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: functionStorageAccount
  name: guid(functionStorageAccount.id, backEndFunctionApp.id, blobContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: blobContributorRoleDefinition.id
    principalId: backEndFunctionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Queue Data Contributor 
resource queueContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
}

resource queueContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: functionStorageAccount
  name: guid(functionStorageAccount.id, frontEndFunctionApp.id, queueContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: queueContributorRoleDefinition.id
    principalId: frontEndFunctionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource backEndQueueProcessorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: functionStorageAccount
  name: guid(functionStorageAccount.id, backEndFunctionApp.id, queueContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: queueContributorRoleDefinition.id
    principalId: backEndFunctionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Table Data Contributor 
resource tableContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
}

resource tableContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: functionStorageAccount
  name: guid(functionStorageAccount.id, backEndFunctionApp.id, tableContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: tableContributorRoleDefinition.id
    principalId: backEndFunctionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
