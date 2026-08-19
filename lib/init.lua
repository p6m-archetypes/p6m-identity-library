-- p6m-identity-library main module.
--
-- Consumers mount this archetype with `library: true` under the catalog key `p6m-identity` and
-- reach this module via `require("p6m-identity")`. The archetype's own shim reaches it via
-- `require("lib")`.
--
-- Contract
-- ────────
-- THE single implementation of the p6m identity prompt surface. A p6m service archetype asks for
-- a project name, a solution slug, and (for shapes that generate a CRUD surface) an entity name.
-- It does NOT ask for author identity, an org × solution split, or a prefix × suffix
-- decomposition: nothing the archetypes render reads them, and two of the three were prompts that
-- existed only to build a third string.
--
--   project_name   the repository, the project directory, the container image, the
--                  PlatformApplication name, the Tilt resource, OTEL_SERVICE_NAME
--   solution_name  the namespace prefix — the platform operator derives solution and environment
--                  back out of `{solution}-{application}-{env}`, which is what lets Shared
--                  resources be shared across a solution
--   entity_name    the sample CRUD entity the generated API exposes; DEFAULTED from project_name
--
-- Why this library exists
-- ───────────────────────
-- One rule, one home. The identity contract has a second reader — `p6m.identity` in
-- prova-p6m-standards, the oracle every archetype's suite asserts against — and a prompt library
-- and an oracle that each DERIVE the same names is a drift machine. So the split is: this library
-- derives; the oracle takes. `p6m.identity{ project = ..., entity = ... }` accepts both as
-- explicit inputs and computes no names of its own beyond casing (and casing is already one
-- implementation across both tools — prova.str calls archetect's own inflections).
--
-- That leaves `entity_default` below as the entire p6m-specific derivation in the fleet, which is
-- why it is a plain exported function with a suite of its own rather than a detail of `prompt`.

local M = {}

-- Trailing tokens that qualify a service's TYPE rather than naming its subject. `billing-service`
-- is a service *about* billing, so its CRUD entity is `Billing` and its REST collection is
-- `/api/v1/billings` — not `/api/v1/billing-services`. Standards S2 fixes this direction:
-- the GraphQL type is "entity-named, not service-named".
--
-- A curated vocabulary, deliberately, rather than "split on the last hyphen": `order-management`
-- and `payment-gateway` are both two tokens and only one of them ends in a type qualifier.
M.TYPE_TOKENS = {
    "service", "orchestrator", "adapter", "router", "gateway",
    "api", "worker", "job", "daemon", "processor",
}

local function is_type_token(token)
    for _, known in ipairs(M.TYPE_TOKENS) do
        if token == known then return true end
    end
    return false
end

--- The one derivation: the sample CRUD entity, defaulted from the project name.
---
--- Strips a trailing type qualifier when there is one to strip, and only when something would be
--- left behind — so a single-token project name keeps its whole name (`customer` → `customer`,
--- never the empty string), and an unqualified compound keeps both tokens (`order-management` →
--- `order-management`).
---@param project_kebab string kebab-case project name
---@return string kebab-case entity name
function M.entity_default(project_kebab)
    local last = project_kebab:match("[^%-]+$")
    if last and is_type_token(last) and project_kebab:find("%-") then
        return project_kebab:sub(1, #project_kebab - #last - 1)
    end
    return project_kebab
end

--- Prompt the p6m identity surface.
---
--- `opts.entity` (default true) asks for the sample CRUD entity. Pass `false` for shapes that
--- generate no domain code — the platform overlay, and the basic service whose only route is a
--- stub identity endpoint — so a prompt whose answer nothing reads cannot survive (standards E2).
---@param opts { entity: boolean? }?
--- The project's own names: what it is called and what its sample entity is called.
---
--- Split from the solution slug so a caller can place them separately — the project names are
--- the user's to invent, while the solution slug is a deployment coordinate a wizard may supply
--- and hide. Same prompts either way; `prompt` composes all of them.
---@param opts { entity: boolean? }?
function M.prompt_project(context, opts)
    opts = opts or {}

    context:prompt_text("Project Name:", "project_name", {
        cases       = { Cases.programming(), Cases.fixed("project_title", Case.Title) },
        placeholder = "billing-service",
        help        = "Kebab-case. The repository and project directory, the container image, "
            .. "the PlatformApplication name, and the directory CD writes into in the platform "
            .. "manifests repo.",
    })

    if opts.entity ~= false then
        -- OPTIONAL with no default, and the derivation runs AFTER — deliberately.
        --
        -- An envelope computed from `project_name` cannot be known until that prompt is answered,
        -- so an interface probe resolves it against whatever placeholder the probe fed and ships
        -- that to every client. Studio was being handed `entity_name = "probe"` as a pre-filled
        -- form value. Blank means "use the derivation", and the help says what the derivation is
        -- rather than guessing a value on the user's behalf.
        context:prompt_text("Entity Name:", "entity_name", {
            cases       = { Cases.programming(), Cases.fixed("entity_title", Case.Title) },
            optional    = true,
            placeholder = "billing",
            help        = "The sample CRUD entity the generated API exposes. Leave blank to use "
                .. "the project name with any trailing type qualifier (service, gateway, "
                .. "adapter, router, …) removed.",
        })

        local answered = context:get("entity-name")
        if answered == nil or answered == "" then
            context:set("entity_name", M.entity_default(context:get("project-name")), {
                cases = { Cases.programming(), Cases.fixed("entity_title", Case.Title) },
            })
        end
    end

    -- Derived, never asked: an archetype told the project name knows its repository name.
    context:set("repo_name", context:get("project-name"))
    return context
end

--- The solution slug — a deployment coordinate, not a name the user invents. Split out so a
--- caller can place it with the other platform facts a wizard may supply and hide.
function M.prompt_solution(context)
    context:prompt_text("Solution Slug:", "solution_name", {
        cases       = { Cases.programming(), Cases.fixed("solution_title", Case.Title) },
        placeholder = "acme-payments",
        help        = "Kebab-case. Prefixes the Kubernetes namespace: {solution}-{application}-{env}.",
    })

    -- TRANSITIONAL ALIAS (YP6M-3424). `org_solution_name` is what platform-application-manifests-
    -- library and the six overlay archetypes read today, and the name describes a decomposition
    -- this library removes. Retire it — and this line — once those consumers are converted to
    -- `solution_name`; nothing else in the fleet reads it.
    context:set("org_solution_name", context:get("solution-name"), { cases = Cases.programming() })

    -- Derived, never asked.
    context:set("github_owner", context:get("solution-name"))
    return context
end

--- The whole surface, in one call — for archetypes that place no layout of their own.
---@param opts { entity: boolean? }?
function M.prompt(context, opts)
    M.prompt_project(context, opts)
    M.prompt_solution(context)
    return context
end

-- No finalize phase — identity is pure context, no side effects. `run` exists for API symmetry
-- with the archetect-common libraries this one replaces.
function M.run(context, opts)
    return M.prompt(context, opts)
end

return M
