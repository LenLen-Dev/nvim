-- Docker / docker-compose 编写环境
--
-- 打底由两个 LazyVim extras 完成（已写入 lazyvim.json）：
--   lazyvim.plugins.extras.lang.yaml
--     -> yamlls (yaml-language-server) + SchemaStore：schema 校验 / 键补全 / 悬停文档 / 折叠
--     -> 保存时按 LazyVim 默认的 conform fallback 用 yamlls 格式化 yaml
--   lazyvim.plugins.extras.lang.docker
--     -> dockerfile treesitter 高亮、dockerls（Dockerfile LSP）、hadolint（Dockerfile lint）
--
-- 本文件只做 compose 相关的针对性调整。

-- 在项目根目录里跑 docker compose 子命令，输出留在浮窗里，按 q 关闭
local function compose(args, opts)
  local cmd = { "docker", "compose" }
  vim.list_extend(cmd, args)
  return Snacks.terminal.open(cmd, vim.tbl_deep_extend("force", {
    cwd = LazyVim.root(),
    -- 一次性命令：跑完不要把窗口关掉，好让输出能看
    interactive = false,
  }, opts or {}))
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- compose 的 schema 校验交给 yamlls + SchemaStore（见下面 yamlls 配置）。
        -- microsoft/compose-language-service 会基于同一份 compose 规范再报一遍错误，
        -- 两个客户端同时挂在 compose 文件上会出现重复诊断，所以关掉它。
        -- 想改用 compose-language-service 的话，把它改成 {} ，并把 yamlls 里
        -- schemas 那几条删掉即可。
        docker_compose_language_service = { enabled = false },

        yamlls = {
          settings = {
            yaml = {
              -- compose 规范 schema：services / image / ports / environment /
              -- healthcheck / depends_on / deploy 等所有键的补全、校验和悬停文档。
              -- SchemaStore 自带的 catalog 已按文件名（compose.yml、docker-compose.yml、
              -- docker-compose.override.yml、compose.prod.yaml …）匹配到这份 schema，
              -- 这里显式再写一份，防止 SchemaStore 版本落后时匹配不到。
              schemas = {
                ["https://raw.githubusercontent.com/compose-spec/compose-go/master/schema/compose-spec.json"] = {
                  "**/compose*.y*ml",
                  "**/docker-compose*.y*ml",
                },
              },
              -- schema 里所有键都进补全列表，而不只是必填项
              completion = true,
              hover = true,
            },
          },
        },
      },
    },
  },

  -- <leader>D 组：不用切终端就能跑常用 compose 命令
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>Dc", function() compose({ "ps" }) end, desc = "compose ps" },
      { "<leader>Du", function() compose({ "up", "-d" }) end, desc = "compose up -d" },
      { "<leader>Dd", function() compose({ "down" }) end, desc = "compose down" },
      { "<leader>Dl", function() compose({ "logs", "-f" }, { interactive = true }) end, desc = "compose logs -f" },
      { "<leader>Dr", function() compose({ "restart" }) end, desc = "compose restart" },
      { "<leader>Dv", function() compose({ "config" }) end, desc = "compose config（校验合并结果）" },
    },
  },
}
