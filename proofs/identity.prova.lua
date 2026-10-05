--- The p6m identity surface, held on rendered output.
---
--- This library owns exactly one derivation — the sample CRUD entity, defaulted from the project
--- name — and it is the only p6m-specific name derivation in the fleet. Everything else here is
--- archetect's casing engine, which prova.str shares, so this suite deliberately does NOT restate
--- casing rules: it asserts the SHAPES that downstream templates consume.
---
--- A prompt library renders no files, so the contract is observed through a probe archetype
--- (proofs/fixtures/probe) that composes the library and writes the derived keys to one YAML file.
--- That is the whole reason none of the fleet's other libraries carries a suite — and the reason
--- this one must: a rule with no direct proof is a rule that drifts, and the oracle in
--- prova-p6m-standards deliberately re-derives nothing, so there is no second reader to catch it.

local PROBE = "proofs/fixtures/probe"

--- The table the rule is written from. Each row exercises a different branch, and the last two are
--- the ones a naive "split on the last hyphen" gets wrong.
local SHAPES = {
  {
    label = "type-qualified, single-token subject",
    project = "billing-service",
    entity = "billing", EntityName = "Billing", entityName = "billing",
    ProjectName = "BillingService", project_name = "billing_service",
    rest = "/api/v1/billings",
  },
  {
    label = "type-qualified, multi-token subject — casing bugs only show here",
    project = "user-details-service",
    entity = "user-details", EntityName = "UserDetails", entityName = "userDetails",
    ProjectName = "UserDetailsService", project_name = "user_details_service",
    rest = "/api/v1/user-detailss",
  },
  {
    label = "type-qualified by a non-'service' token",
    project = "payment-gateway",
    entity = "payment", EntityName = "Payment", entityName = "payment",
    ProjectName = "PaymentGateway", project_name = "payment_gateway",
    rest = "/api/v1/payments",
  },
  {
    label = "compound with NO type qualifier — nothing may be stripped",
    project = "order-management",
    entity = "order-management", EntityName = "OrderManagement", entityName = "orderManagement",
    ProjectName = "OrderManagement", project_name = "order_management",
    rest = "/api/v1/order-managements",
  },
  {
    label = "single token — the whole name survives, never the empty string",
    project = "customer",
    entity = "customer", EntityName = "Customer", entityName = "customer",
    ProjectName = "Customer", project_name = "customer",
    rest = "/api/v1/customers",
  },
}

local ORGANIZATION = "acme-payments"

