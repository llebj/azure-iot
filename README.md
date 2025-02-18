# azure-iot
## Certificate Generation
TLS certificates are required in order to connect an MQTT client to an Event Grid MQTT broker in Azure.

1. Generate a encrypted root certificate private key
`openssl genpkey -algorithm RSA -out {output} -aes256`

2. Generate a self-signed root certificate:
`openssl req -x509 -new -noenc -key {root key} -sha256 -days 3650 -out {root crt}`
The `-x509` flag is used to output a certificate instead of a signing request and the `-noenc` flag specifies that we do not want to encrypt anything (the key is already encrypted and the certificate does not need to be encrypted).

3. Generate an intermediate CA:
  3.1 Generate an intermediate certificate private key:
  `openssl genpkey -algorithm RSA -out {intermediate key} -aes256`
  3.2 Generate a certificate signing request aginst the root CA for the intermediate CA:
  `openssl req -new -key {intermediate key} -out {csr}`
  3.3 Sign the intermediate certificate with the root CA:
  `openssl x509 -req -in {intermediate csr} -CA {root crt} -CAkey {root key} -out {intermediate crt} -days 1825 -sha256 -extfile /etc/ssl/openssl.cnf -extensions v3_ca`
  The `-extfile` and `-extensions` flags are used to mark the certificate as a CA certificate that can be used to sign device certificates.

4. Issue certificates for any devices that require them:
  4.1 Generate a private key for the device:
  `openssl genpkey -algorithm RSA -out {device key}`
  4.2 Generate a certificate signing request against the intermediate CA for the device certificate:
  `openssl req -new -key {device key} -out {device csr} -noenc`
  4.3 Sign the device certificate with the intermediate CA:
  `openssl x509 -req -in {device csr} -CA {intermediate crt} -CAkey {intermediate key} -out {device crt} -days 365 -sha256`

5. The client application requires that the certificate be in `pfx` format:
`openssl pkcs12 -export -out {output} -inkey {device key} -in {device crt} -certfile {intermediate crt}`
