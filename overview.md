# Azure Fundamentals – Improvement Plan

**Goal:** Deepen understanding of Azure regions, availability zones, and service tiers. Practice ARM templates or Bicep for infrastructure as code.

| Part | Topic | Exercises |
|---|---|---|
| 1 | Regions and availability zones ([step-by-step guide](part1/README.md)) | 1–6 |
| 2 | Service tiers ([step-by-step guide](part2/README.md)) | 7–12 |
| 3 | Infrastructure as Code (ARM and Bicep) ([step-by-step guide](part3/README.md)) | 13–24 |
| 4 | Capstone project ([step-by-step guide](part4/README.md)) | — |

---

# Part 1: Regions and availability zones

## 1.1 What to learn

**Global structure**
- **Geography → Region → Availability Zone → Datacenter.** A geography (for example "Europe") contains regions ("West Europe", "Sweden Central"). A region contains up to 3 availability zones, and each zone is one or more datacenters with its own power, cooling and networking.
- **Region pairs.** Most older regions are paired with another region in the same geography, such as East US ↔ West US. Pairs get platform updates one at a time, are recovered first in a large outage, and are the default target for GRS storage replication. Many newer regions have **no pair** and rely on zones instead.
- **Sovereign clouds:** Azure Government, Azure China (21Vianet). They are separate clouds with their own endpoints.
- **Non-regional (global) services:** Microsoft Entra ID, Azure Front Door, Traffic Manager, Azure DNS. They aren't deployed into one region.

**Availability zones**
- **Zonal:** you pin a resource to one zone, such as a VM in zone 1. You get control but no automatic failover.
- **Zone-redundant:** the platform spreads the resource across zones for you. Examples are ZRS storage, Standard Load Balancer, zone-redundant App Service and zone-redundant SQL.
- **Non-zonal / regional:** no zone guarantee.
- **Logical vs physical zones:** "Zone 1" in your subscription may be a different physical zone than "Zone 1" in another subscription.
- Not every region or VM size supports zones, so always check.

**Availability sets (the older, single-datacenter option)**
- **Fault domains:** separate racks with separate power and network.
- **Update domains:** groups that are rebooted at different times during maintenance.
- **Availability sets vs zones vs scale sets:** know when each one fits.

**SLAs and composite SLAs**
- Single VM with Premium SSD: 99.9%. Two or more VMs in an availability set: 99.95%. Two or more VMs across zones: 99.99%.
- **Serial dependencies multiply:** App (99.95%) × SQL (99.99%) = 99.94%.
- **Parallel redundancy:** 1 − (1 − A)(1 − B).
- Convert a percentage into downtime: 99.9% ≈ 8.76 h/year, 99.99% ≈ 52.6 min/year.

**Choosing a region.** Weigh these: latency to users, data residency and compliance, which services and SKUs are available there, price (it differs by region), whether it has zones, and whether it has a pair.

**Disaster recovery basics**
- **RTO** (how long recovery may take) and **RPO** (how much data you can lose).
- Patterns, roughly from cheapest to most resilient: backup/restore, pilot light, warm standby, active-active.
- Tools: Azure Site Recovery, Azure Backup, geo-replication.

## 1.2 Exercises

| # | Exercise | What it teaches |
|---|---|---|
| 1 | Run `az account list-locations -o table` and find 3 regions that have zones and 3 that don't. Identify each one's pair, or note that it has none. | Region layout |
| 2 | Run `az vm list-skus --location eastus --size Standard_D2s --output table` and read the **Zones** column. Try the same in a region without zones. | SKU and zone availability |
| 3 | Deploy 2 VMs in zones 1 and 2 behind a Standard Load Balancer. Stop one VM and confirm the app still responds. | Zonal redundancy |
| 4 | Create an availability set with 2 VMs. In the portal, look at which fault domain and update domain each VM landed in. | FD/UD |
| 5 | **Paper exercise.** App Service (99.95%) → Azure SQL (99.99%) → Storage (99.9%). Compute the composite SLA. Then add a second region in active-active and compute it again. | SLA math |
| 6 | Write a one-page DR plan for a fictional app with RTO = 1 h and RPO = 15 min. Pick the regions, the pattern and the services, and justify each choice. | Design thinking |

---

# Part 2: Service tiers

## 2.1 What to learn

Higher tiers usually add features (SLA, zone support, scaling, private networking) as well as raw performance. Learn to answer "why would I pay for the next tier up?" for each of these services.

