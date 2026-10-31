# Part 4: Capstone project, step by step

Build a multi-region, zone-redundant web app entirely in Bicep, then break it on purpose and explain the results. Plan on about 2–3 weeks part-time.

This part has **no solution folder**, because being able to build this yourself is the goal. The guide gives you the design, working snippets for the services Part 3 didn't cover, and a check for each milestone.

Back to the full plan: [../overview.md](../overview.md)

---

## What you'll build

```
                  Users
                    │
         Azure Front Door (Standard, global)
        priority 1 │           │ priority 2
   ┌───────────────┘           └───────────────┐
   ▼                                           ▼
Southeast Asia                             East Asia
App Service (P1v3, zone-redundant)         App Service (P1v3, zone-redundant)
   │                                           │
   └──────► SQL failover group listener ◄──────┘
            primary ───async───► secondary

Shared: Key Vault · Application Insights · Log Analytics · Storage (GZRS)
```

Southeast Asia and East Asia are a region pair, and both have 3 zones. GZRS storage replicates to the pair automatically.

---

## Cost: read this first

These are public list prices in USD, checked on 2026-10-31 for Linux plans. Confirm them in the [Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) when you write your own estimate.

| Item | Dev | Prod |
|---|---|---|
| App Service | 2 B1 instances: about $0.04/h | 4 P1v3 instances: about $0.80/h |
| Azure SQL | 2 S0 databases: about $0.04/h | 2 databases with 2 vCores each: about $1.60/h, before any zone redundancy charge |
| Front Door Standard | $35/month: about $0.05/h | About $0.05/h |
| **Rough total** | **About $0.13/h, or $3/day** | **About $2.50/h, or $60/day** |

Traffic, logs and storage add a little on top.

**The rules that keep this affordable:**
1. Do all your building in **dev**, and delete it at the end of each session.
2. Deploy **prod only once**, for the failover drills, and aim to finish within 2 hours. That costs about $5.
3. Your $10 budget only sends an alert. It doesn't stop anything, so a forgotten prod deployment could cost over $1,000 in a month.

---

## Step 0: Prerequisites

**0.1 Do these labs first.** The capstone assumes you've done them, and it won't explain them again:

| You need | From |
|---|---|
| Zones, SLA math and DR patterns | Part 1, including `part1/dr-plan.md` |
| App Service, GZRS and Azure SQL tiers | Part 2, including `part2/sql-recommendation.md` |
| Modules, `.bicepparam` files, subscription scope | [Part 3](../part3/README.md), Labs 17, 18 and 21 |
| `existing` and `getSecret()` | Part 3, Lab 22 |
| GitHub Actions with OIDC | Part 3, Lab 24 |

**0.2 Confirm your tools and budget** in Git Bash. The second command should list a $10 budget:

```bash
az bicep version
```

```bash
az consumption budget list --query "[].{Name:name, Amount:amount}" -o table
```

**0.3 Set up a project folder.** It sits outside this learning folder, because it becomes its own GitHub repository:

```bash
export MSYS_NO_PATHCONV=1; CAP="/d/LEARN BY MYSELF/azure-capstone"; mkdir -p "$CAP/infra/modules" "$CAP/.github/workflows"; cp -r "/d/LEARN BY MYSELF/Azure/part4/app" "$CAP/"; cd "$CAP"; ls
```

The test app in [app/server.js](app/server.js) shows which region answered and whether the Key Vault secret arrived. It doesn't connect to the database, so the SQL drill in Milestone 7 tests failover with the CLI.

**0.4 Use this layout:**

```
azure-capstone/
├── app/                     test app (already copied)
├── infra/
│   ├── bootstrap.bicep      resource groups and Key Vault
│   ├── main.bicep           everything else, at subscription scope
│   ├── dev.bicepparam
│   ├── prod.bicepparam
│   ├── bicepconfig.json
│   └── modules/             monitoring, storage, region, sql, frontdoor...
├── .github/workflows/deploy.yml
└── README.md                your design write-up
```

---

## Milestone 1: Bootstrap (1 h)

**Why it's separate:** `getSecret()` needs a vault that already exists, so the vault can't be created by the template that reads it.

