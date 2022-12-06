# HuduCertificateBot - SSL Certificate Monitoring

This is an Azure function app created to improve SSL monitoring for Hudu and add expirations for certificates not tied to websites. This is in response to the following feature request: https://hudu.canny.io/feature-requests/p/security-certificate-tracking

## Features
- Creates 'SSL Certificate' Asset Layout
- Monitors assets for changes to the Certificate field and populates other certificate properties

## Requirements
- Azure subscription and function app
- Hudu hostname and API key

## Installation
1. Generate a Hudu API key https://yourhuduserver/admin/api_keys
2. Fork this repository
3. Deploy the Azure Function App to your environment 
    - [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjohnduprey%2FHuduCertificateBot%2Fmain%2FDeployment%2FAzureDeployment.json)
4. Fill in the details of the deployment template with the appropriate API keys.
5. Disconnect and reconnect GitHub to enable Run from Package mode
6. Create a new SSL Certificate asset and populate the Certificate field with the Base64 contents.
7. The function app runs every 30 minutes looking for modified assets.

## Copyright
This project utilizes some of the helper functions and approaches written by Kelvin Tegelaar from the CIPP project https://github.com/KelvinTegelaar/CIPP and is licensed under the same terms.