--- Render the probe with `entity_name` UNANSWERED, so what lands is the library's default. An
--- answered entity would prove nothing about the derivation — it would prove archetect stores
--- answers.
---
--- The tempdir is NAMED per shape, and that is load-bearing: `ctx:tempdir()` is addressed, not
--- created, so every unnamed call in one scope answers with the SAME directory. Five renders into
--- one destination means the first one wins (prova's engine preserves an existing path) and every
--- later shape silently reads the first shape's output — a suite that passes while proving one
--- shape five times.
local function derived(ctx, project)
  local out = archetect.render{
    source = PROBE,
    answers = { project_name = project, organization_name = ORGANIZATION },
    destination = ctx:tempdir(project),
    defaults = true,
  }
  return yaml.decode(fs.read(out.path .. "/identity.yaml"))
end

for _, shape in ipairs(SHAPES) do
  local id = prova.fixture("identity[" .. shape.project .. "]", Scope.File, function(ctx)
    return derived(ctx, shape.project)
  end)

  prova.group("identity[" .. shape.project .. "] — " .. shape.label, function(g)
    g:test("the entity defaults off the project name", {
      proves = "the one derivation this library owns: a trailing type qualifier is stripped, and "
        .. "only when a subject would be left behind",
    }, function(t)
      t:expect(t:use(id)["entity-name"], "entity-name"):equals(shape.entity)
    end)

    g:test("every casing the templates consume is present and agrees", {
      proves = "downstream templates name classes, packages and fields off these keys; a missing "
        .. "variant renders as empty, which is invisible until the generated project fails to build",
    }, function(t)
      local d = t:use(id)
      t:expect_all(function()
        t:expect(d["project-name"], "project-name"):equals(shape.project)
        t:expect(d["project_name"], "project_name"):equals(shape.project_name)
        t:expect(d["ProjectName"], "ProjectName"):equals(shape.ProjectName)
        t:expect(d["EntityName"], "EntityName"):equals(shape.EntityName)
        t:expect(d["entityName"], "entityName"):equals(shape.entityName)
      end)
    end)

    g:test("the S2 API surface derives from the identity, not from a hardcoded noun", {
      proves = "standards S2: REST is `/api/v1/{entity}s`, the GraphQL type is entity-named and "
        .. "the gRPC service is project-named — the split that hardcoded `items` erased",
    }, function(t)
      local d = t:use(id)
      t:expect_all(function()
        t:expect(d.rest_collection, "REST collection"):equals(shape.rest)
        t:expect(d.graphql_type, "GraphQL type"):equals(shape.EntityName)
        t:expect(d.graphql_query, "GraphQL query field"):equals(shape.entityName)
        t:expect(d.grpc_service, "gRPC service"):equals(shape.ProjectName)
        t:expect(d.grpc_rpc, "gRPC create rpc"):equals("Create" .. shape.EntityName)
      end)
    end)
  end)
end

prova.group("identity — the surface as a whole", function(g)
  local id = prova.fixture("identity[surface]", Scope.File, function(ctx)
    return derived(ctx, "billing-service")
  end)

  g:test("the entity is an ANSWER, not merely a derivation", {
    proves = "the default exists to save a keystroke, not to decide the domain: a caller who "
      .. "names the entity gets that name, or the prompt is decoration",
  }, function(t)
    local out = archetect.render{
      source = PROBE,
      answers = { project_name = "billing-service", organization_name = ORGANIZATION,
                  entity_name = "invoice" },
      destination = t:tempdir("answered-entity"),
      defaults = true,
    }
    local d = yaml.decode(fs.read(out.path .. "/identity.yaml"))
    t:expect_all(function()
      t:expect(d["entity-name"], "entity-name"):equals("invoice")
      t:expect(d.rest_collection, "REST collection"):equals("/api/v1/invoices")
      t:expect(d.grpc_rpc, "gRPC create rpc"):equals("CreateInvoice")
      -- and the project name is untouched by it
      t:expect(d["ProjectName"], "ProjectName"):equals("BillingService")
    end)
  end)

  g:test("SCM addressing is derived, never asked", {
    proves = "an archetype told the project and the organization knows both of these; asking again "
      .. "is a prompt whose answer nothing new reads (standards E2)",
  }, function(t)
    local d = t:use(id)
    t:expect(d.repo_name, "repo_name"):equals("billing-service")
    t:expect(d.github_owner, "github_owner"):equals(ORGANIZATION)
  end)

  g:test("the organization is answered as organization_name, in every casing", {
    proves = "YP6M-3798: the key names what the value is — the GitHub organization — so templates "
      .. "read `{{ organization-name }}` and an answer file says `organization_name`",
  }, function(t)
    local d = t:use(id)
    t:expect_all(function()
      t:expect(d["organization-name"], "organization-name"):equals(ORGANIZATION)
      t:expect(d.organization_title, "organization_title"):equals("Acme Payments")
    end)
  end)

  g:test("a legacy solution_name answer still resolves the organization", {
    proves = "Ybor Studio and older answer files supply the organization as `solution_name`; until "
      .. "they move, that answer must land as the organization rather than be asked for again",
  }, function(t)
    local out = archetect.render{
      source = PROBE,
      answers = { project_name = "billing-service", solution_name = "legacy-org" },
      destination = t:tempdir("legacy-answer"),
      defaults = true,
    }
    local d = yaml.decode(fs.read(out.path .. "/identity.yaml"))
    t:expect_all(function()
      t:expect(d["organization-name"], "organization-name"):equals("legacy-org")
      t:expect(d.organization_title, "organization_title"):equals("Legacy Org")
      t:expect(d.github_owner, "github_owner"):equals("legacy-org")
    end)
  end)

  g:test("a legacy solution_name answer that is not a name is refused, not used", {
    proves = "the fallback must not be a way around the prompt's pattern: a hybrid client sends an "
      .. "empty string for a field the user tabbed past, and an empty organization renders "
      .. "`-billing-service-dev` in silence. Refusal means the prompt runs, and headless it fails "
      .. "naming organization_name",
  }, function(t)
    for _, bad in ipairs({ "", "-acme" }) do
      local ok = pcall(archetect.render, {
        source = PROBE,
        answers = { project_name = "billing-service", solution_name = bad },
        destination = t:tempdir("legacy-bad-" .. #bad),
        defaults = false,
      })
      t:expect(ok, "solution_name=" .. string.format("%q", bad) .. " must not render"):is_false()
    end
  end)

  g:test("organization_name wins when both keys are answered", {
    proves = "a client mid-migration may send both; the new key is the one it meant",
  }, function(t)
    local out = archetect.render{
      source = PROBE,
      answers = { project_name = "billing-service", solution_name = "legacy-org",
                  organization_name = ORGANIZATION },
      destination = t:tempdir("both-answers"),
      defaults = true,
    }
    local d = yaml.decode(fs.read(out.path .. "/identity.yaml"))
    t:expect(d["organization-name"], "organization-name"):equals(ORGANIZATION)
  end)

  g:test("the transitional solution aliases still answer their consumers", {
    proves = "archetype tags cut before YP6M-3798 read `solution-name` or `org-solution-name`; the "
      .. "aliases keep them rendering while the rename lands repo by repo",
  }, function(t)
    local d = t:use(id)
    t:expect_all(function()
      t:expect(d["solution-name"], "solution-name alias"):equals(ORGANIZATION)
      t:expect(d["org-solution-name"], "org-solution-name alias"):equals(ORGANIZATION)
    end)
  end)
end)

-- The prompt WORDING is a user-facing contract, not a comment: Ybor Studio renders a prompt's
-- message verbatim as the form label and its help verbatim as the field description, so a word
-- changed here changes what a user reads. Nothing else in this suite observes display text — the
-- rest is held on rendered output, which is blind to it.
--
-- Held on the SCRIPT rather than on a derived interface, for the same reason prova-p6m-standards
-- holds declaration-shaped bars there (init.lua:1737): prova's `archetect` module exposes `render`
-- and `verify` only, so a suite cannot read the interface a client receives. `archetect interface
-- <source> --json` is the out-of-band check when you want to see the envelope itself.
prova.group("the prompt surface Studio renders", function(g)
  local SOURCE = prova.root .. "/lib/init.lua"
  -- The platform-manifests library prompts for the organization itself when rendered standalone,
  -- so its wording is the same contract. Read when the workspace has it; this repo stands alone.
  local PAM = prova.root .. "/../platform-application-manifests-library/lib/init.lua"

  g:test("the deployment coordinate is labelled Organization", {
    proves = "YP6M-3798: the value IS the GitHub organization — `github_owner` is derived from it "
      .. "below — and Studio already calls that record an Organization everywhere else. 'Solution' "
      .. "named a concept this fleet retired, and the word is being freed for a different one",
  }, function(t)
    local src = fs.read(SOURCE)
    t:expect_all(function()
      t:expect(src:find('"Organization:", "organization_name"', 1, true) ~= nil,
        'the prompt is declared as "Organization:" on organization_name'):is_true()
      t:expect(src:lower():find("solution slug", 1, true) == nil,
        "no 'solution slug' wording survives in the prompt surface"):is_true()
      if fs.exists(PAM) then
        local pam = fs.read(PAM):lower()
        t:expect(pam:find("solution slug", 1, true) == nil,
          "no 'solution slug' wording survives in platform-application-manifests-library"):is_true()
        t:expect(pam:find("org / solution", 1, true) == nil,
          "no 'Org / Solution' prompt survives in platform-application-manifests-library"):is_true()
      end
    end)
  end)

  g:test("the help names the GitHub organization and nothing more", {
    proves = "the namespace derivation `{organization}-{application}-{env}` is a platform-internal "
      .. "rule the user makes no decision about; it stays documented in this module's header, "
      .. "where a maintainer needs it, and out of the field description, where it only mystifies",
  }, function(t)
    local src = fs.read(SOURCE)
    t:expect_all(function()
      t:expect(src:find('help%s+= "Your GitHub organization%."') ~= nil,
        "the help reads 'Your GitHub organization.'"):is_true()
      t:expect(src:find("Prefixes the Kubernetes namespace", 1, true) == nil,
        "the namespace rule is not in the prompt help"):is_true()
    end)
  end)
end)

-- The aliases above are scaffolding, and scaffolding that nothing removes becomes architecture.
-- Two reminders, because the two halves retire on different clocks.
--
-- OUTBOUND: `solution_name` / `org_solution_name` set for templates, and `prompt_solution`. WATCHING
-- while any repo that mounts this library still reads one; DUE once none does (and its PR is merged
-- and `v1` moved — this reads the workspace, so a local branch can run ahead of the fleet).
prova.remind("the outbound solution aliases have outlived their consumers", {
  when = function()
    local fleet = prova.root .. "/.."
    local mounts = shell.run("grep -l p6m-identity-library " .. fleet .. "/*/archetype.yaml",
      { merge_stderr = true })
    if mounts.code ~= 0 then return false end
    for manifest in mounts.stdout:gmatch("[^\n]+") do
      local dir = manifest:gsub("/archetype%.yaml$", "")
      local hit = shell.run("grep -rIlE 'solution[-_]name|prompt_solution' " .. dir
        .. " --exclude-dir=.git --exclude-dir=.prova", { merge_stderr = true })
      if hit.code == 0 then return false end
    end
    return "no archetype mounting p6m-identity reads solution-name or calls prompt_solution any more"
  end,
}, "YP6M-3798: drop the solution_name/org_solution_name aliases and prompt_solution from "
   .. "lib/init.lua, their lines in the probe's identity.yaml, and the alias proof.")

-- INBOUND: the legacy `solution_name` ANSWER. Ybor Studio seeds it (catalog-seeds.ts,
-- retrofit-archetypes.ts), so the fallback stays until Studio sends `organization_name`. Evaluated
-- only when a Studio checkout sits beside this workspace; elsewhere it stays quiet.
prova.remind("Ybor Studio no longer sends solution_name", {
  when = function()
    local studio = prova.root .. "/../../ybor-studio/ybor-studio-frontend/apps/studio/src/lib"
    if not fs.exists(studio) then return false end
    local hit = shell.run("grep -rlE \"'solution_name'\" " .. studio, { merge_stderr = true })
    return hit.code ~= 0 and "Studio's seeds answer organization_name; nothing sends solution_name"
  end,
}, "YP6M-3798: drop the legacy solution_name answer fallback from lib/init.lua and the two "
   .. "legacy-answer proofs.")
