param
(
    $version = "0.0.0-local",
    $registry = "readsourceacr"
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath

# use ansible to codegen the porter and docker files
docker build -t cnab-ansible-base -f Dockerfile.base $here
# TODO: build a new image rather than use volume mount, so this script will work in a containerised CI/CD environment
docker run --rm -v "$($here):/src" `
                -w /src `
                cnab-ansible-base `
                ansible-playbook -e "bundle_version=$version" -e "registry=$($registry).azurecr.io" ./codegen.yml

az acr login -n $registry

$envs = (gci -dir ./ansible/environments).Name
# build bundle for each environment
foreach ($env in $envs)
{
    Copy-Item $here/porter-$env-codegen.yaml $here/porter.yaml
    porter build
    porter publish
    Remove-Item $here/porter.yaml
}
