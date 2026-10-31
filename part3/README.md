# Part 3: Infrastructure as Code (ARM and Bicep), step by step

Part 3 has 12 labs, which match Exercises 13–24. The overview's suggested pace is Labs 13–19 in week 3 and Labs 20–24 in week 4. Each lab should cost well under $1 if you delete its resources the same day.

**How each lab works:**
1. Read the short concept section and write the file yourself in `part3/work/`.
2. Run `what-if` to preview the change, then deploy it.
3. Only then compare your file with the one in [solutions](solutions/).

Back to the full plan: [../overview.md](../overview.md)

---

## Step 0: Setup (15 min)

**0.1 Install the tools.** Install [VS Code](https://code.visualstudio.com/) with the **Bicep** extension, then open Git Bash and install the Bicep CLI:

```bash
az bicep install
```

```bash
az bicep version
```

**0.2 Sign in and stop Git Bash from rewriting Azure resource IDs:**

```bash
az login
```

```bash
export MSYS_NO_PATHCONV=1
```

**0.3 Set the lab variables.** They only last for the current shell session, so set them again if you open a new terminal:

```bash
LOC=southeastasia; RG=rg-bicep-lab; P3="/d/LEARN BY MYSELF/Azure/part3"; echo "$LOC / $RG / $P3"
```

**0.4 Load the public SSH key** for the VM labs. It comes from the key already in your subscription, and the VMs have no public IP, so you won't log in to them:

```bash
SSHKEY=$(az sshkey show -g bndzSSHKey -n bndz-azure-key --query publicKey -o tsv); echo "${SSHKEY:0:20}"
```

**0.5 Compile the solutions.** These files haven't been compiled yet, so check them before relying on them. This also downloads the public modules for Lab 23. Expect `no-unused-params` warnings for `ex14`, which uses unused params on purpose. Any line marked `Error` is a bug in the solution:

```bash
cd "$P3"; for f in solutions/*/*.bicep solutions/ex24/infra/main.bicep; do echo "== $f"; az bicep build --file "$f" --stdout > /dev/null; done
```

```bash
for f in solutions/ex18/*.bicepparam; do echo "== $f"; az bicep build-params --file "$f" --stdout > /dev/null; done
```

**0.6 Create the lab resource group:**

```bash
az group create -n $RG -l $LOC
```

---

## Lab 13: Raw ARM JSON (45 min)

### Concept
- An ARM template has `$schema`, `contentVersion`, `parameters`, `variables`, `resources` and `outputs`.
- Expressions go in square brackets, such as `[resourceGroup().location]` and `[concat('st', uniqueString(resourceGroup().id))]`.
- **Bicep compiles to this JSON,** so reading it helps when you debug.
- **Scopes:** a deployment targets a resource group, subscription, management group or tenant.

### Lab

**13.1 Write `azuredeploy.json`** for a storage account. Use a `storageSku` param, a `concat()` name and a blob endpoint output.

```bash
mkdir -p "$P3/work/ex13"; cd "$P3/work/ex13"
```

**13.2 Deploy it:**

```bash
az deployment group what-if -g $RG -f azuredeploy.json
```

```bash
az deployment group create -g $RG -f azuredeploy.json
```

**13.3 Convert it to Bicep,** then open the two files side by side:

```bash
az bicep decompile --file azuredeploy.json
```

**✅ Answer:**
1. What became shorter in the Bicep version?
2. Which ARM function became a symbolic reference?

Compare with: [ex13](solutions/ex13/azuredeploy.json)

---

## Lab 14: Params, decorators and validation (30 min)

### Concept
- Decorators validate input before anything deploys: `@allowed`, `@minLength`, `@maxLength`, `@minValue`, `@description`.
- `@secure()` keeps a value out of logs and deployment history.
- `what-if` previews changes, so run it before every deployment.

### Lab

**14.1 Write `main.bicep`.** Start from the example in [overview section 3.3](../overview.md), and add:
- A `prefix` param, limited to 3–11 characters.
- A `storageSku` param, limited with `@allowed`.
- A `plainNote` param, and a `@secure()` `secretNote` param. Don't use either of them in a resource.

```bash
mkdir -p "$P3/work/ex14"; cd "$P3/work/ex14"
```

**14.2 Deploy it with both notes set:**

```bash
az deployment group create -g $RG -f main.bicep -p plainNote=visible -p secretNote=hidden
```

**14.3 See how history treats them.** `plainNote` shows its value, but `secretNote` shows only its type:

```bash
az deployment group show -g $RG -n main --query properties.parameters
```

**14.4 Break it on purpose.** Read each validation error:

```bash
az deployment group what-if -g $RG -f main.bicep -p storageSku=Standard_XYZ
```

```bash
az deployment group what-if -g $RG -f main.bicep -p prefix=thisprefixiswaytoolong
```

**14.5 Add a bad output.** Add `output leak string = secretNote`, and build the file to see the linter warning. Then remove the line:

```bash
az bicep build --file main.bicep --stdout > /dev/null
```

**✅ Answer:**
1. Why is the `prefix` limit 11 characters? (Hint: storage names allow 24, and `uniqueString()` returns 13.)
2. Why shouldn't you put a secret in an output?

Compare with: [ex14](solutions/ex14/main.bicep)

---

## Lab 15: Loops (30 min)

### Concept
- `[for x in list: {...}]` creates one resource per item, and `[for (x, i) in list: ...]` also gives you the index.
- Use `parent:` to attach a child resource instead of building its name by hand.
- A blob container's parent is a `blobServices` resource named `default`, whose parent is the storage account.

### Lab

**15.1 Write `main.bicep`.** Deploy 3 storage accounts from an array, then 3 containers in one of those accounts by looping over `blobServices/containers`.

```bash
mkdir -p "$P3/work/ex15"; cd "$P3/work/ex15"
```

```bash
az deployment group what-if -g $RG -f main.bicep
```

```bash
az deployment group create -g $RG -f main.bicep
```

**15.2 Rerun the create command.** Nothing should change, because deployments describe a desired state.

**✅ Answer:**
1. What happens to the third account if you remove it from the array and redeploy in the default mode?
2. Why does a loop over `['logs','data','media']` make renaming risky?

Compare with: [ex15](solutions/ex15/main.bicep)

---

## Lab 16: Conditions (20 min)

### Concept
- `resource x '...' = if (condition) {...}` deploys the resource only when the condition is true.
- A conditional resource might not exist, so Bicep warns when you use its properties. Use `x!.id` when you know it exists, or `x.?properties` when it may not.
- Application Insights stores its data in a Log Analytics workspace, so both need the condition.

### Lab

**16.1 Write `main.bicep`** with an `env` param. Always deploy a storage account, and deploy the workspace and Application Insights only when `env == 'prod'`.

```bash
mkdir -p "$P3/work/ex16"; cd "$P3/work/ex16"
```

**16.2 Compare the two previews.** Only `prod` should list Application Insights:

```bash
az deployment group what-if -g $RG -f main.bicep -p env=dev
```

```bash
az deployment group what-if -g $RG -f main.bicep -p env=prod
```

**16.3 Deploy `prod`, then clear the group** before the next lab. Deleting can take a few minutes:

```bash
az deployment group create -g $RG -f main.bicep -p env=prod
```

```bash
az group delete -n $RG --yes; az group create -n $RG -l $LOC
```

**✅ Answer:** What would `what-if` show if you deployed `prod`, then ran `dev` in the same group? Why?

Compare with: [ex16](solutions/ex16/main.bicep)

---

## Lab 17: Modules (45 min, creates a VM)

### Concept
- A **module** is another Bicep file with its own params and outputs.
- Passing one module's output to another creates the dependency for you, so you don't need `dependsOn`.

### Lab

**17.1 Write three files:**
- `network.bicep`: a VNet with 2 subnets and an NSG. Output the web subnet's ID.
- `vm.bicep`: a NIC and an Ubuntu VM in zone 1, using `Standard_B1s`, with no public IP.
- `main.bicep`: calls both, and passes the subnet ID from one to the other.

```bash
mkdir -p "$P3/work/ex17"; cd "$P3/work/ex17"
```

```bash
az deployment group what-if -g $RG -f main.bicep -p sshPublicKey="$SSHKEY"
```

```bash
az deployment group create -g $RG -f main.bicep -p sshPublicKey="$SSHKEY"
```

**17.2 List the module deployments and read the output,** then delete the VM:

```bash
az deployment group list -g $RG --query "[].name" -o tsv
```

```bash
az deployment group show -g $RG -n main --query properties.outputs
```

```bash
az group delete -n $RG --yes; az group create -n $RG -l $LOC
```

**✅ Answer:**
1. Which order did Azure deploy the modules in, and how did it know?
2. What would you have to change to deploy a second VM?

Compare with: [ex17](solutions/ex17/main.bicep), [network.bicep](solutions/ex17/network.bicep), [vm.bicep](solutions/ex17/vm.bicep)

---

## Lab 18: Environments with `.bicepparam` (30 min)

### Concept
- A `.bicepparam` file starts with `using 'main.bicep'`, then sets values. The compiler checks them against the template.
- This keeps one template and moves the differences between environments into data.

| Setting | Dev | Prod |
|---|---|---|
| App Service plan | B1 | P1v3 |
| Instances | 1 | 2 |
| Zone redundant | No | Yes |
| Storage | LRS | ZRS |

### Lab

**18.1 Write `main.bicep`, `dev.bicepparam` and `prod.bicepparam`.**

```bash
mkdir -p "$P3/work/ex18"; cd "$P3/work/ex18"
```

**18.2 Preview both environments:**

```bash
az deployment group what-if -g $RG -f main.bicep -p dev.bicepparam
```

```bash
az deployment group what-if -g $RG -f main.bicep -p prod.bicepparam
```

**18.3 Deploy dev.** Deploy prod too if you'd like to see it working, but delete it soon after, because it runs 2 P1v3 instances. Prod can fail if the plan lands on hardware without zone support, as Part 2 explained:

```bash
az deployment group create -g $RG -f main.bicep -p dev.bicepparam
```

```bash
az group delete -n $RG --yes; az group create -n $RG -l $LOC
```

**✅ Answer:** Using Parts 1 and 2, explain what prod gets for its extra cost.

Compare with: [ex18](solutions/ex18/main.bicep), [dev](solutions/ex18/dev.bicepparam), [prod](solutions/ex18/prod.bicepparam)

---

## Lab 19: Zone-redundant scale set (90 min, creates 3 VMs)

### Concept
This is the Part 1 load balancer lab, written as code and using a scale set:

```
Internet → Public IP (Standard, zone-redundant)
             → Standard Load Balancer (health probe on port 80)
                 → VM Scale Set across zones 1, 2 and 3
```

The exercise says to delete an instance and watch it heal, but there are two different behaviours to see:
- **Deleting an instance** lowers the scale set's capacity, so Azure doesn't replace it. Redeploying your template restores the count.
- **An unhealthy instance** is replaced by **automatic repairs**, when the scale set has a health probe.

### Lab

**19.1 Write `main.bicep`,** and copy the web server config from Part 1:

```bash
mkdir -p "$P3/work/ex19"; cd "$P3/work/ex19"; cp ../../../part1/cloud-init.yaml .
```

Use `loadFileAsBase64('cloud-init.yaml')` for `customData`. Set `automaticRepairsPolicy` and `networkProfile.healthProbe` on the scale set.

```bash
az deployment group what-if -g $RG -f main.bicep -p sshPublicKey="$SSHKEY"
```

```bash
az deployment group create -g $RG -f main.bicep -p sshPublicKey="$SSHKEY"
```

**19.2 Test it.** Wait 2–3 minutes for cloud-init, then send 8 requests. You should see more than one zone:

```bash
PIP=$(az network public-ip show -g $RG -n pip-lb --query ipAddress -o tsv); for n in {1..8}; do curl -s --max-time 5 http://$PIP; done
```

**19.3 Delete an instance.** First list the instances, then replace `0` with an ID from your list:

```bash
az vmss list-instances -g $RG -n vmss-web --query "[].{Id:instanceId, Zone:zones[0]}" -o table
```

```bash
az vmss delete-instances -g $RG -n vmss-web --instance-ids 0
```

```bash
az vmss show -g $RG -n vmss-web --query sku.capacity
```

**19.4 Redeploy to restore the count,** then check the capacity again:

```bash
az deployment group create -g $RG -f main.bicep -p sshPublicKey="$SSHKEY"
```

```bash
az vmss show -g $RG -n vmss-web --query sku.capacity
```

**19.5 Make an instance unhealthy.** Stop the web server on one instance, again using an ID from your list. The probe now fails for it:

```bash
az vmss list-instances -g $RG -n vmss-web --query "[].{Id:instanceId, Zone:zones[0]}" -o table
```

```bash
az vmss run-command invoke -g $RG -n vmss-web --instance-id 1 --command-id RunShellScript --scripts "systemctl stop web"
```

**19.6 Watch the repair.** The site stays up on the other instances. Repairs wait for at least the 10-minute grace period and can take longer. Rerun this every few minutes until the instance list changes:

```bash
az vmss list-instances -g $RG -n vmss-web --query "[].{Id:instanceId, Zone:zones[0], State:provisioningState}" -o table
```

**19.7 Delete everything:**

```bash
az group delete -n $RG --yes; az group create -n $RG -l $LOC
```

**✅ Answer:**
1. Why does the template use `'${lb.id}/probes/probe-http'` on the scale set, but `resourceId()` inside the load balancer?
2. Why do Standard SKUs matter here? (You answered this in Part 1.)
3. What is the difference between redeploying and automatic repairs?

Compare with: [ex19](solutions/ex19/main.bicep)

---

## Lab 20: Complete mode (20 min, uses its own group)

### Concept
- **Incremental** is the default mode. It adds and updates resources, and leaves everything else alone.
- **Complete** also **deletes anything in the resource group that isn't in the template**. Never try it on a group holding anything you care about.
- For managing what gets deleted, Microsoft now points people to **deployment stacks** instead. **Template specs** store templates for reuse.

### Lab

**20.1 Write `v1.bicep`** with two storage accounts (`keep` and `drop`), and `v2.bicep` with only `keep`.

```bash
mkdir -p "$P3/work/ex20"; cd "$P3/work/ex20"; RG20=rg-bicep-complete-lab; az group create -n $RG20 -l $LOC
```

```bash
az deployment group create -g $RG20 -f v1.bicep
```

**20.2 Compare the two modes.** The incremental preview ignores `drop`, while the complete preview marks it for deletion:

```bash
az deployment group what-if -g $RG20 -f v2.bicep --mode Incremental
```

```bash
az deployment group what-if -g $RG20 -f v2.bicep --mode Complete
```

**20.3 Run it, confirm `drop` is gone,** then clean up:

```bash
az deployment group create -g $RG20 -f v2.bicep --mode Complete
```

```bash
az storage account list -g $RG20 --query "[].name" -o tsv
```

```bash
az group delete -n $RG20 --yes --no-wait
```

**✅ Answer:** What would happen if you ran a Complete deployment of `v2.bicep` against a shared group?

Compare with: [v1](solutions/ex20/v1.bicep), [v2](solutions/ex20/v2.bicep)

---

## Lab 21: Subscription scope (20 min)

### Concept
- `targetScope = 'subscription'` lets a template create resource groups.
- A resource must be deployed at the right scope, so storage goes in a module with `scope: rg`.

### Lab

**21.1 Write `main.bicep` and `storage.bicep`.** The commands use `az deployment sub`, and `-l` says where to keep the deployment's history:

```bash
mkdir -p "$P3/work/ex21"; cd "$P3/work/ex21"
```

```bash
az deployment sub what-if -l $LOC -f main.bicep -p location=$LOC
```

```bash
az deployment sub create -l $LOC -f main.bicep -p location=$LOC
```

```bash
az group delete -n rg-bicep-sub-lab --yes --no-wait
```

**✅ Answer:** What error do you get if you put the storage account directly in `main.bicep`, with no module? Try it.

Compare with: [ex21](solutions/ex21/main.bicep), [storage.bicep](solutions/ex21/storage.bicep)

---

## Lab 22: Key Vault secrets (45 min)

### Concept
- `existing` refers to a resource you don't deploy.
- `keyVault.getSecret('name')` passes a secret to a module's `@secure()` param, without its value ever being in your files.
- The vault needs `--enabled-for-template-deployment`, and the person deploying needs permission to use it.
- A logical SQL server with no database costs nothing, so this lab doesn't create one.

### Lab

**22.1 Create the vault and give yourself access to its secrets:**

```bash
mkdir -p "$P3/work/ex22"; cd "$P3/work/ex22"; KV=kv-part3-$RANDOM; echo $KV
```

```bash
az keyvault create -g $RG -n $KV -l $LOC --enabled-for-template-deployment true --enable-rbac-authorization true
```

```bash
az role assignment create --assignee $(az ad signed-in-user show --query id -o tsv) --role "Key Vault Secrets Officer" --scope $(az keyvault show -n $KV --query id -o tsv)
```

**22.2 Wait a minute for the role to apply, then store a random password.** It's never printed or saved in a file:

```bash
az keyvault secret set --vault-name $KV -n sql-admin-password --value "Aa1!$(openssl rand -hex 16)" --query name -o tsv
```

**22.3 Write `main.bicep` and `sql.bicep`.** `main.bicep` reads the vault with `existing`, and passes the secret to the `sql` module.

```bash
az deployment group what-if -g $RG -f main.bicep -p keyVaultName=$KV
```

```bash
az deployment group create -g $RG -f main.bicep -p keyVaultName=$KV
```

If Azure says it can't create SQL servers in your region, add `-p location=<another region>`.

**22.4 Confirm the secret isn't in the deployment history,** then clean up. The deleted vault stays recoverable for 90 days, at no cost:

```bash
az deployment group show -g $RG -n sql --query properties.parameters.adminPassword
```

```bash
az group delete -n $RG --yes; az group create -n $RG -l $LOC
```

**✅ Answer:** Why is `getSecret()` better than passing the password on the command line?

Compare with: [ex22](solutions/ex22/main.bicep), [sql.bicep](solutions/ex22/sql.bicep)

---

## Lab 23: Azure Verified Modules (45 min, creates a VM)

### Concept
- **AVM** modules are Microsoft-maintained building blocks, referenced as `br/public:avm/res/...:version`.
- Pin an exact version, so a module update can't change your deployment unexpectedly.
- You can publish your own modules in a private registry in Azure Container Registry.

### Lab

**23.1 Rebuild Lab 17 in `main.bicep`** with these modules. Hover over a module in VS Code to see its params, and read their pages on the [AVM site](https://aka.ms/avm):
- `br/public:avm/res/network/network-security-group:0.5.4`
- `br/public:avm/res/network/virtual-network:0.10.2`
- `br/public:avm/res/compute/virtual-machine:0.22.3`

```bash
mkdir -p "$P3/work/ex23"; cd "$P3/work/ex23"
```

```bash
az deployment group what-if -g $RG -f main.bicep -p sshPublicKey="$SSHKEY"
```

```bash
az deployment group create -g $RG -f main.bicep -p sshPublicKey="$SSHKEY"
```

```bash
az group delete -n $RG --yes
```

**✅ Answer:**
1. How many lines did you save compared with Lab 17?
2. What do you give up by using someone else's module?

Compare with: [ex23](solutions/ex23/main.bicep)

---

## Lab 24: CI/CD with GitHub Actions (90 min)

### Concept
- **OIDC federated credentials** let GitHub log in to Azure with short-lived tokens, so no password is stored in GitHub.
- The pipeline is **lint → what-if on pull requests → deploy on merge to main**.
- Each credential trusts one exact `subject`. Adding a GitHub `environment:` for approvals changes the subject to `repo:OWNER/REPO:environment:NAME`, so you'd need a credential for that too.

### Lab
This lab needs a GitHub account. Use a new **private** repository, so nobody else can run your workflow.

**24.1 Create an empty private repository on GitHub,** then set its name here:

```bash
REPO=OWNER/REPO; echo $REPO
```

**24.2 Create the resource group and an identity** that can only touch that group:

```bash
RG24=rg-bicep-cicd-lab; az group create -n $RG24 -l $LOC
```

```bash
SUB=$(az account show --query id -o tsv); TENANT=$(az account show --query tenantId -o tsv); APPID=$(az ad app create --display-name gh-bicep-lab --query appId -o tsv); echo "$APPID"
```

```bash
az ad sp create --id $APPID
```

```bash
az role assignment create --assignee $APPID --role Contributor --scope /subscriptions/$SUB/resourceGroups/$RG24
```

**24.3 Trust your repository,** once for merges to main and once for pull requests:

```bash
az ad app federated-credential create --id $APPID --parameters "{\"name\":\"main\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:$REPO:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"
```

```bash
az ad app federated-credential create --id $APPID --parameters "{\"name\":\"pr\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:$REPO:pull_request\",\"audiences\":[\"api://AzureADTokenExchange\"]}"
```

**24.4 Add 3 secrets in GitHub.** Go to **Settings → Secrets and variables → Actions**, and add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` with these values:

```bash
echo "client=$APPID tenant=$TENANT subscription=$SUB"
```

**24.5 Write the three files** in a new folder outside this project: `infra/main.bicep`, `infra/bicepconfig.json` and `.github/workflows/bicep.yml`. Then push them:

```bash
mkdir -p "/d/LEARN BY MYSELF/bicep-cicd-lab"; cd "/d/LEARN BY MYSELF/bicep-cicd-lab"
```

```bash
git init -b main; git add .; git commit -m "Add Bicep pipeline"; git remote add origin https://github.com/$REPO.git; git push -u origin main
```

Watch the **Actions** tab. The lint and deploy jobs should pass, and the storage account should appear in the group.

**24.6 Open a pull request.** On a new branch, add `tags: { lab: 'cicd' }` to the storage account, push it and open a pull request. Read the `what-if` output in the job log, then merge it and watch it deploy.

**24.7 Break the lint step.** On another branch, add an unused param. The pull request should fail at lint, before it reaches Azure, because `bicepconfig.json` makes that rule an error.

**24.8 Clean up** Azure, including the identity:

```bash
az group delete -n $RG24 --yes --no-wait
```

```bash
az ad app delete --id $APPID
```

**✅ Answer:**
1. Why is OIDC safer than storing a client secret in GitHub?
2. Why does the role assignment target the group rather than the subscription?
3. What stops a pull request from deploying?

Compare with: [workflow](solutions/ex24/.github/workflows/bicep.yml), [main.bicep](solutions/ex24/infra/main.bicep), [bicepconfig.json](solutions/ex24/infra/bicepconfig.json)

---

## Final cleanup

Confirm that only `bndzSSHKey` is left:

```bash
az group list --query "[].name" -o tsv
```

---

## Self-check
You've finished Part 3 when you can answer these without looking anything up:

1. What are the sections of an ARM template, and what does Bicep compile to?
2. How do Incremental and Complete mode differ, and which one is dangerous?
3. What does `what-if` tell you, and when should you run it?
4. How do symbolic references remove the need for `dependsOn`?
5. How do you write a loop, a condition and a module?
6. What does a `.bicepparam` file do, and why is it better than copying templates?
7. What are the four deployment scopes, and how do you create a resource group from Bicep?
8. How does `getSecret()` keep a password out of your code and deployment history?
9. What is AVM, and why do you pin a module's version?
10. How do OIDC credentials work, and what are the stages of a safe Bicep pipeline?