| Service | Tiers / options to know |
|---|---|
| **Virtual Machines** | Families: B (burstable), D (general purpose), E (memory), F (compute), L (storage), N (GPU), M (huge memory). Naming such as `Standard_D4s_v5`. **Spot** VMs. |
| **Managed Disks** | Standard HDD → Standard SSD → Premium SSD → Premium SSD v2 → Ultra Disk. Disk type affects the VM SLA. |
| **Storage accounts** | Performance: Standard or Premium. **Redundancy:** LRS, ZRS, GRS, RA-GRS, GZRS, RA-GZRS. **Access tiers:** Hot, Cool, Cold, Archive, plus rehydration and lifecycle policies. |
| **App Service plans** | Free/Shared → Basic → Standard (deployment slots, autoscale) → Premium v3 (zone redundancy, more slots) → Isolated v2 (App Service Environment, network isolation). |
| **Azure SQL Database** | **DTU** (Basic/Standard/Premium) vs **vCore** (General Purpose, Business Critical, Hyperscale). Serverless vs provisioned. Elastic pools. |
| **Networking** | Load Balancer and Public IP **Standard** (the Basic SKU is retired). Application Gateway Standard_v2 / WAF_v2. VPN Gateway SKUs. |
| **Others** | Key Vault Standard vs Premium (HSM-backed keys). API Management tiers. Cosmos DB provisioned vs serverless vs autoscale. |

**Pricing models**
- Pay-as-you-go
- Reserved Instances (1 or 3 years)
- Azure Savings Plan
- Spot
- Azure Hybrid Benefit
- Dev/Test pricing

**Cost tools**
- Pricing Calculator
- TCO Calculator
- Cost Management with budgets and alerts
- Azure Advisor

## 2.2 Exercises

| # | Exercise |
|---|---|
| 7 | Create an App Service on **B1**, then scale up to **S1** and then **P1v3**. Note what each step unlocks: slots, autoscale, zone redundancy. Scale back down afterwards. |
| 8 | Create a storage account on **LRS** and upload a blob. Change it to **ZRS** or **GRS** and note which conversions are allowed. Move a blob Hot → Cool → Archive, then try to read the archived blob. |
| 9 | Write a lifecycle management policy: move blobs to Cool after 30 days, to Archive after 90, and delete them after 365. |
| 10 | In the Pricing Calculator, price the same workload three ways: (a) a single D4s_v5 VM on pay-as-you-go, (b) the same VM with a 3-year reservation, (c) Spot. Then price it in 3 different regions. |
| 11 | Create a $10 budget with an email alert at 80%. **Do this one first.** |
| 12 | Compare Azure SQL General Purpose and Business Critical: HA architecture, zone redundancy, read replicas and price. Write a short recommendation. |

---

# Part 3: Infrastructure as Code (ARM and Bicep)

## 3.1 ARM templates (learn them, but write Bicep)

- **Structure:** `$schema`, `contentVersion`, `parameters`, `variables`, `functions`, `resources`, `outputs`.
- **Template functions:** `resourceGroup().location`, `uniqueString()`, `concat()`, `resourceId()`, `reference()`, `parameters()`, `variables()`.
- **`dependsOn`** and the order resources deploy in.
- **Deployment scopes:** resource group, subscription, management group, tenant.
- **Deployment modes:**
  - **Incremental** (the default) adds and updates resources.
  - **Complete** also deletes resources that aren't in the template. This is dangerous.
- **What-if:** preview a deployment before running it.
- **Template specs** and **deployment stacks:** store templates and manage the resources they deploy.
- Bicep **compiles to ARM JSON**, so being able to read ARM helps when you debug.

## 3.2 Bicep (main focus)

**Fundamentals**
- `param`, `var`, `resource`, `output`, `module`, `targetScope`.
- Decorators: `@description`, `@allowed`, `@minLength`, `@maxLength`, `@minValue`, `@secure()`.
- Symbolic references such as `storage.id` and `storage.properties.primaryEndpoints`. These create the dependencies for you, so you don't write `dependsOn`.
- The `existing` keyword, for referencing resources you don't deploy.
- Child resources: nested syntax or the `parent:` property.
- String interpolation: `'st${uniqueString(resourceGroup().id)}'`.

**Intermediate**
- **Loops:** `[for x in list: {...}]` and `[for (x, i) in list: ...]`.
- **Conditions:** `resource x '...' = if (deployIt) {...}`.
- **Modules:** split code into reusable files and pass outputs between them.
- **`.bicepparam` files** with one per environment, such as dev and prod.
- **User-defined types** (`type`), plus `union()`, `contains()`, `empty()` and the ternary operator.
- Reading secrets with `getSecret()` on an `existing` Key Vault.

