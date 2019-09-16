param
(
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path ansible/environments/$_})]
    [string] $environmentName = "example",

    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path $_})]
    [string] $credentialFile = "./porter-dev-creds.yml",

    [ValidateSet("install","upgrade","uninstall", ignorecase=$true)]
    [string] $action = "install",

    [switch] $skipBuild
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath

if ( !(Test-Path env:AZURE_SECRET) )
{
    Write-Error "You must preload your shell with the required environment variables for Azure SPN authentication:`n`tAZURE_CLIENT_ID`n`tAZURE_SECRET`n`tAZURE_SUBSCRIPTION_ID`n`tAZURE_TENANT"
}

Push-Location $here
if (!$skipBuild)
{
    # ensure the base image is built
    docker build -q -t cnab-ansible-base -f Dockerfile.base .
    # build the bundle
    porter build
}

Write-Host "******`n* Target Environment: $environmentName`n******" -ForegroundColor Green
porter $action --param environment_name=$environmentName --cred $credentialFile
Pop-Location
