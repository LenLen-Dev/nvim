# Python 开发环境（LazyVim）使用说明

配置入口：`lua/plugins/python.lua`，依赖 `lazyvim.plugins.extras.lang.python`（已写入 `lazyvim.json`）。

## 组成部分

| 能力 | 提供方 |
| --- | --- |
| 类型检查 / 补全 / 跳转 / 重命名 | pyright（mason 安装） |
| lint + 格式化 + import 排序 | ruff（mason 安装，`ruff_fix` + `ruff_format`） |
| 断点调试 | nvim-dap + debugpy（`debugpy-adapter`）+ nvim-dap-python |
| 虚拟环境切换 | venv-selector.nvim |
| 高亮 / 语法树选中 | treesitter python |
| 运行 / 测试命令 | `<leader>p*` 键位（见下） |

pyright 和 ruff **两个都挂**：pyright 管类型，ruff 管风格，同一份诊断里会分别标成 `[Pyright]` / `[Ruff]`。

## 解释器：必须用项目的 venv

这是最容易出问题的地方。系统 Python（`/usr/bin/python3`，3.14.8）是 Arch 的
「externally managed」，**没有 pip 也不能直接装包**；项目依赖都在 `.venv` 里。

配置会自动找解释器，优先级：

1. `<项目根>/.venv/bin/python`
2. `<项目根>/venv/bin/python`、`<项目根>/.env/bin/python`
3. `$VIRTUAL_ENV`
4. `PATH` 里的 `python3`

「项目根」是按**当前打开的文件**往上找标记（`pyproject.toml` / `setup.py` /
`requirements.txt` / `.git` 等），不是按 nvim 的启动目录——否则从别的 cwd 打开文件会认错。

三处都指向同一个解释器：

| 消费者 | 怎么拿到解释器 |
| --- | --- |
| pyright | `before_init` 里按**该 client 自己的 `root_dir`** 写 `python.pythonPath` / `venvPath` / `venv`（每个项目一份，互不影响） |
| 调试（dap-python） | `resolve_python` 回调 |
| `<leader>p*` 命令 / REPL | `project_python()` |
| `<leader>ft` / `<C-/>` 的 shell | 从终端 cwd 往上找 `.venv`/`venv`/`.env`，设 `VIRTUAL_ENV` + `PATH` |

验证方法：打开项目里的文件，`:lua =vim.lsp.get_clients({name="pyright"})[1].config.settings.python` 看 `pythonPath`。

⚠️ 别把 `pythonPath` 写回静态 `settings`：那样只在 spec 加载时求值一次，整个 session
被「第一个打开的 Python 文件」锁死——先开一个不在项目里的 `.py`，或者中途切到另一个项目，
pyright 就一直用错解释器，第三方库全部 `could not be resolved`。

### 没有 venv 的项目

先用 uv 建一个（`uv` 已装在 `/usr/bin/uv`）：

```bash
cd 你的项目
uv venv --python 3.13     # 建 .venv
uv sync                   # 或 uv pip install -r requirements.txt
```

## 键位

LazyVim 原生 LSP 键位都能用（`gd` 定义、`gr` 引用、`K` 悬停、`<leader>ca` code action、
`<leader>cr` 重命名、`<leader>cf` 格式化）。Python 补充：

| 键位 | 作用 |
| --- | --- |
| `<leader>pr` | 用项目解释器跑当前脚本 |
| `<leader>pt` | 跑整个项目的 pytest |
| `<leader>pf` | 只跑当前文件的 pytest |
| `<leader>pl` | `ruff check .`（全项目 lint） |
| `<leader>pi` | 开 REPL（带 `PYTHONPATH=src`，能 import 到本项目） |
| `<leader>cv` | venv-selector 选虚拟环境 |
| `<leader>db` / `<leader>dc` / `<leader>di` / `<leader>do` | 断点 · 启动/继续 · 单步进入 · 单步跳过 |
| `<leader>dPt` / `<leader>dPc` | 调试当前测试方法 / 测试类 |
| `<leader>du` / `<leader>de` | 调试 UI · 求值 |

## 格式化与 lint 的配置来源

ruff 会读项目里的 `pyproject.toml` / `ruff.toml`。例如：

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B"]
```

格式化走 conform 的 `ruff_fix`（先修 lint 能自动修的，比如 import 排序）再 `ruff_format`，
保存时自动执行。想临时关掉：`:lua vim.b.autoformat = false`。

## 排查

- `:LspInfo` 看 pyright / ruff 有没有都挂上（pyright 比 ruff 慢，刚打开文件时可能只有 ruff）。
- `:ConformInfo` 看当前 buffer 用哪个 formatter。
- pyright 没报第三方库的错？确认 `pythonPath` 指向 `.venv`，而不是 `/usr/bin/python3`：
  `:lua =vim.lsp.get_clients({name="pyright"})[1].config.settings.python.pythonPath`。
- 报 `Import "xxx" could not be resolved`：先看上面那条 `pythonPath`；
  多个项目同时开着时，每个项目的 client 应该各自指向自己的 `.venv`。
- 终端里手敲 `python` 拿到的是系统解释器：看 `echo $VIRTUAL_ENV`，
  为空说明该目录往上没有 `.venv`/`venv`/`.env`（终端只在找到 venv 时才注入环境）。
- 改了 venv 或 `pyproject.toml` 后行为没变：`:LspRestart`。
- 调试时 `ModuleNotFoundError`：说明 `resolve_python` 没拿到 venv，
  用 `:lua =require("dap-python").resolve_python()` 检查。
