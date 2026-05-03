local M = {}

function M.current()
  return vim.fn.mode()
end

function M.is_visual(mode)
  local current_mode = mode or M.current()
  return current_mode == "v" or current_mode == "V" or current_mode == "\22"
end

function M.is_insert(mode)
  local current_mode = mode or M.current()
  return current_mode:sub(1, 1) == "i"
end

function M.leave_visual()
  if M.is_visual() then
    pcall(vim.cmd.normal, { args = { vim.keycode("<Esc>") }, bang = true })
  end
end

function M.leave_insert()
  if M.is_insert() then
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "i", false)
  end
end

function M.leave_editor()
  M.leave_visual()
  M.leave_insert()
end

function M.wait_for_normal(fn, remaining_checks)
  local checks = remaining_checks or 40
  local current_mode = M.current()

  if not (M.is_visual(current_mode) or M.is_insert(current_mode)) then
    fn()
    return
  end

  if checks <= 0 then
    fn()
    return
  end

  vim.schedule(function()
    M.wait_for_normal(fn, checks - 1)
  end)
end

function M.run_after_editor_mode(fn)
  local current_mode = M.current()
  if M.is_visual(current_mode) or M.is_insert(current_mode) then
    M.leave_editor()
    M.wait_for_normal(fn)
  else
    fn()
  end
end

return M
