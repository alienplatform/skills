# Alien agent skills

Skills that help a coding agent design and build software that runs outside your cloud with
[Alien](https://alien.dev): close to your customers' data, private systems, and hardware, while
the rest of your product stays SaaS.

| Skill | Use it to |
|---|---|
| [`alien-architecture`](skills/alien-architecture/SKILL.md) | Decide what to run outside your cloud. Turns a customer requirement ("our data can't leave our account", "our cluster isn't reachable from the internet", "checks must not add latency") into 2-3 candidates, from only the customer's key or bucket to an agent, a cache, the part that touches the data, or the whole product, recommends one, and writes `docs/alien-architecture.md` for approval. No code changes. |
| [`alien-integration`](skills/alien-integration/SKILL.md) | Implement the approved split: `alien.ts`, data-plane code with `@alienplatform/sdk`, local runs with `alien dev`, tests, CI releases, setup links and status in your backend, the customer runbook, and validation in a real cloud. |

They cover every Alien path: single-tenant deployments in your cloud, bring your own cloud (BYOC),
customer-managed keys, local models, on-prem Kubernetes and Linux machines, and Remote Operator
added to an install you already ship.

## Install

With the [skills CLI](https://github.com/vercel-labs/skills), for Claude Code, Codex, and
other agents:

```bash
npx skills add alienplatform/skills
npx skills add alienplatform/skills --skill alien-architecture   # one skill only
```

As a Claude Code plugin:

```bash
claude plugin marketplace add alienplatform/skills
claude plugin install alien@alien-skills
```

Or copy a folder from `skills/` into your agent's skills directory (for example
`~/.claude/skills/` or `.agents/skills/` in your repository).

## Use

From your repository, ask your agent:

```text
A customer requires that their documents never leave their AWS account.
Use the alien-architecture skill to propose what should run there, then stop for my review.
```

After you approve `docs/alien-architecture.md`:

```text
Implement docs/alien-architecture.md with the alien-integration skill.
Run it locally first. Ask before releasing, creating customer deployments, or changing CI.
```

The skills fetch current reference material from the Alien docs as Markdown
(`https://alien.dev/docs/<page>.md`, index at `https://alien.dev/llms.txt`), so API details stay
up to date. The skills themselves hold decision rules and checklists.

## Layout

```text
skills/
  alien-architecture/
    SKILL.md
    references/        inventory, what to run remotely, boundary checks, decision record template
  alien-integration/
    SKILL.md
    references/        profiling, alien.ts, reaching a deployment, local dev and tests,
                       releases and CI, control-plane integration, standalone paths,
                       patterns, customer runbook, validation
.claude-plugin/marketplace.json
scripts/check.sh       spec and link checks
```

Skills follow the [Agent Skills specification](https://agentskills.io/specification).

## License

[Apache-2.0](LICENSE)
