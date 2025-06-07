param location string = resourceGroup().location
param client_name string
param event_grid_namespace_name string = 'mqtt-broker'

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
    minimumTlsVersionAllowed: '1.2'
  }
}

resource ca_certificate 'Microsoft.EventGrid/namespaces/caCertificates@2025-02-15' = {
  parent: event_grid_namespace
  name: 'intermediate-ca'
  properties: {
    encodedCertificate: '-----BEGIN CERTIFICATE-----\r\nMIIDSzCCAjOgAwIBAgIUVLM+AxrCH6EDeye6X7wMwEJ+zcgwDQYJKoZIhvcNAQELBQAwMTELMAkGA1UEBhMCR0IxEDAOBgNVBAoMB2hvbWVsYWIxEDAOBgNVBAMMB2hvbWVsYWIwHhcNMjUwMjE1MjAyMDQxWhcNMzAwMjE0MjAyMDQxWjA5MQswCQYDVQQGEwJHQjEQMA4GA1UECgwHaG9tZWxhYjEYMBYGA1UEAwwPaW50ZXJtZWRpYXRlLWNhMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAx+Ucw/32izAVpbAtyzqZ5XwyCgw4uVPAlQKb1f3iebF7e+vYSIPIjMqrnrqKoCP6B0DZ/wDQ81Ofh1fAiBEogOzLvKIquQDhY7RpuAVj71UTipQdR1CF/L3hKjcZULPUST07fS6d3Q9pEowLs94ie3+FCj820/FKVNkxAB2J6RosP7hUs+2PY7iWmsRgvkCZ1toUn7+46a0gcaWB0rkBB4PxnRHmHBlRQoUrtrSKcGtSwn6QQC21kXXFm8TqRBlgNkOiwtAmAEoVC2VfeVwx1kg2cZjgE+EMBbMlojOccpGe6HGaIK4zTNa8uKi91nt9p7yVGBOn+7PlqRHEZdASRQIDAQABo1MwUTAdBgNVHQ4EFgQUWMLJ04gmvXVHSRLyHPLIcRSA++AwHwYDVR0jBBgwFoAUEtse6amPGQvckeFcLaReuai5QTAwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAXLGxHBAKaTYrXNC6Bx1Mx4kvJH0plV3JXLqsfXV90snsXaTAgaUSjBA7TKUaGOxM11JN0tmbq6AucrggiedT1REhmRGGrJA2m8W/VnamPvhL+sA6vRSLEoKojksagO4t+Mt397nUz0Z40WdAoqGOC1vsap+FyLm7rQiBEjIXT1AvjYrxbq4ppkLKgoL0cfDkvh6P3CIEO1TcZJRd++byP+VHhouKWn0mnqm3nbw2gvL4xSC393Fnn+uJlDr2wYmzr98xYHBfI3rVI7mgdwEyXJknVoRWiDa2CwriCdnWgjE7BvprxdCXldeBTktKzGtrR11UwxjGYgME7AxtL/t7Sw==\r\n-----END CERTIFICATE-----'
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

resource topic_space 'Microsoft.EventGrid/namespaces/topicSpaces@2025-02-15' = {
  parent: event_grid_namespace
  name: 'All'
  properties: {
    topicTemplates: [
      '#'
    ]
  }
}
