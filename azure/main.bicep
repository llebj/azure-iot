param location string = resourceGroup().location

param client_name string
param event_grid_namespace_name string = 'mqtt-broker'

@minLength(3)
@maxLength(24)
param storage_account_name string
param storage_sku string = 'Standard_LRS'
param table_definition_name string = 'readings'

param server_farm_name string = 'asp-iot'

param server_farm_id string 
param function_app_name string = 'iot-processing'

// Turn this into a variable
var function_app_storage_container_name string = 'app-package-${function_app_name}-0ec39e8'
var function_app_storage_endpoint string = 'https://${storage_account_name}.blob.core.windows.net/${function_app_storage_container_name}'

resource event_grid_namespace 'Microsoft.EventGrid/namespaces@2025-02-15' = {
  name: event_grid_namespace_name
  location: location
  sku: {
    name: 'Standard'
    capacity: 1
  }
  identity: {
    type: 'None'
  }
  properties: {
    topicSpacesConfiguration: {
      clientAuthentication: {
        alternativeAuthenticationNameSources: [
          'ClientCertificateSubject'
        ]
      }
      state: 'Enabled'
      maximumSessionExpiryInHours: 1
      maximumClientSessionsPerAuthenticationName: 1
    }
    isZoneRedundant: true
    publicNetworkAccess: 'Enabled'
    inboundIpRules: []
  }
}

resource client 'Microsoft.EventGrid/namespaces/clients@2025-02-15' = {
  parent: event_grid_namespace
  name: client_name
  properties: {
    authenticationName: client_name
    clientCertificateAuthentication: {
      validationScheme: 'SubjectMatchesAuthenticationName'
    }
    state: 'Enabled'
    attributes: {}
  }
}

resource namespaces_mqtt_broker_name_Test 'Microsoft.EventGrid/namespaces/permissionBindings@2025-02-15' = {
  parent: event_grid_namespace
  name: 'All'
  properties: {
    topicSpaceName: 'All'
    permission: 'Publisher'
    clientGroupName: '$all'
  }
  dependsOn: [
    topic_space
  ]
}

resource topic_space 'Microsoft.EventGrid/namespaces/topicSpaces@2025-02-15' = {
  parent: event_grid_namespace
  name: 'All'
  properties: {
    topicTemplates: [
      '#'
    ]
  }
}

resource storage_account 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storage_account_name
  location: 'uksouth'
  sku: {
    name: storage_sku
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
    accessTier: 'Hot'
  }
}

resource blob_service 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storage_account
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
  }
}

resource function_app_storage_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blob_service
  name: function_app_storage_container_name
  properties: {}
}


resource file_service 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' = {
  parent: storage_account
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource table_service 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = {
  parent: storage_account
  name: 'default'
}

resource table_definition 'Microsoft.Storage/storageAccounts/tableServices/tables@2024-01-01' = {
  parent: table_service
  name: table_definition_name
  properties: {}
}

resource server_farm 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: server_farm_name
  location: 'uksouth'
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
    maximumElasticWorkerCount: 2
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }
}

resource sites_iot_processing_name_resource 'Microsoft.Web/sites@2024-04-01' = {
  name: function_app_name
  location: location
  kind: 'functionapp,linux'
  properties: {
    enabled: true
    serverFarmId: server_farm_id
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobcontainer'
          value: function_app_storage_endpoint
          authentication: {
            type: 'storageaccountconnectionstring'
            storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          }
        }
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 2048
        maximumInstanceCount: 40
      }
    }
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      appSettings: [
        {
          name: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage_account.name};AccountKey=${storage_account.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage_account.name};AccountKey=${storage_account.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'Storage_Uri'
          value: storage_account.properties.primaryEndpoints.table
        }
        {
          name: 'Storage_AccountName'
          value: storage_account_name
        }
        {
          name: 'Storage_AccountKey'
          value: storage_account.listKeys().keys[0].value
        }
        {
          name: 'Storage_TableName'
          value: table_definition_name
        }
      ]
    }
  }
  dependsOn: [
    server_farm
  ]
}

resource host_name_bindings 'Microsoft.Web/sites/hostNameBindings@2024-04-01' = {
  parent: sites_iot_processing_name_resource
  name: '${function_app_name}.azurewebsites.net'
  properties: {
    siteName: 'iot-processing'
    hostNameType: 'Verified'
  }
}
