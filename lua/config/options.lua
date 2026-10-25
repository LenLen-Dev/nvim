-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-------------------------------------------------------------------------------
-- root 解析：不要让 root 退化成 $HOME
-------------------------------------------------------------------------------
-- 背景：~/.git 存在（家目录本身是个 git 仓库），而 LazyVim 默认
--   root_spec = { "lsp", { ".git", "lua" }, "cwd" }
-- 对「在 ~ 下、又不在任何项目里」的文件会一路向上命中 ~/.git，
-- 于是 LazyVim.root() = ~，<leader>ft / <C-/> 打开的终端就落在 ~。
-- 这里在 lsp / git 两层把 $HOME 过滤掉，再用「文件所在目录」兜底，最后才退到 cwd。
local Root = require("lazyvim.util.root")
local home = Root.realpath(vim.env.HOME)

local function no_home(paths)
  local ret = {}
  for _, p in ipairs(paths or {}) do
    local rp = Root.realpath(p)
    if rp and rp ~= home and not vim.tbl_contains(ret, rp) then
      ret[#ret + 1] = rp
    end
  end
  return ret
end

local function root_lsp(buf)
  return no_home(Root.detectors.lsp(buf))
end

local function root_project(buf)
  return no_home(Root.detectors.pattern(buf, { ".git", "lua" }))
end

-- 文件自己所在的目录永远可信（比如 ~/x.md 的 root 就应该是 ~）
local function root_file(buf)
  local path = Root.bufpath(buf)
  return path and { vim.fs.dirname(path) } or {}
end

vim.g.root_spec = { root_lsp, root_project, root_file, "cwd" }
