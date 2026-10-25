-- 配色：Gruvbox
--
-- LazyVim 换主题只需要两件事：
--   1) 装主题插件（这里用 ellisonleao/gruvbox.nvim）
--   2) 让 LazyVim 启动时加载它（opts.colorscheme）
--
-- lualine / bufferline / snacks / which-key 等都是从高亮组取色的，所以改主题后
-- 状态栏、补全菜单会自动跟着变，不需要单独配。
--
-- 想换回 tokyonight：把下面 colorscheme 改成 "tokyonight"，并去掉 gruvbox 那个 spec。
-- 想临时试试别的主题（不写进配置）：:colorscheme <name>，重启后失效。
--
-- 柔和配色（背景完全不变，仍是 #1d2021）：
-- 比起原版把各前景色略微压暗、降饱和，减少眼睛的紧张感。
-- 背景、CursorLine 等色块一律不碰，只调 fg。
-- 每条注释后的数字是「相对背景实测的对比度」（WCAG 比值）。
-- 觉得太暗就往亮调 hex，觉得刺眼就往暗调。

return {
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false, -- 主题必须在启动时加载，不能懒加载
    priority = 1000, -- 比其它插件先加载，避免界面先闪一下默认配色
    opts = {
      -- 对比度档位：soft（最柔和）/ medium / hard（对比最强）
      contrast = "hard",
      -- 用 gruvbox 的透明背景（想让终端壁纸透出来时改成 true）
      transparent_mode = false,
      italic = {
        strings = false,
        emphasis = false,
        comments = false,
        operators = false,
        folds = false,
      },
      -- 前景色柔和化：不改任何背景色，只调 fg
      overrides = {
        -- ---- 正文 / 变量 ----
        -- 占比最大的前景色，柔和化收益最明显：#ebdbb2 → #d5c4a1   12.0 → 9.6
        Normal = { fg = "#d5c4a1" },
        GruvboxFg1 = { fg = "#d5c4a1" },
        ["@variable"] = { fg = "#d5c4a1" },
        ["@module"] = { fg = "#d5c4a1" },
        ["@namespace"] = { fg = "#d5c4a1" },

        -- ---- 语法主体 ----
        -- 运算符 / 括号 / 分隔符：橙 #fe8019 → 柔和橙  6.5 → 6.0
        Operator = { fg = "#e5852e" },
        Delimiter = { fg = "#e5852e" },
        GruvboxOrange = { fg = "#e5852e" },
        ["@operator"] = { fg = "#e5852e" },
        ["@punctuation.bracket"] = { fg = "#e5852e" },
        ["@punctuation.delimiter"] = { fg = "#e5852e" },

        -- 成员 / 属性 / 标识符：蓝 #83a598 → 柔和青绿  6.1 → 6.2
        Identifier = { fg = "#7fa89b" },
        GruvboxBlue = { fg = "#7fa89b" },
        ["@variable.member"] = { fg = "#7fa89b" },
        ["@variable.parameter"] = { fg = "#7fa89b" },
        ["@property"] = { fg = "#7fa89b" },
        ["@field"] = { fg = "#7fa89b" },

        -- 常量 / 数字 / 布尔：紫 #d3869b → 柔和紫  6.0 → 5.4
        Constant = { fg = "#c08397" },
        Character = { fg = "#c08397" },
        Number = { fg = "#c08397" },
        Boolean = { fg = "#c08397" },
        Float = { fg = "#c08397" },
        GruvboxPurple = { fg = "#c08397" },
        ["@constant"] = { fg = "#c08397" },
        ["@number"] = { fg = "#c08397" },
        ["@boolean"] = { fg = "#c08397" },

        -- 函数 / 字符串：绿 #b8bb26 → 柔和绿  7.9 → 7.6
        Function = { fg = "#adb92f" },
        String = { fg = "#adb92f" },
        GruvboxGreen = { fg = "#adb92f" },
        GruvboxGreenBold = { fg = "#adb92f", bold = true },
        ["@function"] = { fg = "#adb92f" },
        ["@function.call"] = { fg = "#adb92f" },
        ["@function.method"] = { fg = "#adb92f" },
        ["@string"] = { fg = "#adb92f" },
        ["@string.regex"] = { fg = "#adb92f" },

        -- 类型：黄 #fabd2f → 柔和黄  9.7 → 8.4
        Type = { fg = "#e5b143" },
        Typedef = { fg = "#e5b143" },
        GruvboxYellow = { fg = "#e5b143" },
        ["@type"] = { fg = "#e5b143" },
        ["@type.builtin"] = { fg = "#e5b143" },
        ["@type.qualifier"] = { fg = "#e5b143" },

        -- 关键字 / 错误：红 #fb4934 → 柔和红  4.8 → 4.6
        -- 注意：只降饱和度，不改色相，错误仍然是红色
        Keyword = { fg = "#e35d4f" },
        Statement = { fg = "#e35d4f" },
        Conditional = { fg = "#e35d4f" },
        Repeat = { fg = "#e35d4f" },
        Label = { fg = "#e35d4f" },
        Exception = { fg = "#e35d4f" },
        DiagnosticError = { fg = "#e35d4f" },
        DiagnosticSignError = { fg = "#e35d4f" },
        DiagnosticVirtualTextError = { fg = "#e35d4f" },
        DiagnosticUnderlineError = { sp = "#e35d4f", undercurl = true },
        ["@keyword"] = { fg = "#e35d4f" },
        ["@keyword.return"] = { fg = "#e35d4f" },
        ["@keyword.function"] = { fg = "#e35d4f" },
        ["@keyword.conditional"] = { fg = "#e35d4f" },
        ["@keyword.repeat"] = { fg = "#e35d4f" },
        ["@keyword.exception"] = { fg = "#e35d4f" },
        ["@keyword.operator"] = { fg = "#e35d4f" },
        ["@keyword.storage"] = { fg = "#e35d4f" },

        -- ---- 辅助信息（原本太灰，最影响阅读）----
        -- 注释：#928374 → #8a7f72   4.5 → 4.2
        Comment = { fg = "#8a7f72" },
        ["@comment"] = { fg = "#8a7f72" },
        SpecialComment = { fg = "#8a7f72" },
        -- 行号：#7c6f64 → #8a7f72   3.4 → 4.2
        LineNr = { fg = "#8a7f72" },
        -- 空白字符 / 换行符等非文本：#504945 → #6b6158   1.9 → 2.6
        NonText = { fg = "#6b6158" },
        Whitespace = { fg = "#6b6158" },
      },
    },
    config = function(_, opts)
      require("gruvbox").setup(opts)
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  -- 告诉 LazyVim 启动时用哪个主题。
  -- 这个 opts 会合并进 LazyVim 自己的 config，LazyVim 在启动流程里会执行它。
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
