# Contributing to the Alien skills

This repository is public. Everything you commit here is visible to anyone.

## Layout

- One directory per skill under `skills/`, named like the skill (`lowercase-with-hyphens`).
- `SKILL.md` has frontmatter (`name`, `description`, `license`, optional `compatibility` and
  `metadata`) and a body under 300 lines. The `description` says what the skill does and when to
  use it, with the words a user would type.
- Detailed material goes in `references/*.md`, one level deep, linked from `SKILL.md` with a
  relative path and loaded only when the workflow reaches it.
- Add a new skill to `.claude-plugin/marketplace.json` and the table in `README.md`.

## What belongs in a skill

- Decision rules, workflows, checklists, and the mistakes that real integrations made.
- Short, type-checked code examples where the exact API matters.
- Links to the docs as Markdown: `https://alien.dev/docs/<path>.md`. Do not copy reference
  material (resource options, CLI flags, REST fields) into a skill. It goes stale; the docs do not.

## What does not belong

- Customer or prospect names, or details that identify a customer's architecture. Use generic
  products ("a document-processing service", "an email API") and `customer-1`.
- Internal tooling, private repositories, or engineering notes about Alien's own implementation.
- Features that are not in the docs. If the docs do not describe it, the skill does not promise it.
- Comparisons between ways of running Alien. Describe one product.

## Writing

Plain, direct, second person. Short sentences. Define a term the first time a file uses it.
No em dashes. Avoid filler words: easy, simple, simply, just, really, very, seamless, powerful,
robust, leverage. Say "the deployment" or "the smallest piece", not "run your product in the
customer's cloud".

## Verifying changes

1. Type-check every TypeScript snippet against the published `@alienplatform/*` packages: copy
   the snippet into a scratch project with those packages installed and run `npx tsc --noEmit`.
2. Check every CLI command and flag against `alien <command> --help` for the current release.
3. Run `scripts/check.sh` (spec basics, references, em dashes). Run `scripts/check.sh --links`
   before a release to confirm every docs URL resolves.
4. Try the skill: install it locally, give an agent a realistic request in a sample repository,
   and read what it produces. A skill that reads well but leads the agent astray is a bug.
