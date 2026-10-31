# Azure fundamentals: learning plan and labs

A hands-on plan for learning Azure regions, availability zones, service tiers and infrastructure as code with Bicep. The full plan and suggested pace are in [overview.md](overview.md).

| Part | Topic | Guide |
|---|---|---|
| 1 | Regions and availability zones | [part1/README.md](part1/README.md) |
| 2 | Service tiers | [part2/README.md](part2/README.md) |
| 3 | Infrastructure as Code (ARM and Bicep) | [part3/README.md](part3/README.md) |
| 4 | Capstone: a multi-region, zone-redundant web app | [part4/README.md](part4/README.md) |

## Before you run anything

- **The labs create real Azure resources that cost money.** Set up the budget alert first, and delete each lab's resources when you finish it.
- **The Part 3 Bicep solutions and the Part 4 snippets haven't been compiled or deployed yet.** Part 3's setup includes a step that compiles the solutions.
- **Part 3 and Part 4 use the author's own SSH key and resource group names,** such as `bndzSSHKey`. Replace them with your own.
- **Never commit secrets.** The labs keep passwords in Key Vault, not in files.
