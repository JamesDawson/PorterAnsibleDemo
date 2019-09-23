# Using CNAB/Porter with Ansible

This repo is an experiment to better understand the benefits (if any) of pairing [CNAB](https://cnab.io) with an existing Ansible-based automated process.  What the automated process actually does is less important than understanding the integration of the two, however, for completeness here's what the Ansible playbook does:

* Provisions a set of Azure resources (networking, VM scaleset etc.)
* Sets up a dynamic Ansible inventory (based on the above)
* Perform some nominal Elasticsearch installation tasks

# Porter Features Used

[Porter](https://porter.sh) is an opionated implementation of the CNAB spec, this bundle uses the following Porter features:

* credentials
* parameters
* `exec` mixin

Rather than implementing the automated process using Porter mixins (its automation building blocks), the bundle uses a cutdown version of an existing Ansible playbook I had lying around.

# Usage

Before running the script below, you must set the following environment variables to configure Azure SPN authentication:
* AZURE_CLIENT_ID
* AZURE_SECRET
* AZURE_SUBSCRIPTION_ID
* AZURE_TENANT

> NOTE: See https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli for more details

Running the `porter-test.ps1` script from a PowerShell or PowerShell Core prompt will:

1. Build the invocation base image with all the Ansible pre-reqs (this will take a few minutes the first time)
1. Use Porter to build the CNAB bundle
1. Use Porter to invoke the CNAB bundle passing parameters to Ansible
1. Ansible will use the specified environment as its 'inventory' (for configuration purposes)

## Bundle-Per-Env Example

To run this example you should have an Azure Container Registry (ACR) available, and be logged in to the Azure-Cli. Run the example build process to generate the CNAB bundles for each environment (in this case two environments, 'example' & 'readsource'):
```
./build.ps1 -version 0.1.0 -registry myacr
```

You should now be able to see the following repositories in your ACR, inside which will be the versioned items:
```
elasticstack-example
elasticstack-example-bundle
elasticstack-readsource
elasticstack-readsource-bundle
```

The `-bundle` repositories contain the CNAB bundle manifests, while the others contain the invocation image that will perform the bundle install, upgrade or uninstall.

To install one of these bundles, you give Porter a reference to the bundle artefact:
```
porter install -t myacr.azurecr.io/elasticstack-example-bundle:0.1.0 --cred ./porter-dev-creds.yaml
```

## Examples

Run an installation using the default `example` environment and default `porter-dev-creds.yaml` credentials:
```
porter-test.ps1
```

Run an installation targetting the `foo` environment using a custom credential file (previously created via `porter credentials generate`):
```
porter-test.ps1 -environmentName foo -credentialFile ./myCreds.yml
```

Run an upgrade using the 'example' environment and default credentials (this skips the Azure resource provisioning stage):
```
porter-test.ps1 -environmentName example -action upgrade
```

Run a default installation without rebuilding the bundle:
```
porter-test.ps1 -environmentName example -skipBuild
```

# Thoughts

The bundle concept offers convenience for:

* packaging the runtime environment, automation process and configuration
* ability to use any CNAB-compliant tool for initiating the automated process (rather than having to roll-your-own)
* hides the underlying automation, which could be useful for turn-key appliance scenarios etc.

## Other considerations:

* developing the entire automation using Porter mixins is likely to be quite limiting for more complex scenarios - this would also force you to rebuild the package on each test iteration. Using a seperate tool for the automation (e.g. Ansible) offers a lower-friction development workflow and a richer set of building blocks to work with
* exposing all configuration for a reasonably complex process as CNAB parameters felt quite onerous and limiting (e.g. I failed to find the correct quoting strategy to send in a parameter value containing spaces - see the `porter_no-inventory.yaml` file), and I reverted back using the standard Ansible inventory for configuration management. This resulted in far fewer CNAB parameters to maintain.
* using only CNAB parameters would be more important for the more turn-key scenarios, where it is important to hide the underlying automation 
* initially I felt that credential handling was a bit clunky, but on reflection I think it's on par with other tools - it will be interesting to see whether the CNAB/Porter tooling expands to support secret stores (e.g. Azure KeyVault, Hashicorp Vault etc.)

# Gotchas

* Porter tracks installed bundles (look in `~/.porter/claims`) and as it tracks by bundle name it can't understand that a bundle installed with a different parameter is actually a different instance (as in this usage). Installing to two different environments worked fine, however, once I ran the uninstall against one environment Porter would not start an uninstall for the other as it didn't think the bundle was installed. Initially it was somewhat confusing as there isn't any message to explain why nothing is happening, so of course I assumed I'd messed-up something, however I eventually realised what was happening before completely losing my sanity.  One of the potential future experiments listed below aims to workaround this.

# Conclusions

I can see this tooling offering benefits whether you're delivering a shrink-wrapped cloud product that needs a simple way of enabling users/customers to install it, or if you're building cloud solutions internally.  Also, as long as your underlying automation supports it, you could have a single bundle that enabled deployment of your product to multiple cloud platforms (e.g. Azure and AWS).

The Porter tooling offers functionality that you would otherwise have to write yourself (i.e packaging and deployment invocation), as well as simplifying the process of encapsulating an automated process into a versioned artefact that is easy to distribute.

# Potential Future Experiments

* Investigate using Ansible to codegen the `porter.yaml` file (e.g. to automate parameter authoring)
* Enable passing arbitrary Ansible arguments through the `porter install` command (i.e. to provide greater adhoc control)
* Bundling the automation and configuration seperately (i.e. a configuration bundle per enviroment for this use case), then use Porter's [bundle dependencies feature](https://porter.sh/dependencies/) to re-combine them at deployment time
