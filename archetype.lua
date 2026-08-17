-- p6m-identity-library standalone / one-shot entry point.
--
-- Parents consume this library with `library: true` and call
-- `require("p6m-identity").prompt(context)` — see the README. This script runs when the archetype
-- is invoked directly, which is what the probe fixture under tests/ does to observe the derived
-- keys: a prompt library renders no files, so a probe that renders them is the only way to hold
-- its contract black-box.

local context = Context.new()
require("lib").run(context)
return context
