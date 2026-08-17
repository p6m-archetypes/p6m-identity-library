# p6m-identity-library

The single implementation of the identity prompt surface every p6m service archetype asks for.

```lua
local identity = require("p6m-identity")
identity.prompt(context)                    -- full shape: project, solution, entity
identity.prompt(context, { entity = false }) -- shapes that generate no domain code
```

## What it asks

| Key | What it becomes |
|---|---|
| `project_name` | the repository and project directory, the container image, the `PlatformApplication` name, the Tilt resource, `OTEL_SERVICE_NAME` |
| `solution_name` | the namespace prefix — the platform operator derives solution and environment back out of `{solution}-{application}-{env}`, which is what lets `Shared` resources be shared across a solution |
| `entity_name` | the sample CRUD entity the generated API exposes; **defaulted** from `project_name` |

Each is expanded through `Cases.programming()` plus a Title variant, so templates say
`{{ ProjectName }}`, `{{ entity-name }}`, `{{ project_title }}` without reformatting anything by
hand. `repo_name` and `github_owner` are derived, never asked.

## What it deliberately does not ask

No author identity, no org × solution split, no prefix × suffix decomposition. Measured across
the fleet before this library was written: `author_name`/`author_email` reached four files
(rust's `Cargo.toml`), and `org_name`/`solution_name` reached no template at all — only their
derived combination did. Two prompts existed to build one string, and `prefix_name` was doing two
unrelated jobs at once.

Conventions are not lost by asking less. Archetect resolves answers `config → -A files → -a
flags`, and an answered key suppresses its prompt entirely — so an org convention supplied by
`p6m-catalog` or injected by Ybor Studio costs zero prompts and cannot be typed wrong, which a
free-text prefix never guaranteed.

## The one rule this library owns

`entity_default(project_kebab)` strips a trailing **type qualifier** — the token that says what
kind of thing the service is rather than what it is about:

```
billing-service       → billing            /api/v1/billings
user-details-service  → user-details       /api/v1/user-detailss
payment-gateway       → payment            /api/v1/payments
order-management      → order-management   /api/v1/order-managements    (nothing to strip)
customer              → customer           /api/v1/customers            (single token)
```

A curated vocabulary (`M.TYPE_TOKENS`), deliberately, rather than "split on the last hyphen":
`order-management` and `payment-gateway` are both two tokens and only one of them ends in a type
qualifier. The default exists to save a keystroke, not to decide the domain — `entity_name` is a
real answer, and a caller who names it gets that name.

## Why this repo has a suite when no other library does

The 42 resource libraries, the 6 CI libraries and the platform-manifests library carry no proofs;
they are held transitively by the archetypes that compose them. This one owns a **rule**, and a
rule with no direct proof is a rule that drifts.

It matters more than usual here, because the identity contract has a second reader:
`p6m.identity` in [prova-p6m-standards](https://github.com/p6m-archetypes/prova-p6m-standards),
the oracle every archetype's suite asserts against. A prompt library and an oracle that each
*derive* the same names is a drift machine — so **this library derives, and the oracle takes**.
`p6m.identity{ project = ..., entity = ... }` accepts both as explicit inputs and computes no
names of its own beyond casing, and casing is already one implementation across both tools
(`prova.str` calls archetect's own inflections). That leaves `entity_default` as the entire
p6m-specific derivation in the fleet, proven here and nowhere else.

Consequently this repo depends on no plugin: cross-checking against `p6m.identity` would recreate
the second implementation the design removes.

## Proving a library that renders nothing

A prompt library produces no files, so there is nothing to observe black-box — which is why none
of the fleet's libraries has ever had a suite. `proofs/fixtures/probe` is a throwaway archetype
that composes this library and renders every derived key to one YAML file; the suite renders the
probe and reads that. The contract is held on rendered output rather than by reaching into the
module, and the pattern generalizes to any prompt library.

```
prova            # render the probe across the name-shape table, assert the derived keys
```

The suite is mutation-tested: replacing the vocabulary check with a naive last-hyphen split, or
removing the strip entirely, or dropping a casing variant, each turn it red.

## Related

- [prova-p6m-standards](https://github.com/p6m-archetypes/prova-p6m-standards) — `docs/standards.md`
  S1 states the identity contract; the `p6m` plugin holds every archetype to it.
- [p6m-catalog](https://github.com/p6m-archetypes/p6m-catalog) — the customer-agnostic answer
  defaults that ride on top of this surface.
