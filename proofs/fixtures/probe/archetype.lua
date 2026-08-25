local context = Context.new()
require("p6m-identity").prompt(context)
directory.render("contents", context)
return context