**Advanced and tooling**
- `az bicep build` (Bicep → ARM) and `az bicep decompile` (ARM → Bicep).
- The linter with `bicepconfig.json`.
- **Azure Verified Modules (AVM)** and private module registries in ACR.
- **CI/CD:** GitHub Actions or Azure DevOps, with OIDC federated credentials, a lint → what-if → deploy pipeline, and environment approvals.
- Deploying at subscription scope (for example, creating resource groups) and using `scope:` on modules.

**Setup**
- VS Code with the **Bicep extension**
- Azure CLI (`az bicep install`)
- An Azure free account

## 3.3 Starter example

This creates a storage account with redundancy and tier chosen per environment:

```bicep
@description('Environment name')
@allowed(['dev', 'prod'])
param env string = 'dev'

param location string = resourceGroup().location

var skuByEnv = {
  dev: 'Standard_LRS'
  prod: 'Standard_ZRS'   // zone-redundant in prod
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${env}${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: skuByEnv[env] }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

output blobEndpoint string = storage.properties.primaryEndpoints.blob
```

Run these commands one at a time:

```bash
az group create -n rg-bicep-lab -l eastus
```

```bash
az deployment group what-if -g rg-bicep-lab -f main.bicep -p env=prod
```

```bash
az deployment group create -g rg-bicep-lab -f main.bicep -p env=prod
```

## 3.4 Exercises (in order of difficulty)

| # | Exercise |
|---|---|
| 13 | Write a **raw ARM JSON** template for a storage account and deploy it. Then run `az bicep decompile` on it and compare the two files. |
| 14 | Turn the example above into a version with **`@secure()` params**, `@allowed` SKUs and an output. Break it on purpose (wrong SKU, name too long) to see the validation errors. |
| 15 | **Loops:** deploy 3 storage accounts from an array, plus 3 blob containers inside one account using a nested loop. |
| 16 | **Conditions:** deploy Application Insights only when `env == 'prod'`. |
| 17 | **Modules:** build `network.bicep` (a VNet with 2 subnets and an NSG) and `vm.bicep`. Make `main.bicep` call both and pass the subnet ID from one module to the other. |
| 18 | **Environments:** create `dev.bicepparam` and `prod.bicepparam`. Dev uses B1 App Service and LRS storage. Prod uses P1v3 with `zoneRedundant: true` and ZRS. *This ties Parts 1–3 together.* |
| 19 | **Zone-redundant architecture in Bicep:** a Standard public IP, a Standard Load Balancer and a VM Scale Set across `zones: ['1','2','3']`. Delete an instance and watch it heal. |
| 20 | **Complete mode:** deploy a template, remove one resource from it, then redeploy with `--mode Complete` and `what-if`. See what would be deleted. |
| 21 | **Subscription scope:** use `targetScope = 'subscription'` to create the resource group and deploy a module into it. |
| 22 | **Key Vault:** use `existing` plus `getSecret()` to pass a SQL admin password into a module without hard-coding it. |
| 23 | **Use AVM:** rebuild Exercise 17 using Azure Verified Modules from `br/public:avm/...`. |
| 24 | **CI/CD:** set up a GitHub Actions workflow with OIDC login → `bicep lint` → `what-if` on pull requests → deploy on merge to main. |

---

# Part 4: Capstone project

Build a **multi-region, zone-redundant web app**, entirely in Bicep:
- 2 regions, each with an App Service on Premium v3 with zone redundancy
- Azure Front Door in front of both regions
- Azure SQL with a failover group
- Storage on GZRS
- Key Vault, Application Insights and Log Analytics
- dev and prod parameter files
- A GitHub Actions pipeline
- A README covering the composite SLA, the RTO/RPO and the monthly cost estimate

If you can build and explain this, you've met the whole requirement.

---

# Study resources (all free on Microsoft Learn)

1. **AZ-900 learning path:** core architecture and pricing modules
2. **Fundamentals of Bicep → Intermediate Bicep → Advanced Bicep** learning paths. These are the best structured Bicep material and include free sandboxes.
3. **Well-Architected Framework, Reliability pillar,** plus "Azure services that support availability zones"
4. **Azure Architecture Center:** reference architectures for multi-region web apps
5. **AZ-104 (Azure Administrator):** the natural next certification after this

# Suggested pace (about 4 weeks)

| Week | Focus |
|---|---|
| 1 | Part 1 and Exercises 1–6 |
| 2 | Part 2 and Exercises 7–12 |
| 3 | Exercises 13–19 |
| 4 | Exercises 20–24 and start the capstone |

# Cost tip

After each lab, delete everything the lab created:

```bash
az group delete -n rg-bicep-lab --yes --no-wait
```

The zone-redundant Premium tiers and scale sets are where costs add up quickly, so delete those labs as soon as you finish them.
