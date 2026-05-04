local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

local runtime_menus = require("orca_menu.runtime_menus")
local state = require("orca_menu.state")

runtime_menus.reset()

local ok, err = pcall(runtime_menus.register, "", {})
H.falsy(ok, "register should reject an empty id")
H.truthy(tostring(err):find("register_menu", 1, true), "register error should mention register_menu")

ok, err = pcall(runtime_menus.update, "tools", "bad")
H.falsy(ok, "update should reject a non-table menu spec")
H.truthy(tostring(err):find("update_menu", 1, true), "update error should mention update_menu")

ok, err = pcall(runtime_menus.register, "broken", { items = {} })
H.falsy(ok, "register should reject a menu without a string label")
H.truthy(tostring(err):find("menu.label", 1, true), "missing top-level label should be reported clearly")

ok, err = pcall(runtime_menus.register, "broken-child", {
  label = "&Broken",
  items = {
    {},
  },
})
H.falsy(ok, "register should reject child items without string labels")
H.truthy(tostring(err):find("menu.items[1].label", 1, true), "missing child label should be reported clearly")

runtime_menus.register("tools", {
  label = "&Tools",
  key = "t",
  items = {
    { label = "Run &One", key = "1" },
  },
})

runtime_menus.register("view", {
  label = "&View",
  items = {},
})

H.eq(state.dynamic_menu_order, { "tools", "view" }, "register should preserve insertion order")

local specs = runtime_menus.specs()
H.eq(#specs, 2, "specs should return each registered menu")
H.eq(specs[1].label, "&Tools", "specs should preserve raw menu labels")
specs[1].label = "Changed"
H.eq(state.dynamic_menus.tools.label, "&Tools", "specs should return deep copies")

local base_menus = {
  { label = "Base", kind = "top", items = {} },
}
local appended = runtime_menus.append_to(base_menus)
H.eq(#appended, 3, "append_to should append runtime menus after base menus")
H.eq(appended[1].label, "Base", "append_to should preserve base menus")
H.eq(appended[2].label, "Tools", "append_to should normalize runtime menu labels")
H.eq(appended[2].accelerator, "t", "append_to should normalize accelerators")
H.eq(appended[2].items[1].label, "Run One", "append_to should normalize child items")

appended[2].label = "Mutated"
appended[2].items[1].label = "Mutated child"
H.eq(state.dynamic_menus.tools.label, "&Tools", "append_to should not expose registry tables directly")
H.eq(state.dynamic_menus.tools.items[1].label, "Run &One", "append_to should deep copy child items")

runtime_menus.update("tools", {
  label = "&Tools",
  key = "tt",
  items = {
    { label = "Run &Two", key = "2" },
  },
})

H.eq(state.dynamic_menu_order, { "tools", "view" }, "update should not change menu ordering")
H.eq(state.dynamic_menus.tools.key, "tt", "update should replace the stored menu")

H.truthy(runtime_menus.unregister("tools"), "unregister should report success for installed menus")
H.eq(state.dynamic_menu_order, { "view" }, "unregister should remove ids from ordering")
H.falsy(runtime_menus.unregister("tools"), "unregister should report false for missing menus")

runtime_menus.reset()
H.eq(state.dynamic_menu_order, {}, "reset should clear runtime ordering")
H.eq(state.dynamic_menus, {}, "reset should clear runtime menu registry")

print("ok - tests/unit/runtime_registry.lua")
