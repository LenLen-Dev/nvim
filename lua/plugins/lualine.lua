-- 状态栏（lualine）的两处调整：
--
-- 一、INSERT 模式用 gruvbox 的「加粗绿色」
--   LazyVim 让 lualine 用 theme = "auto"，会匹配到自带的 gruvbox_dark 主题。
--   那个主题里 insert.a 写死用蓝色 #83a598，进插入模式时左边那块是灰蓝色，
--   跟 gruvbox 的绿色语义不符。这里只在主题后面打补丁覆盖 insert 配色。
--   #b8bb26 是 gruvbox 官方亮绿（bright_green / GruvboxGreenBold），
--   写死不跟随 colorscheme.lua 的柔和化调整，保证 INSERT 状态足够醒目。
--
-- 二、消除 c 段中间那块突兀的色块
--   现象：路径区域的 LSP 符号（如 trouble 显示的 "f main(String[])"）前面，
--         那个小图标后面会露出一小块比周围更深的方块。
--   原因有两层：
--     1) gruvbox_dark 主题里 c 段背景用的是 StatusLineNC 的 #3c3836，
--        和 b 段的 #504945 不一样，两段拼接处本来就有颜色断层；
--     2) trouble 的图标（TroubleIcon*）本身没有背景色，trouble 的
--        fix_statusline() 会拿 c 段的 bg 给它补上，
--        于是那块图标就成了一块深色方块。
--   修法：
--     1) 把 c 段背景统一成和 b 段一样的 #504945，断开消失；
--     2) 给 TroubleIcon* 系列高亮组显式设 transparent，
--        让它跟随所在段落的底色，不再自己画方块。

return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    opts.options = opts.options or {}

    -- 取出 lualine 当前主题表（theme="auto" 时它会在 setup 阶段解析，
    -- 这里提前按 gruvbox 解析一份，再打补丁）
    local theme = opts.options.theme
    if type(theme) == "string" then
      local ok, gruvbox = pcall(require, "lualine.themes.gruvbox_" .. vim.o.background)
      theme = (ok and gruvbox) or {}
    end
    theme = theme or {}

    local green = "#b8bb26" -- gruvbox 亮绿，加粗使用
    local bar_bg = "#504945" -- 状态栏统一的底条背景（gruvbox lightgray）

    -- ===== 一、INSERT 用加粗绿色 =====
    theme.insert = theme.insert or {}
    -- a 段：模式名那块，绿底深字加粗，和 normal / command 的块样式一致
    theme.insert.a = { bg = green, fg = "#282828", gui = "bold" }
    -- b / c 段：只把前景色改成绿色，背景沿用下面统一后的底条色
    theme.insert.b = theme.insert.b or {}
    theme.insert.b.fg = green
    theme.insert.c = theme.insert.c or {}
    theme.insert.c.fg = green

    -- ===== 二、统一 c 段背景，消除拼接处的深色块 =====
    -- gruvbox_dark 原本 c 段用 #3c3836（StatusLineNC），跟 b 段的 #504945 不一致。
    -- 全部模式的 c 段都拉齐成 bar_bg，状态栏就是一条连续的底色。
    for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "inactive" }) do
      local sec = theme[mode]
      if sec and sec.c then
        sec.c.bg = bar_bg
      end
    end

    opts.options.theme = theme

    -- ===== 三、让 trouble 的图标不再自带背景块 =====
    -- TroubleIcon* 本身没有 bg，trouble 的 fix_statusline() 会拿 c 段 bg 补上，
    -- 结果图标后面出现一块深色方块。这里显式声明 transparent，
    -- 让它直接使用所在段落的底色。
    -- 放在 ColorScheme 之后执行，避免被主题重新定义覆盖掉。
    local function transparent_trouble_icons()
      for _, kind in ipairs({
        "Method",
        "Function",
        "Constructor",
        "Class",
        "Interface",
        "Enum",
        "Struct",
        "Field",
        "Property",
        "Variable",
        "Constant",
        "Module",
        "Namespace",
        "Package",
        "Event",
      }) do
        local name = "TroubleIcon" .. kind
        local cur = vim.api.nvim_get_hl(0, { name = name, link = false })
        vim.api.nvim_set_hl(0, name, {
          fg = cur.fg,
          bg = nil,
          link = nil,
          bold = cur.bold,
          italic = cur.italic,
        })
      end
    end

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("user_lualine_trouble_icons", { clear = true }),
      callback = transparent_trouble_icons,
    })
    transparent_trouble_icons()
  end,
}
