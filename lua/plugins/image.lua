-- 图片预览：用 snacks.nvim 自带的 image 模块
--
-- 原理：
--   snacks.image 走 Kitty Graphics Protocol 直接在终端里画图。
--   kitty / wezterm / ghostty 都支持，你的终端是 kitty，天然可用。
--   不需要额外装插件（snacks.nvim 已经装了）。
--
-- 使用方式：
--   1) 直接 :e xxx.png 打开图片文件，自动在 buffer 里显示
--   2) Markdown 里写的图片 ![](xx.png)，打开 md 会自动内联显示
--   3) <leader>fp 打开文件选择器，选中图片会显示预览
--
-- 依赖说明：
--   非 PNG 格式（jpg / gif / webp / svg / pdf...）需要 ImageMagick 的 magick 命令转换。
--   Arch 上装：sudo pacman -S imagemagick
--   没装的话只有 PNG 能显示，其他格式退化成普通文本 buffer。
--   查看当前状态：:checkhealth snacks

return {
  "folke/snacks.nvim",
  opts = {
    image = {
      -- 启用图片查看器
      enabled = true,

      -- 支持的格式（在默认列表基础上加了 svg）
      formats = {
        "png",
        "jpg",
        "jpeg",
        "gif",
        "bmp",
        "webp",
        "tiff",
        "heic",
        "avif",
        "svg",
        "mp4",
        "mov",
        "avi",
        "mkv",
        "webm",
        "pdf",
        "icns",
      },

      -- 显示图片的窗口选项：隐藏行号、标志列等干扰元素
      wo = {
        wrap = false,
        number = false,
        relativenumber = false,
        cursorcolumn = false,
        signcolumn = "no",
        foldcolumn = "0",
        list = false,
        spell = false,
        statuscolumn = "",
      },

      -- 文档（Markdown 等）里的图片
      doc = {
        enabled = true,
        -- 在 buffer 里内联渲染
        inline = true,
        -- 内联不支持时退化成浮窗
        float = true,
        -- 单位是「终端格子数」，不是屏幕比例。
        -- 这里 100x40 基本等于「尽量占满当前窗口」，想要小图就调小。
        max_width = 100,
        max_height = 40,
      },
    },
  },
}