**Build `bootstrap.bicep`** at subscription scope, with an `env` param. It should create:
- `rg-capstone-<env>-shared`, `rg-capstone-<env>-primary` and `rg-capstone-<env>-secondary`.
- A Key Vault in the shared group, with RBAC authorization and `enabledForTemplateDeployment: true`.

**Deploy it,** then give yourself the **Key Vault Secrets Officer** role and store a random SQL password, as in Lab 22. The secret value is the one thing not in Bicep, because secrets must never be in your files.

**✅ Check:** `az keyvault secret show` finds the secret's name, and the password isn't in any file or in your terminal output.

---

## Milestone 2: Monitoring and storage (1 h)

**Build `modules/monitoring.bicep`** with a Log Analytics workspace and a workspace-based Application Insights, as in Lab 16. Output the connection string.

**Build `modules/storage.bicep`** with the SKU as a param: `Standard_LRS` in dev and `Standard_GZRS` in prod.

**Start `main.bicep`** at subscription scope, using `existing` for the 3 resource groups and `scope:` for each module.

**✅ Check:** `what-if` shows only the resources you expect, and a second deployment changes nothing.

---

## Milestone 3: One module, two regions (2–3 h)

**Build `modules/region.bicep`**, then deploy it twice with a loop:

```bicep
module regions 'modules/region.bicep' = [
  for r in regionConfigs: {
    name: 'region-${r.name}'
    scope: resourceGroup(r.resourceGroup)
    params: {
      // location, plan SKU, instance count, zone redundancy, settings...
    }
  }
]
```

Each region gets a plan and a web app with:
- `identity: { type: 'SystemAssigned' }`, and the principal ID as an output.
- `healthCheckPath: '/health'`, `alwaysOn: true`, `httpsOnly: true` and `linuxFxVersion: 'NODE|22-lts'`.
- App settings `REGION_NAME`, `ENV_NAME` and `APPLICATIONINSIGHTS_CONNECTION_STRING`.

**Deploy the test app to each region.** Replace `<app-name>` and `<group>` with your values:

```bash
cd "$CAP/app"; powershell -NoProfile -Command "Compress-Archive -Force -Path server.js,package.json -DestinationPath ../app.zip"; cd "$CAP"
```

```bash
az webapp deploy -g <group> -n <app-name> --src-path app.zip --type zip
```

**✅ Check:** each app's own URL returns JSON naming the right region.

---

## Milestone 4: SQL failover group and secrets (3–4 h)

Three facts shape this design:
- **Use the listener in your connection string:** `<fog-name>.database.windows.net` keeps working after a failover. The server names don't.
- **A failover group doesn't copy zone redundancy** to a secondary it creates for you. So declare the secondary database yourself with `zoneRedundant`, and let the group inherit it.
- **The failover group's name must be globally unique.**

**Build the two servers** using the password from `keyVault.getSecret()`, with each server in its region's group. Then add the databases and the group. These snippets show the parts Part 3 didn't cover:

```bicep
// On the secondary server. It runs in the secondary region's group.
resource secondaryDb 'Microsoft.Sql/servers/databases@2023-08-01' = {
  parent: secondaryServer
  name: databaseName
  location: location
  sku: sqlSku
  properties: {
    createMode: 'Secondary'
    sourceDatabaseId: primaryDatabaseId
    zoneRedundant: zoneRedundant
  }
}
```

```bicep
// On the primary server. It runs after the secondary database exists.
resource failoverGroup 'Microsoft.Sql/servers/failoverGroups@2023-08-01' = {
  parent: primaryServer
  name: failoverGroupName
  properties: {
    readWriteEndpoint: { failoverPolicy: 'Manual' }
    readOnlyEndpoint: { failoverPolicy: 'Disabled' }
    partnerServers: [{ id: secondaryServerId }]
    databases: [primaryDatabase.id]
  }
}
```

Microsoft recommends the customer-managed policy, `Manual`. With `Automatic`, you wait at least an hour, and Microsoft decides whether to act.

**S0 can't be zone-redundant**, so `zoneRedundant` is false in dev. In prod, use `{ name: 'GP_Gen5', tier: 'GeneralPurpose', family: 'Gen5', capacity: 2 }`.

