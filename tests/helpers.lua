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

function M.expected_popup_anchor(position, popup_width, border)
  local border_size = border ~= nil and border ~= false and 1 or 0
  local frame_width = popup_width + (border_size * 2)
  local min_frame_col = 1
  local max_frame_col = math.max(vim.o.columns - frame_width + 1, 1)
  local frame_col = math.min(
    math.max(position.screen.end_col - frame_width + 1, min_frame_col),
    max_frame_col
  )
  return frame_col - 1
end

function M.finish()
  local ok, popup = pcall(require, "orca_menu.popup")
  if ok then
    pcall(popup.close_all)
  end
end

return M
