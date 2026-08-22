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
  local layout = require("orca_menu.layout")
  local lualine = require("lualine")

  vim.o.laststatus = 2
  local lualine_config = lualine.get_config()
  if lualine_config and lualine_config.options then
    lualine.refresh({ force = true, scope = "window", place = { "statusline" } })
  end
  layout.refresh_label_positions()
end

function M.finish()
  local ok, popup = pcall(require, "orca_menu.popup")
  if ok then
    pcall(popup.close_all)
  end
end

return M
