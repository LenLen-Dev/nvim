# nvim config

基于 [LazyVim](https://github.com/LazyVim/LazyVim) 的个人 Neovim 配置，日常在 Arch Linux + kitty 上使用。

## 特性

| 能力 | 说明 |
| --- | --- |
| 配色 | gruvbox（hard 对比度）+ 前景色柔和化，见 `lua/plugins/colorscheme.lua` |
| 状态栏 | lualine：INSERT 用加粗绿色，路径段背景拉齐，去掉 trouble 图标的深色块 |
| 启动页 | snacks dashboard，头部换成 `LEESYUU` 字符画 |
| 终端 | `<leader>ft` 在当前文件所属项目根开终端，自动带上项目 venv 环境变量 |
| root 解析 | 避免 root 退化成 `$HOME`（家目录本身是 git 仓库时尤其明显） |
| 图片预览 | snacks.image，走 Kitty Graphics Protocol；Markdown 内联渲染 |
| Java | jdtls + nvim-jdtls + dap + java-test，4 空格缩进，`<leader>j` 构建快捷键 |
| Python | pyright + ruff，自动探测项目 `.venv`，pyright / dap / 终端用同一个解释器 |
| Docker Compose | yamlls + compose schema 补全校验，`<leader>D` 常用 compose 命令 |
| 稳定性 | 一个 snacks.nvim picker 输入框的竞态补丁（上游修复后可删） |

Java / Python 的完整环境说明（JDK 选择、mason 包、常见坑）见 [JAVA.md](./JAVA.md) 和 [PYTHON.md](./PYTHON.md)。

## 目录结构

```
.
├── init.lua                  # 入口，只负责 require("config.lazy")
├── lazyvim.json              # 启用的 LazyVim extras
├── lazy-lock.json            # 插件版本锁定
├── lua/
│   ├── config/
│   │   ├── lazy.lua          # lazy.nvim bootstrap + LazyVim 加载
│   │   ├── options.lua       # 选项 + root_spec 修正
│   │   ├── keymaps.lua       # 终端 cwd / venv 相关键位
│   │   └── autocmds.lua      # （目前为空）
│   └── plugins/              # 按功能拆分的插件 spec
│       ├── colorscheme.lua
│       ├── dashboard.lua
│       ├── docker-compose.lua
│       ├── image.lua
│       ├── java.lua
│       ├── lualine.lua
│       ├── python.lua
│       ├── snacks-race-fix.lua
│       └── example.lua       # LazyVim 模板示例（已禁用，不会加载）
├── JAVA.md / PYTHON.md       # 开发环境笔记
└── stylua.toml               # 格式化配置
```

## 环境要求

- Neovim **≥ 0.11**（当前在 0.12.6 上使用）
- `git`、`ripgrep`、`fd`（LazyVim 需要）
- 可选：[lazygit](https://github.com/jesseduffield/lazygit)、[imagemagick](https://imagemagick.org/)（非 PNG 图片预览需要）
- 图片预览依赖终端支持 Kitty Graphics Protocol（kitty / wezterm / ghostty）
- Java 开发：jdtls 本体需要 **JDK 25+**，项目运行时可以是 11/17/21；脚本会从 `~/.local/share/mise/installs/java` 里自动找
- Python 开发：`python3`，项目里建议有 `.venv`

缺少的 LSP / 格式化工具由 mason 自动安装（首次启动时执行）。

## 安装 / 恢复

```bash
# 先备份已有配置
mv ~/.config/nvim ~/.config/nvim.bak

# 克隆本仓库
git clone <this-repo-url> ~/.config/nvim

# 启动，lazy.nvim 会自动安装插件，mason 会安装 LSP
nvim
```

首次启动后可以检查一下：

```
:Lazy          # 插件状态
:Mason         # LSP / DAP / formatter 安装情况
:checkhealth
```

想严格对齐当前使用的插件版本：

```
:Lazy restore
```

## 自定义键位

| 键位 | 作用 |
| --- | --- |
| `<leader>ft` | 终端（当前文件所属项目根，带 venv 环境） |
| `<leader>fT` | 终端（当前 cwd） |
| `<C-/>` / `<C-_>` / `<C-,>` | 同上，聚焦终端 |
| `<leader>jb` | Java：编译 |
| `<leader>ju` | Java：跑测试 |
| `<leader>jr` | Java：运行项目 |
| `<leader>jp` | Java：打包（跳过测试） |
| `<leader>js` | Java：Spring Boot 运行 |
| `<leader>jd` | Java：依赖树 |
| `<leader>pr` | Python：运行当前脚本 |
| `<leader>pt` | Python：pytest（整个项目） |
| `<leader>pf` | Python：pytest（当前文件） |
| `<leader>pl` | Python：ruff lint |
| `<leader>pi` | Python：打开项目环境的 REPL |
| `<leader>Dc` | compose ps |
| `<leader>Du` | compose up -d |
| `<leader>Dd` | compose down |
| `<leader>Dl` | compose logs -f |
| `<leader>Dr` | compose restart |
| `<leader>Dv` | compose config（校验合并结果） |

其余键位沿用 LazyVim 默认（`<leader>` 为空格，按 `<leader>` 等 which-key 提示即可）。

## 启用 / 禁用功能

- 语言相关能力由 `lazyvim.json` 里的 extras 提供，不需要时从数组里删掉对应项即可。
- 不想用 Java / Python / Docker：删除 `lua/plugins/` 下对应的 `.lua` 和 `lazyvim.json` 里的 extra，然后 `:Lazy clean`。
- 想换回 tokyonight：改 `lua/plugins/colorscheme.lua` 里的 `colorscheme` 并去掉 gruvbox spec。

## License

Apache-2.0（继承自 LazyVim starter 模板）。
