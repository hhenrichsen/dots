local function set_cursor_line_nr_color(mode)
  if mode == "i" then
    vim.fn.VSCodeNotify("nvim-theme.insert")
  elseif mode == "r" then
    vim.fn.VSCodeNotify("nvim-theme.replace")
  end
end

if vim.fn.exists("*VSCodeNotify") == 1 then
  local theme_group = vim.api.nvim_create_augroup("CursorLineNrColorSwap", { clear = true })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = theme_group,
    pattern = "*:[vV\22]*",
    callback = function()
      vim.fn.VSCodeNotify("nvim-theme.visual")
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = theme_group,
    pattern = "*:[R]*",
    callback = function()
      vim.fn.VSCodeNotify("nvim-theme.replace")
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = theme_group,
    callback = function()
      set_cursor_line_nr_color(vim.v.insertmode)
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = theme_group,
    callback = function()
      vim.fn.VSCodeNotify("nvim-theme.normal")
    end,
  })
  vim.api.nvim_create_autocmd("CursorHold", {
    group = theme_group,
    callback = function()
      vim.fn.VSCodeNotify("nvim-theme.normal")
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = theme_group,
    pattern = "[vV\22]*:*",
    callback = function()
      vim.fn.VSCodeNotify("nvim-theme.normal")
    end,
  })
end

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.autochdir = true

local function trim(value)
  return value:match("^%s*(.-)%s*$")
end

local function uncomment_current_line()
  local line = vim.api.nvim_get_current_line()
  local before, after = vim.bo.commentstring:match("^(.-)%%s(.-)$")

  if not before then
    return line
  end

  before, after = trim(before), trim(after)
  local command = trim(line)
  if before ~= "" and vim.startswith(command, before) then
    command = trim(command:sub(#before + 1))
    if after ~= "" and command:sub(-#after) == after then
      command = trim(command:sub(1, -#after - 1))
    end
  end

  return command
end

local function shell_command(command)
  local shell_args = vim.split(vim.o.shellcmdflag, "%s+", { trimempty = true })
  table.insert(shell_args, 1, vim.o.shell)
  table.insert(shell_args, command)
  return vim.system(shell_args, { text = true }):wait()
end

local function show_result(result)
  local output = (result.stdout or "") .. (result.stderr or "")
  output = output:gsub("\n$", "")
  vim.api.nvim_echo({ { output ~= "" and output or "(no output)", result.code == 0 and "None" or "ErrorMsg" } }, true, {})
end

local function run_current_line(replace)
  local command = uncomment_current_line()
  if command == "" then
    vim.notify("Current line has no command to run.", vim.log.levels.WARN)
    return
  end

  local result = shell_command(command)
  show_result(result)
  if result.code ~= 0 or not replace then
    return
  end

  local output = (result.stdout or ""):gsub("\n$", "")
  local lines = output == "" and { "" } or vim.split(output, "\n", { plain = true })
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  vim.api.nvim_buf_set_lines(0, row, row + 1, false, lines)
end

vim.api.nvim_create_user_command("RunLine", function()
  run_current_line(false)
end, { desc = "Run the current line with the configured shell" })

vim.api.nvim_create_user_command("ReplaceLine", function()
  run_current_line(true)
end, { desc = "Replace the current line with its shell output" })

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local result = vim.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  }):wait()
  if result.code ~= 0 then
    error("Could not install lazy.nvim: " .. (result.stderr or "unknown error"))
  end
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup("plugins")