**Store the connection string in Key Vault** from a module with a `@secure()` param, and never output it. Use a `Microsoft.KeyVault/vaults/secrets` resource named `db-connection`.

**Let the apps read it.** Add this app setting to each region:

```bicep
DB_CONNECTION: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=db-connection)'
```

Then give each app's identity the **Key Vault Secrets User** role on the vault:

```bicep
resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, 'secrets-user')
  scope: keyVault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}
```

**✅ Check:** `az sql failover-group show` lists the database, and each app shows `"keyVaultSecretLoaded": true`. If it's false, restart the app, because it may have read the setting before the role applied. If it's still false, open the setting in the portal to see the error.

---

## Milestone 5: Front Door (2–3 h)

Front Door is global, so use `location: 'global'`. The pieces are a **profile**, an **endpoint**, an **origin group**, 2 **origins** and a **route**.

Deploy it in two modules, because of a dependency loop: each app needs the profile's ID (Milestone 6), and the origins need each app's hostname. So the order is **profile → regions → origins and route**.

```bicep
resource profile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: profileName
  location: 'global'
  sku: { name: 'Standard_AzureFrontDoor' }
}

output frontDoorId string = profile.properties.frontDoorId
```

```bicep
resource profile 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: profileName
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: profile
  name: endpointName
  location: 'global'
  properties: { enabledState: 'Enabled' }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: profile
  name: 'web'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/health'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
  }
}

resource origins 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = [
  for (hostName, i) in appHostNames: {
    parent: originGroup
    name: 'region-${i}'
    properties: {
      hostName: hostName
      originHostHeader: hostName
      httpsPort: 443
      priority: i + 1     // Priority 1 takes traffic. Priority 2 is the standby.
      weight: 1000
      enabledState: 'Enabled'
    }
  }
]

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: 'default'
  dependsOn: [origins]
  properties: {
    originGroup: { id: originGroup.id }
    supportedProtocols: ['Http', 'Https']
    patternsToMatch: ['/*']
    forwardingProtocol: 'HttpsOnly'
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Enabled'
  }
}

output endpointHostName string = endpoint.properties.hostName
```

**Your design choice:** this is active-passive. Giving both origins priority 1 makes the web tier active-active. Decide which suits you, and explain why in your README. Remember that the database still accepts writes in one region only.

**✅ Check:** after 5–10 minutes, `curl https://<endpoint-host>` shows the Southeast Asia region.

---

## Milestone 6: Close the back door (1 h)

Right now, anyone can skip Front Door by calling an app's own URL. Add this to each app's `siteConfig`, passing in the profile's ID. The service tag alone isn't enough, because other Azure customers' Front Doors share those addresses, so the header check makes it yours:

```bicep
ipSecurityRestrictions: [
  {
    name: 'allow-my-front-door'
    action: 'Allow'
    priority: 100
    tag: 'ServiceTag'
    ipAddress: 'AzureFrontDoor.Backend'
    headers: {
      'x-azure-fdid': [frontDoorId]
    }
  }
]
```

**✅ Check:** the Front Door URL still works, and each app's own URL returns `403`.

---

## Milestone 7: Prod and the failover drills (half a day, about $5)

**7.1 Finish the two parameter files:**

| Setting | `dev.bicepparam` | `prod.bicepparam` |
|---|---|---|
| Plan | B1 | P1v3 |
| Instances per region | 1 | 2 |
| Zone-redundant plan | false | true |
| Storage | `Standard_LRS` | `Standard_GZRS` |
| SQL | S0 | `GP_Gen5`, 2 vCores, zone-redundant |

**7.2 Note the start time, then deploy prod.** Run `what-if` first. Set an alarm for 2 hours, and delete prod when you finish.

If a plan refuses zone redundancy, its hardware doesn't support it. Delete the plan's resource group and deploy again, as Part 2 explained.

**7.3 Run the drills.** Keep this running in a second terminal, so you can read off how long each outage lasts:

```bash
while true; do echo "$(date +%T) $(curl -s --max-time 5 https://<endpoint-host> | grep -o '"region": "[^"]*"')"; sleep 5; done
```

