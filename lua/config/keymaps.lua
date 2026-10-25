-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-------------------------------------------------------------------------------
-- 终端 cwd：跟着当前文件走，不要落到 ~
-------------------------------------------------------------------------------
-- LazyVim 默认的 <leader>ft / <C-/> 用的是 LazyVim.root()，
-- 一旦 root 被解析成 $HOME（见 config/options.lua 里的 root_spec 说明），
-- 终端就会开在 ~。这里再兜一层：root 等于 $HOME 时改用文件所在目录。
local uv = vim.uv or vim.loop

local function term_cwd()
  local name = vim.api.nvim_buf_get_name(0)
  local home = uv.fs_realpath(vim.env.HOME) or vim.env.HOME
  local root = LazyVim.root()

  if root and root ~= "" and root ~= home then
    return root
  end
  if name ~= "" then
    local dir = vim.fs.dirname(name)
    if dir ~= "" and dir ~= "." then
      return dir
    end
  end
  return uv.cwd()
end

-- 终端里手动敲的 python / pytest 也要用项目 venv：
-- 从终端 cwd 往上找 .venv / venv / .env，找到就把 VIRTUAL_ENV + PATH 传进去。
-- 注意：nvim 本身不一定是从「已激活 venv 的 shell」里启动的，不能指望继承。
---@param dir string
---@return table<string, string>?
local function venv_env(dir)
  local d = dir
  for _ = 1, 8 do
    for _, name in ipairs({ ".venv", "venv", ".env" }) do
      local venv = d .. "/" .. name
      if uv.fs_stat(venv .. "/bin/python") then
        return {
          VIRTUAL_ENV = venv,
          PATH = venv .. "/bin:" .. (vim.env.PATH or ""),
        }
      end
    end
    local parent = vim.fs.dirname(d)
    if not parent or parent == d then
      break
    end
    d = parent
  end
end

---@return { cwd: string, env: table<string, string>? }
local function term_opts()
  local cwd = term_cwd()
  return { cwd = cwd, env = venv_env(cwd) }
end

local function term_focus()
  Snacks.terminal.focus(nil, term_opts())
end

vim.keymap.set("n", "<leader>ft", function()
  Snacks.terminal(nil, term_opts())
end, { desc = "Terminal (Root Dir)" })

vim.keymap.set("n", "<leader>fT", function()
  Snacks.terminal()
end, { desc = "Terminal (cwd)" })

vim.keymap.set({ "n", "t" }, "<C-/>", term_focus, { desc = "Terminal (Root Dir)" })
vim.keymap.set({ "n", "t" }, "<C-_>", term_focus, { desc = "which_key_ignore" })
-- Ctrl+, 也指向同一个终端（是否真的能收到这个键取决于你的终端模拟器）
vim.keymap.set({ "n", "t" }, "<C-,>", term_focus, { desc = "Terminal (Root Dir)" })
