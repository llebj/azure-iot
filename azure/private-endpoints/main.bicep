param location string = resourceGroup().location
param vnetAddressPrefix string = '10.100.0.0/16'
param frontendSubnetAddressPrefix string = '10.100.1.0/24'
param backendSubnetAddressPrefix string = '10.100.2.0/24'
param storageSubnetAddressPrefix string = '10.100.0.0/24'

var uniqueSuffix = uniqueString(resourceGroup().id)
var vnetName = 'vnet-${uniqueSuffix}'
var frontEndSubnetName = 'snet-frontend'
var frontEndSubnetNsgName = 'nsg-${frontEndSubnetName}'
var backEndSubnetName = 'snet-backend'
var backEndSubnetNsgName = 'nsg-${backEndSubnetName}'
var storageSubnetName = 'snet-hub'
var functionStorageAccountName = 'st${uniqueSuffix}'
var applicationInsightsName = 'appi-${uniqueSuffix}'
var frontEndFunctionAppName = 'func-frontend-${uniqueSuffix}'
var backEndFunctionAppName = 'func-backend-${uniqueSuffix}'
var privateStorageTableDnsZoneName = 'privatelink.table.${environment().suffixes.storage}'
var privateEndpointStorageTableName = '${functionStorageAccountName}-table-private-endpoint'
var privateStorageBlobDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var privateEndpointStorageBlobName = '${functionStorageAccountName}-blob-private-endpoint'
var privateStorageQueueDnsZoneName = 'privatelink.queue.${environment().suffixes.storage}'
var privateEndpointStorageQueueName = '${functionStorageAccountName}-queue-private-endpoint'

var queueDefinitionName = 'readings'
var tableDefinitionName = 'readings'
var storageServiceName = 'default'

// TODO: Implement logging of secure services (is this handled by AzureServices bypass).
// TODO: Can we consolidate the private endpoints?

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
          networkSecurityGroup: {
            id: frontEndNetworkSecurityGroup.id
          }
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
          networkSecurityGroup: {
            id: backEndNetworkSecurityGroup.id
          }
        }
      }
      {
        name: storageSubnetName
        properties: {
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          addressPrefix: storageSubnetAddressPrefix
        }
      }
    ]
  }
}

resource frontEndNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: frontEndSubnetNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'BlockBackEndAccess'
        properties: {
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: frontendSubnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: backendSubnetAddressPrefix
          destinationPortRange: '*'
          protocol: '*' 
          priority: 2048
        }
      }
    ]
  }
}

resource backEndNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: backEndSubnetNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'BlockFrontEndAccessInbound'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: frontendSubnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: backendSubnetAddressPrefix
          destinationPortRange: '*'
          protocol: '*' 
          priority: 2048
        }
      }
      {
        name: 'BlockFrontEndAccessOutbound'
        properties: {
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: backendSubnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: frontendSubnetAddressPrefix
          destinationPortRange: '*'
          protocol: '*' 
          priority: 2048
        }
      }
    ]
  }
}

resource privateStorageBlobDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateStorageBlobDnsZoneName
  location: 'global'
}

resource privateStorageQueueDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateStorageQueueDnsZoneName
  location: 'global'
}

resource privateStorageTableDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateStorageTableDnsZoneName
  location: 'global'
}

resource privateStorageBlobDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateStorageBlobDnsZone
  name: '${privateStorageBlobDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateStorageQueueDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateStorageQueueDnsZone
  name: '${privateStorageQueueDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateStorageTableDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateStorageTableDnsZone
  name: '${privateStorageTableDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateEndpointStorageBlobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-05-01' = {
  parent: privateEndpointStorageBlob
  name: 'blobPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateStorageBlobDnsZone.id
        }
      }
    ]
  }
}

resource privateEndpointStorageTablePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-05-01' = {
  parent: privateEndpointStorageTable
  name: 'tablePrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateStorageTableDnsZone.id
        }
      }
    ]
  }
}

resource privateEndpointStorageQueuePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-05-01' = {
  parent: privateEndpointStorageQueue
  name: 'queuePrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateStorageQueueDnsZone.id
        }
      }
    ]
  }
}

resource privateEndpointStorageBlob 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: privateEndpointStorageBlobName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, storageSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'MyStorageBlobPrivateLinkConnection'
        properties: {
          privateLinkServiceId: functionStorageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource privateEndpointStorageTable 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: privateEndpointStorageTableName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, storageSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'MyStorageTablePrivateLinkConnection'
        properties: {
          privateLinkServiceId: functionStorageAccount.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource privateEndpointStorageQueue 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: privateEndpointStorageQueueName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, storageSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'MyStorageQueuePrivateLinkConnection'
        properties: {
          privateLinkServiceId: functionStorageAccount.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
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
    privateStorageBlobDnsZoneLink
    privateEndpointStorageBlobPrivateDnsZoneGroup
    privateStorageQueueDnsZoneLink
    privateEndpointStorageQueuePrivateDnsZoneGroup
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
    privateStorageBlobDnsZoneLink
    privateEndpointStorageBlobPrivateDnsZoneGroup
    privateStorageTableDnsZoneLink
    privateEndpointStorageTablePrivateDnsZoneGroup
    privateStorageQueueDnsZoneLink
    privateEndpointStorageQueuePrivateDnsZoneGroup
  ]
}
