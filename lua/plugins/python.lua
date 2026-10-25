-- Python 开发环境
--
-- 打底由 LazyVim extra 完成（已写入 lazyvim.json）：
--   lazyvim.plugins.extras.lang.python
--     -> pyright（类型检查/补全/跳转） + ruff（lint + 格式化），两个都挂
--     -> venv-selector.nvim（<leader>cv 选虚拟环境）
--     -> nvim-dap-python（<leader>dPt / <leader>dPc 调试 pytest 用例）
--     -> treesitter python 高亮
--
-- 本文件只做针对性调整：venv 自动探测、ruff 作为唯一 formatter、dap 用项目 venv、
-- 以及 <leader>p 组的运行/测试命令。

-- ---------------------------------------------------------------------------
-- 找到项目根 + 该用哪个 Python 解释器
--
-- 注意不能用 LazyVim.root()：它优先取 cwd，从 nvim 打开任意路径时可能不是
-- 这个文件所属的项目。这里直接按「当前 buffer 的文件路径」往上找标记文件。
-- ---------------------------------------------------------------------------
local py_root_markers = {
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  "pyrightconfig.json",
  ".git",
}

--- 当前 buffer 所属的项目根（找不到就退回 LazyVim.root()）
---@param buf? integer
---@return string
local function python_root(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= "" then
    local root = vim.fs.root(name, py_root_markers)
    if root then
      return root
    end
  end
  return LazyVim.root()
end

-- 项目里有没有虚拟环境，有的话返回目录名（.venv / venv / .env）
---@param dir string
---@return string?
local function venv_in(dir)
  for _, name in ipairs({ ".venv", "venv", ".env" }) do
    if vim.fn.executable(dir .. "/" .. name .. "/bin/python") == 1 then
      return name
    end
  end
end

-- 优先级：项目内 .venv/venv/.env -> VIRTUAL_ENV -> PATH 里的 python3。
-- pyright 和 dap 必须用同一个，否则「编辑器里能跳转、一运行就 ModuleNotFoundError」。
---@param root string
---@return string
local function python_for(root)
  local name = venv_in(root)
  if name then
    return root .. "/" .. name .. "/bin/python"
  end
  local venv = os.getenv("VIRTUAL_ENV")
  if venv and venv ~= "" and vim.fn.executable(venv .. "/bin/python") == 1 then
    return venv .. "/bin/python"
  end
  local exe = vim.fn.exepath("python3")
  return exe ~= "" and exe or "python3"
end

---@param buf? integer
---@return string
local function project_python(buf)
  return python_for(python_root(buf))
end

-- 在项目根目录跑命令，输出留在浮窗里
local function run(cmd, opts)
  return Snacks.terminal.open(
    cmd,
    vim.tbl_deep_extend("force", {
      cwd = python_root(),
      interactive = false,
    }, opts or {})
  )
end

-- 当前项目的 python 解释器
local function py()
  return project_python()
end

return {
  -- 补齐 mason 包（extra 里只声明了 lsp 的启动方式，没写 ensure_installed）
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "pyright", "ruff", "debugpy" },
    },
  },

  -- pyright：每个 client 启动时按它自己的 root_dir 解析解释器，否则第三方库
  -- 全部报 "could not be resolved"。
  --
  -- 这里踩过两个坑，别再退回去：
  -- 1. 不能把 pythonPath 直接写在静态 settings 里。那样只会求值一次（spec 加载时），
  --    整个 session 被「第一个打开的 Python 文件」锁死：先开一个不在项目里的 .py，
  --    或之后切到另一个项目，pyright 就一直用错解释器。
  -- 2. before_init 里必须「原地改」config.settings（config.settings.python.xxx = ...）。
  --    client.settings 捕获的是同一张表的引用，整个替换成新表服务端收不到。
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.pyright = vim.tbl_deep_extend("force", opts.servers.pyright or {}, {
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "standard",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly",
            },
          },
        },
        before_init = function(_, config)
          local root = config.root_dir
          if not root or root == "" then
            return
          end
          local settings = config.settings or {}
          settings.python = settings.python or {}
          settings.python.pythonPath = python_for(root)
          local name = venv_in(root)
          if name then
            settings.python.venvPath = root
            settings.python.venv = name
          end
          -- config.settings 可能是 nil（被别的 spec 清过），补回去保证引用一致
          config.settings = settings
        end,
      })
      opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
        init_options = {
          settings = {
            -- 让 ruff 的 LSP 每次都重新读 pyproject.toml
            logLevel = "error",
          },
        },
      })
      return opts
    end,
  },

  -- 格式化统一交给 ruff（both lint fix + format），pyright 不管格式化
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_fix", "ruff_format" },
      },
    },
  },

  -- lint 交给 ruff 的 LSP 就够了，nvim-lint 不用再跑一遍
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      -- dap-python 的 adapter 用 mason 的 debugpy-adapter（只是适配器进程），
      -- 真正被调试的程序解释器由 resolve_python 决定 —— 必须指向项目 venv，
      -- 否则断点能停，但 import 第三方库会报 ModuleNotFoundError。
      local dap_python = require("dap-python")
      dap_python.setup(vim.fn.exepath("debugpy-adapter"), { include_configs = true })
      dap_python.resolve_python = function()
        return project_python()
      end
    end,
  },

  -- <leader>p 组：跑脚本 / 跑测试 / 开 REPL
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>pr",
        function()
          local file = vim.fn.expand("%:p")
          run({ py(), file }, { interactive = true })
        end,
        desc = "运行当前脚本",
      },
      {
        "<leader>pt",
        function()
          run({ py(), "-m", "pytest", "-q" }, { interactive = true })
        end,
        desc = "跑 pytest（整个项目）",
      },
      {
        "<leader>pf",
        function()
          -- 只跑光标所在的文件
          run({ py(), "-m", "pytest", vim.fn.expand("%:p"), "-q" }, { interactive = true })
        end,
        desc = "跑 pytest（当前文件）",
      },
      {
        "<leader>pl",
        function()
          run({ py(), "-m", "ruff", "check", "." }, { interactive = false })
        end,
        desc = "ruff lint（全项目）",
      },
      {
        "<leader>pi",
        function()
          -- 交互式 REPL：直接用项目解释器，能 import 到本项目的包
          local root = LazyVim.root()
          run({ py() }, {
            interactive = true,
            env = {
              PYTHONPATH = root .. "/src" .. (os.getenv("PYTHONPATH") and (":" .. os.getenv("PYTHONPATH")) or ""),
            },
          })
        end,
        desc = "Python REPL（项目环境）",
      },
    },
  },
}
