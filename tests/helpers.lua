local M = {}

local function format_value(value)
  return vim.inspect(value)
end

function M.eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error((message or "values are not equal") .. "\nexpected: " .. format_value(expected) .. "\nactual: " .. format_value(actual))
  end
end

function M.truthy(value, message)
  if not value then
    error(message or "expected truthy value")
  end
end

function M.falsy(value, message)
  if value then
    error(message or "expected falsy value")
  end
end

function M.flush()
  vim.wait(20, function()
    return false
  end, 1)
end

function M.stub_mouse(mouse)
  local original = vim.fn.getmousepos
  vim.fn.getmousepos = function()
    return mouse
  end
  return function()
    vim.fn.getmousepos = original
  end
end

function M.render_statusline()
  local state = require("orca_menu.state")
  local layout = require("orca_menu.layout")
  local labels = {}

  for index, menu in ipairs(state.config.menus or {}) do
    table.insert(labels, layout.top_bar_display_label(menu, index))
  end

  vim.o.laststatus = 2
  vim.wo.statusline = " " .. table.concat(labels, " ") .. " "
  layout.refresh_label_positions()
end

function M.finish()
  local ok, popup = pcall(require, "orca_menu.popup")
  if ok then
    pcall(popup.close_all)
  end
end

return M

