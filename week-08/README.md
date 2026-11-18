# Week 8 — Infrastructure as Code (Terraform)

I rebuilt Week 5's VPC shape in code instead of clicking the console wizard. Same idea — 2 AZs, 2 public + 2 private subnets, one NAT — but Terraform creates and tears it down from `main.tf`.

## What I declared

[`main.tf`](main.tf) uses the public module `terraform-aws-modules/vpc/aws` `5.8.1`:

| Setting | Value |
|---|---|
| Name | `training-vpc-tf` |
| CIDR | `10.1.0.0/16` (not Week 5's `10.0.0.0/16`, so the ranges don't collide) |
| AZs | `us-east-1a`, `us-east-1b` |
| Public | `10.1.1.0/24`, `10.1.2.0/24` |
| Private | `10.1.101.0/24`, `10.1.102.0/24` |
| NAT | one (`single_nat_gateway = true`) |

`terraform apply` created 19 resources. The VPC console showed `training-vpc-tf` next to the default VPC.

## Terms

| Term | What it means |
|---|---|
| **Infrastructure as Code (IaC)** | Describe servers, networks, and related AWS pieces in files, then create/update/destroy them with a tool instead of only clicking the console |
| **Declarative** | Say *what* you want (a VPC named `training-vpc-tf` with these CIDRs). Terraform figures out *how* to get there |
| **Imperative** | Say *how* step by step (create VPC, then subnet, then route…). The console and raw AWS CLI feel more like this |
| **Provider** | Plugin that talks to a cloud API. Here: `hashicorp/aws` |
| **Module** | Reusable package of Terraform resources. I used `terraform-aws-modules/vpc/aws` instead of writing every subnet by hand |
| **State** (`terraform.tfstate`) | Terraform's local record of what it owns in AWS and each resource's id |
| **Drift** | AWS reality no longer matches state/config — usually because someone edited or deleted a managed resource in the console |
| **Lock file** (`.terraform.lock.hcl`) | Pins provider versions so `init` on another machine gets the same plugins. Safe to commit |

## plan, apply, destroy

| Command | What it does |
|---|---|
| `terraform init` | Downloads providers/modules into `.terraform/` (not committed) |
| `terraform plan` | Compares config + state to real AWS and **prints** the diff. Creates nothing. |
| `terraform apply` | Makes AWS match the config (after I type `yes`) |
| `terraform destroy` | Deletes everything Terraform tracks in state |

`plan` is the safety check. I read it before every `apply`.

## AWS Console vs Terraform

| | AWS Console | Terraform |
|---|---|---|
| **How you work** | Click through wizards and forms | Edit `.tf` files, then `plan` / `apply` |
| **Repeatable?** | Hard — easy to miss a checkbox next time | Yes — same `main.tf` rebuilds the same shape |
| **Reviewable?** | Screenshots / memory | Diff in git; teammates can read the intent |
| **Teardown** | Delete pieces in the right order by hand | `terraform destroy` tears down what state tracks |
| **Best when** | Learning a service the first time, one-off debug, looking at a live resource map | Anything you will rebuild (labs, shared envs, Week 12 capstone) |
| **Risk** | Silent drift; forgotten NAT / EIP keep billing | Bad `apply` without reading `plan`; committing state secrets |

**Which is better?** For this internship track, **Terraform is better for real infrastructure** once I know what I'm building — Week 5's console VPC taught the ideas; Week 8's code is how I'd ship that network again. The console stays useful to **verify** (`training-vpc-tf` showed up) and to **explore**, but once a resource is in state I treat the console as read-only for it so I don't create drift.

## Why state matters

Terraform keeps a local memory file, `terraform.tfstate`, of every resource it created and that resource's AWS id. Without state, Terraform cannot tell "already exists" from "needs creating."

I proved drift on purpose:

1. `terraform plan` → **No changes**
2. `terraform state rm 'module.vpc.aws_subnet.public[1]'` — removed the subnet from state only; it stayed in AWS
3. `terraform plan` → wanted to **create** that subnet again (and replace its route-table association)
4. `terraform import 'module.vpc.aws_subnet.public[1]' subnet-…` → put it back in state
5. `terraform plan` → **No changes** again

If a managed resource is deleted in the console, the fix is the same idea in reverse: `terraform state rm` if it is truly gone, or `import` if it still exists. Once something is in state, I treat the console as read-only for it.

State can hold identifiers and other sensitive values, so `*.tfstate`, `.terraform/`, and `*.tfvars` stay out of git (already in `.gitignore`). I do commit `.terraform.lock.hcl` so provider versions stay pinned.

## Cleanup

```bash
cd week-08
terraform destroy   # type yes
```

You'll know it worked when: `Destroy complete!` and `training-vpc-tf` is gone from the VPC console. NAT and its Elastic IP go with it.
