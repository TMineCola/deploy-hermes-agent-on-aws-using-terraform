# CLAUDE.md

## Project

Terraform IaC deploying Hermes Agent (Telegram AI assistant) on AWS EC2 with Amazon Bedrock.

File structure: see `README.md`.

## Key Constraints

- Hermes runs as unprivileged `hermes` user, never root
- All configurable values must be in `variables.tf` with defaults
- Secrets in SSM Parameter Store only, never in .tf or user_data
- Feature toggles use `count = var.enable_x ? 1 : 0`, reference with `[0]`

## Documentation

- Bilingual: English (`docs/en/`) and Traditional Chinese (`docs/zh-TW/`)
- Both versions must stay in sync with each other and with Terraform code
- Technical terms kept in English even in Chinese docs (e.g., VPC Endpoint, IAM Role)
- Chinese docs add Chinese explanations alongside English terms (e.g., "EC2 零入站規則 (Telegram 採取 Long Polling)")

## user_data.sh

- Terraform `templatefile()`: TF vars = `${var}`, bash vars = `$var` (no `$$` needed)
- `$${...}` only for literal `${...}` in output (CloudWatch Agent's `${aws:InstanceId}`)
- Install Hermes as hermes user: `su - hermes -c '...'`
- Gateway: `printf 'n\ny\n' | hermes gateway install --system --run-as-user hermes`
- Always `chown -R hermes:hermes /home/hermes/.hermes` AFTER gateway install, BEFORE start
- Config via `printf` not heredoc (avoids templatefile interpolation conflicts)

## Pitfalls

- AL2023 needs `dnf clean all` before install (cache corruption)
- AL2023 doesn't ship `git` — install it before Hermes installer
- IAM policy propagation: ~60s delay after updates
- S3/Athena: need `force_destroy = true` for clean teardown
- Lifecycle rules: always include empty `filter {}` block
