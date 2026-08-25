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

local SOLUTION = "acme-payments"

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
    answers = { project_name = project, solution_name = SOLUTION },
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
      answers = { project_name = "billing-service", solution_name = SOLUTION,
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
    proves = "an archetype told the project and the solution knows both of these; asking again "
      .. "is a prompt whose answer nothing new reads (standards E2)",
  }, function(t)
    local d = t:use(id)
    t:expect(d.repo_name, "repo_name"):equals("billing-service")
    t:expect(d.github_owner, "github_owner"):equals(SOLUTION)
  end)

  g:test("the transitional org_solution_name alias still answers its consumers", {
    proves = "platform-application-manifests-library and the six overlays read `org-solution-name` "
      .. "today; the alias keeps them rendering while the rename lands repo by repo",
  }, function(t)
    t:expect(t:use(id)["org-solution-name"], "org-solution-name alias"):equals(SOLUTION)
  end)
end)

-- The alias above is scaffolding, and scaffolding that nothing removes becomes architecture. This
-- reminder is WATCHING while any consumer still reads the old key, and fires DUE the moment none
-- does — at which point the alias in lib/init.lua, its probe line, and the proof above all go.
prova.remind("the org_solution_name alias has outlived its consumers", {
  when = function()
    local fleet = prova.root .. "/.."
    local consumers = {}
    for _, repo in ipairs({
      "platform-application-manifests-library",
      "dotnet-service-empty-archetype", "golang-service-empty-archetype",
      "java-service-empty-archetype", "python-service-empty-archetype",
      "rust-service-empty-archetype", "typescript-service-empty-archetype",
    }) do
      local dir = fleet .. "/" .. repo
      if fs.exists(dir) then
        local hit = shell.run("grep -rIl org.solution.name " .. dir .. " --exclude-dir=.git",
          { merge_stderr = true })
        if hit.code == 0 then consumers[#consumers + 1] = repo end
      end
    end
    return #consumers == 0
      and "no repo in this workspace reads org-solution-name any more — the alias is dead weight"
  end,
}, "YP6M-3424: drop the org_solution_name alias from lib/init.lua, its line in the probe's "
   .. "identity.yaml, and the proof that covers it.")
