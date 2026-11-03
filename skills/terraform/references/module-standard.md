# Module standard and the procedure for new resources

Read this before writing or changing a module, and whenever a task needs an AWS resource the templates do not cover. The modules in `assets/modules/` are worked examples of every rule here.

## Shape of a module

- Three files: `main.tf` (resources, data sources, locals), `variables.tf`, `outputs.tf`. Split `main.tf` only when it passes roughly 300 lines.
- No `provider` blocks, no `terraform {}` version block, no backend, no hard-coded region, account ID or ARN inside a module. Get them from `data "aws_region"`, `data "aws_caller_identity"` and `data "aws_partition"`. Use `data.aws_region.current.region` (the `.name` attribute is deprecated in provider 6).
- Modules never read `terraform.tfvars` or environment names. They take inputs and return outputs.

## Variables

- Every variable has `description` and `type`. Use `map(object({... optional()}))` for sets of similar things (rules, tasks, listeners) and drive them with `for_each`.
- Give a default only when it is a sensible choice for any caller (volume type `gp3`, encryption `true`). A value that differs by environment has no default in the module either if forgetting it would be dangerous; make it required.
- Add `validation` for anything constrained: allowed enums, ranges, cross-field rules (`max >= min`), exactly-one-of inputs.
- Always accept `tags` (`map(string)`, default `{}`) and apply it to every taggable resource, with `merge(var.tags, { Name = ... })` where AWS shows a Name.
- Naming: `name` for the primary identifier, `<thing>_ids`/`<thing>_arns` for lists, no environment names.

## Resources

- `for_each` over a map keyed by a stable name. `count` only for an on/off toggle (`count = var.enabled ? 1 : 0`). Never `count` over a list that can be reordered.
- Prefer the standalone rule resources over inline blocks where AWS offers them (`aws_vpc_security_group_ingress_rule`, not an inline `ingress` block), so rules can be added and removed without replacing the parent.
- Build IAM JSON with `data "aws_iam_policy_document"`; build other JSON with `jsonencode`. Give each statement a `sid`. Scope `resources` to the specific ARNs; use `"*"` only for actions that do not support resource-level permissions, and say so in a comment.
- Comment the **why** of anything non-obvious (an `ignore_changes`, a `depends_on`, an odd port range), the way the shipped modules do. A rule that exists because of a failure keeps its story.
- `depends_on` only for dependencies Terraform cannot see (a listener that must exist before a service uses its target group). Not as a habit.
- No `local-exec`/`remote-exec` provisioners, no `null_resource`, no `external` data sources.

## Secure defaults, by resource family

| Family | Default |
|---|---|
| Compute | IMDSv2 required (`http_tokens = "required"`), encrypted root volume, no public SSH, access through Session Manager with the SSM managed policy |
| Storage (S3, EBS, ECR, logs) | encryption on, versioning for S3, public access blocked, ECR tags immutable and scan on push, a lifecycle or retention policy |
| Network | no `0.0.0.0/0` ingress except HTTP/HTTPS on a load balancer; internal traffic references security groups, not CIDRs; `drop_invalid_header_fields` on ALBs |
| IAM | roles per workload, no inline `*` actions, OIDC federation instead of access keys, `iam:PassRole` limited with `iam:PassedToService` |
| Data stores | deletion protection on, final snapshot, encrypted, not publicly accessible, credentials from Secrets Manager |
| Deletion | `deletion_protection` / `force_delete` / `prevent_destroy` on stateful resources in production, controlled by a variable |

## Lifecycle patterns

| Situation | Pattern |
|---|---|
| Another system owns an attribute (CI registers task definition revisions, autoscaling owns `desired_capacity`, a managed AMI parameter moves) | `lifecycle { ignore_changes = [attr] }` with a comment naming who owns it |
| A dependent object must be recreated when its parent is | `replace_triggered_by` |
| A resource with a unique name must be replaced without downtime | `create_before_destroy` plus `name_prefix` or a changing suffix |
| Losing it would lose data | `prevent_destroy = true`, switched by a variable so non-production can be torn down |

## Outputs

Output only what another module or an environment needs, with a `description`. Environments re-export the values people look up after an apply (URLs, ARNs, names the deploy workflow needs). Never output a secret.

## Procedure: a resource or pattern the templates do not cover

1. **Look for what exists.** Read `assets/modules/` and the project's `modules/`. Extend or compose an existing module when the new resource belongs with it; otherwise make a new one. A module should own one coherent thing (an S3 bucket with its policy and public-access block; not "all storage").
2. **Read the docs for the locked provider version, not memory.**
   - Find the version: `grep version environments/production/.terraform.lock.hcl`.
   - Read `https://registry.terraform.io/providers/hashicorp/aws/<version>/docs/resources/<resource>` and the data-source page if one exists.
   - Dump the exact schema offline: `terraform providers schema -json | python3 -c '...'` and check argument names, required vs optional and `deprecated` flags. Treat deprecated arguments as unusable.
   - Read the AWS service documentation for limits, naming rules and any prerequisite (quotas, service-linked roles, one-per-account resources, regional availability).
   - If the docs and the schema disagree, trust the schema, and note it.
3. **Check for known traps.** Search the provider's issue tracker for the resource name plus "replace", "perpetual diff" or "ignore_changes"; many resources have attributes that drift and need `ignore_changes`.
4. **Write the module** to the rules above. Start from the closest asset module and copy its structure and comment style.
5. **Wire it in all three environments.** Add the module block to `environments/*/main.tf` identically, its variables to every `variables.tf` (no defaults for environment-specific values), its values to every `terraform.tfvars`, its useful outputs to `outputs.tf`.
6. **Prove it.** `make check`, then `plan` per environment. For anything that changes IAM, networking exposure or costs, show the plan summary to the user before they apply.
7. **Record it.** Add the facts you checked to `references/sources.md` (resource, provider version, doc URL, date). If the module is general enough to be a template, offer to add it to this skill through `skill-authoring`.

## When the request is outside AWS or outside Terraform

Only AWS is covered. For another provider (Google Cloud, Azure, Cloudflare) or for Kubernetes/Helm, say it is not yet covered here (see the repo `roadmap.md`), follow this standard where it applies, and do not invent a template. Pulumi, CDK and CloudFormation are out of scope.

## Anti-patterns

- A registry module (`source = "terraform-aws-modules/..."`) — hand-write it.
- Provider config or `required_providers` inside a module.
- A default in an environment's `variables.tf` for a per-environment value (the cause of "which value is actually used?").
- `terraform apply -auto-approve`, or applying from a plan that was not reviewed.
- `data "aws_ami"` with `most_recent = true` and no `ignore_changes`, which replaces instances on every upstream release.
- A hard-coded AMI ID, account ID, ARN or region.
- Putting a secret in `terraform.tfvars` or in state through a resource argument when a runtime reference would do.
