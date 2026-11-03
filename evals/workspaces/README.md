These folders are not templates. They are the stand-in projects the prompts in
`evals/triggers.json` run against: `scripts/eval-triggers.sh --run` copies `base/`
fresh for every prompt, then the case's optional `"workspace"` overlay on top
(`docker`, `deploy-workflow`, `scripts`, `monorepo`, `terraform`, `spa`), so a
prompt that says "this Makefile" has a Makefile to look at. Keep them tiny.