| Drill | How | Record |
|---|---|---|
| **Web region failure** | `az webapp stop` on the primary app | Seconds until East Asia answers |
| **Web recovery** | `az webapp start` on the primary app | Seconds until traffic returns |
| **Database failover** | `az sql failover-group set-primary -g <secondary-group> -s <secondary-server> -n <fog-name>` | Duration, and whether the listener name still resolves |
| **Database failback** | The same command, with the original primary's group and server | Duration |

**Fail back before you redeploy.** Your template says which server is primary, so redeploying after a failover can fail or change the roles.

**7.4 Delete prod** using the cleanup commands at the end of this guide, and record the total time and rough cost.

**✅ Check:** you have measured numbers for all 4 drills, and prod is gone.

---

## Milestone 8: The pipeline (2–3 h)

Extend your Lab 24 workflow to do **lint → what-if on pull requests → deploy on merge → deploy the app to both regions**. Deploy **dev** only from the pipeline, so a merge can't start prod's costs.

This template needs more access than Lab 24 did, for two reasons:
- It deploys at **subscription scope**, using `az deployment sub`.
- It **creates role assignments**, which Contributor can't do. So the identity also needs **Role Based Access Control Administrator**.

Assign both roles at subscription scope for this lab. That's powerful access, so **delete the identity when you finish**. In real work, you'd limit it to the capstone's resource groups and restrict which roles it can assign.

`what-if` and `getSecret()` also need the identity to be able to use the vault, which Contributor covers.

**✅ Check:** a pull request shows `what-if` output and deploys nothing, a merge deploys dev, and a bad Bicep change fails at lint.

---

## Milestone 9: Your README (half a day)

This is what proves you understand the design. In the capstone's `README.md`, cover:

1. **Architecture:** the diagram, and why you chose those regions and that Front Door routing.
2. **Composite SLA:** use the Lesson 5 method from Part 1 and current figures from the [SLA page](https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services). Start by treating the two web regions as parallel, then put Front Door and SQL in series. Say which component limits the result.
3. **RTO and RPO:** state your targets and your **measured** drill results. Include the manual step: who decides to fail over the database, and how they'd find out there's a problem?
4. **Monthly cost:** estimates for dev and prod from the Pricing Calculator, including which parts you'd cut first and what you'd lose.
5. **Known weak points.** At least cover these:
   - There's one Key Vault, in the primary region. What happens to the secondary app if that region fails and it has to restart?
   - Monitoring is in one region too. What can you still see during an outage?
   - `Manual` database failover means someone has to act. What does that do to your RTO?

**✅ Check:** someone who has never seen the project can explain from your README what happens when Southeast Asia goes down.

---

## Cleanup

Set `ENV` to `dev` or `prod`:

```bash
ENV=dev; for g in primary secondary shared; do az group delete -n rg-capstone-$ENV-$g --yes --no-wait; done
```

Confirm they're gone. This can take several minutes:

```bash
az group list --query "[].name" -o tsv
```

A deleted Key Vault keeps its name reserved for 90 days. If your template reuses the same name, the next deployment fails until you **permanently delete** the vault:

```bash
az keyvault list-deleted --query "[].name" -o tsv
```

```bash
az keyvault purge -n <vault-name>
```

When you've finished the whole project, delete the pipeline's identity:

```bash
az ad app delete --id <app-id>
```

---

## Finished when

You've met the whole requirement when all of these are true:

- [ ] Everything except the password is deployed from Bicep.
- [ ] Each region runs on Premium v3 with zone redundancy in prod.
- [ ] Front Door serves the app, and the apps' own URLs return `403`.
- [ ] Azure SQL has a failover group, and the apps connect through its listener.
- [ ] Storage uses GZRS in prod.
- [ ] Key Vault, Application Insights and Log Analytics are all deployed.
- [ ] `dev` and `prod` differ only through their parameter files.
- [ ] The GitHub Actions pipeline runs lint, what-if and deploy.
- [ ] Your README covers the composite SLA, RTO/RPO with measured results, and monthly cost.
- [ ] All cloud resources are deleted, and only `bndzSSHKey` is left.

Without notes, you should be able to explain why each component is there, and what breaks if you remove it.
