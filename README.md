# ai-skills 🧠

[English](./README.md) · [简体中文](./README.zh-CN.md)

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/YuAICode/ai-skills?style=social)](https://github.com/YuAICode/ai-skills/stargazers)
[![markdownlint](https://img.shields.io/badge/lint-markdownlint-brightgreen?logo=markdown)](./commit-guard-zh)

**25 practical, battle-tested skills for [Claude Code](https://www.claude.com/product/claude-code).** Every skill ships with its own offline tests, and the whole collection is self-linted by [`skill-doctor`](./skill-doctor) — not an untested AI-generated dump. Chinese-first, but most skills are language- and stack-agnostic.

Each skill is a self-contained folder with a `SKILL.md` — drop it into `~/.claude/skills/` and Claude picks it up.

## ✨ Why this collection

- **Tested.** Deterministic logic lives in small `bash` scripts with `tests/run.sh` (offline, zero deps). Hundreds of assertions across the collection.
- **Self-linting.** `skill-doctor` validates every skill's structure; CI-able.
- **Honest.** Skills that need an external tool (aws/mysql/markdownlint…) degrade gracefully when it's missing — they never crash your toolchain.
- **Easy to extend.** `skill-scaffold` generates a new skill (SKILL.md + README + badges + tests) in one command.

## 📦 Skills

### General-purpose (any stack)

| Skill | What it does | Trigger |
| --- | --- | --- |
| [error-explain-zh](./error-explain-zh) | Paste any-language error/stacktrace → Chinese root cause + actionable fixes | "explain this error" |
| [commit-guard-zh](./commit-guard-zh) | Pre-commit/push guard (secret scan / GORM×MySQL / main-branch protection) + Chinese commit | "ready to commit" / git hook |
| [pr-desc-zh](./pr-desc-zh) | Generate a Chinese PR description (motivation / changes / tests / blast radius) from the diff | "write a PR" |
| [changelog-zh](./changelog-zh) | Conventional commits → Chinese CHANGELOG / release notes | "generate changelog" |
| [standup-zh](./standup-zh) | Git activity → Chinese daily/weekly standup report | "write standup" |
| [readme-init](./readme-init) | Scan a project (stack/structure/scripts) → generate or refresh its README | "generate README" |
| [gitignore-doctor](./gitignore-doctor) | Find tracked / unignored junk files, suggest `.gitignore` entries | "check gitignore" |
| [dep-audit](./dep-audit) | Scan go/npm/pip/flutter manifests for outdated deps, Chinese summary | "check dependencies" |
| [env-doctor](./env-doctor) | Pre-run env check: missing `.env`, keys missing vs `.env.example` | "check env" |
| [test-gen-zh](./test-gen-zh) | Detect the test framework, generate tests for a function/file | "generate tests" |
| [branch-cleaner](./branch-cleaner) | List merged/stale local branches for safe (confirmed) cleanup | "clean up branches" |
| [conflict-resolver-zh](./conflict-resolver-zh) | Explain merge/rebase conflicts in Chinese, guide the resolution | "help with conflicts" |
| [license-picker](./license-picker) | Pick + generate an open-source LICENSE (MIT/ISC/BSD/Unlicense; Apache/GPL guidance) | "add a LICENSE" |
| [json-yaml-doctor](./json-yaml-doctor) | Validate / format / explain JSON·YAML·TOML with Chinese error locations | "validate this json" |
| [cron-regex-buddy](./cron-regex-buddy) | Explain or generate cron expressions & regexes in Chinese | "explain this cron" |
| [curl-buddy](./curl-buddy) | Build / explain curl & HTTP requests, field-by-field + safety notes | "explain this curl" |
| [doc-sync](./doc-sync) | After code changes, surface docs that may be stale and need updating | "check doc sync" |
| [slack-to-spec](./slack-to-spec) | Distill a Slack channel discussion into a landable requirement spec | `/slack-to-spec <channel>` |
| [source-to-spec](./source-to-spec) | PDF / docs / meeting notes → landable requirement spec | "turn this doc into a spec" |

### Meta-tooling (for building the collection)

| Skill | What it does | Trigger |
| --- | --- | --- |
| [skill-scaffold](./skill-scaffold) | Generate a new skill's standard skeleton (SKILL.md + badge README + bin/tests) | "scaffold a skill" |
| [skill-doctor](./skill-doctor) | Lint a skill folder against the collection's conventions before publishing | "lint a skill" |

### Stack-specific (Go / AWS / MySQL)

| Skill | What it does | Trigger |
| --- | --- | --- |
| [lambda-logs-zh](./lambda-logs-zh) | Pull AWS Lambda CloudWatch errors, cluster by frequency + Chinese root-cause summary | "check lambda errors" |
| [go-migration-guard](./go-migration-guard) | Heuristic check: do GORM model changes lack a matching migration? | "check migration" |
| [sql-explain-zh](./sql-explain-zh) | Read a slow-query `EXPLAIN`, give Chinese tuning advice (index/rows/filesort) | "explain this SQL" |
| [claude-code-zh](./claude-code-zh) | Localize Claude Code: Chinese replies + per-tool Chinese tooltips (toggleable) | "localize Claude Code" |

## 🚀 Install

Clone, then copy any skill into your Claude Code skills directory:

```bash
git clone https://github.com/YuAICode/ai-skills.git
cd ai-skills

# A plain skill — just copy the folder, then restart Claude Code
cp -r error-explain-zh ~/.claude/skills/

# Project-scoped instead of global: copy into <project>/.claude/skills/
```

Some skills ship an installer or extra tooling (e.g. `commit-guard-zh` installs git hooks, `claude-code-zh` configures Chinese replies) — see each skill's own README.

**Requirements:** `bash` + `python3` (used by a few scripts to edit JSON safely). Claude Code v2.1.113+.

### Verify

After restarting Claude Code, type `/` and look for the skill, or `ls ~/.claude/skills/`.

## 🤝 Contributing

Adding a skill is one command:

```bash
bash skill-scaffold/bin/new-skill.sh my-skill "what it does (with trigger words)" --bin
# fill in SKILL.md + bin + tests, then:
bash skill-doctor/bin/lint-skill.sh my-skill
```

PRs welcome — every new skill should pass `skill-doctor` and include `tests/run.sh` if it has scripts.

## 📄 License

[MIT](./LICENSE)
