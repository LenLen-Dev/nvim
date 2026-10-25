# Java 开发环境（LazyVim）使用说明

配置入口：`lua/plugins/java.lua`，依赖两个 LazyVim extras（已写入 `lazyvim.json`）：
`lazyvim.plugins.extras.lang.java`、`lazyvim.plugins.extras.dap.core`。

## 组成部分

| 能力 | 提供方 |
| --- | --- |
| 语言服务器 | jdtls（mason 安装，带 lombok.jar 作为 javaagent） |
| 补全 / 跳转 / 重命名 / 提取变量·方法 / 整理 import | nvim-jdtls + jdtls |
| 断点调试 / 单步 / 变量查看 | nvim-dap + nvim-dap-ui + java-debug-adapter |
| 跑单个测试 / 整个测试类 | java-test（jdtls 的测试扩展） |
| Spring Boot | vscode-spring-boot-tools 的 JDT 扩展 bundle（properties/yml 键补全等） |
| 格式化 | conform(LSP fallback) -> jdtls，**4 空格**缩进，保存时整理 import |
| 构建命令 | 本文件里的 `<leader>j*` 键位，自动用 mvnw / gradlew 或全局 mvn / gradle |

## JDK 的两层选择（重要）

jdtls 本体所依赖的 Eclipse 平台对 JDK 有下限（当前 jdtls 1.62 的 bundle 要求 JavaSE 25），
而项目本身的编译目标通常还是 21 / 17。所以两者是**分开**配置的：

- **服务端 JDK**：`jdtls_jdk()` 在 `~/.local/share/mise/installs/java/` 里找 ≥25 的最新 JDK，
  通过 `--java-executable` 传给 jdtls 启动器。装不到就退回 `$JAVA_HOME`。
- **项目 JDK**：`java.configuration.runtimes` 注册本机所有 ≥11 的 JDK，
  `default` 标在 `$JAVA_HOME` 上（也就是 mise / 项目里 `mise.toml` 决定的那个）。
  所以 `mise.toml` 写 `java = "temurin-21"`，jdtls 就会用 JavaSE-21 当编译运行时。

写成 `JavaSE-21` 这种形式是必须的：裸 `"21"` 会让保存报 `Invalid runtime for 25`；
JDK 8 不要注册进去，新版 jdtls 不支持，会在保存时报 `Invalid runtime for JavaSE-8`。

## 键位

LazyVim 原生的 LSP 键位（`gd` 定义、`gr` 引用、`K` 悬停、`<leader>ca` code action、
`<leader>cr` 重命名、`<leader>cf` 格式化…）在 Java 里都可用。Java 专属补充：

| 键位 | 作用 |
| --- | --- |
| `<leader>co` | 整理 import（organize imports） |
| `<leader>cxv` | 提取变量（可视模式下也行） |
| `<leader>cxm` | 提取方法（可视模式） |
| `<leader>cxc` | 提取常量 |
| `<leader>cgs` | 跳到父类实现 |
| `<leader>tt` | 运行整个测试类 |
| `<leader>tr` | 运行光标所在测试方法 |
| `<leader>tT` | 选一个测试运行 |
| `<leader>db` / `<leader>dc` / `<leader>di` / `<leader>do` | 打/取消断点 · 启动/继续 · 单步进入 · 单步跳过 |
| `<leader>du` | 开关调试 UI |
| `<leader>de` | 求值（可视模式下选中后再按） |

构建命令（`<leader>j` 组，输出在浮窗里）：

| 键位 | 作用 |
| --- | --- |
| `<leader>jb` | 编译（`mvn compile` / `gradle compileJava`） |
| `<leader>ju` | 跑测试（`mvn test` / `gradle test`） |
| `<leader>jr` | 运行（`mvn exec:java` / `gradle run`） |
| `<leader>jp` | 打包，跳过测试（`mvn package -DskipTests` / `gradle build -x test`） |
| `<leader>js` | Spring Boot 启动（`mvn spring-boot:run` / `gradle bootRun`） |
| `<leader>jd` | 依赖树（`mvn dependency:tree`） |

> 调试/运行需要项目可解析依赖，第一次索引会从 Maven 仓库拉依赖，会慢一点。


## 缩进：4 空格

Java 用 **4 空格**（对齐 IDEA / Eclipse 默认，也是你 `algorithm/` 里文件的风格）。
LazyVim 全局默认是 2 空格，只在 `java` buffer 覆盖，其它语言不受影响。

三处必须保持一致，否则会出现「敲字时一个宽度、保存后另一个宽度」：

| 位置 | 值 |
| --- | --- |
| vim 侧 `shiftwidth` / `tabstop` / `softtabstop` | 4（`UserJavaIndent` autocmd） |
| jdtls 侧 `java.formatSettings.tabSize` | 4 |
| `google-java-format` 的 `--aosp` | 4 空格 |

想换成别的宽度（比如 2 或 8），这三处要一起改，见 `lua/plugins/java.lua` 顶部的注释。

### 保存时会改的地方

jdtls 格式化除了缩进，还会把数组初始化补上空格：

```java
int[] arr = {3, 1, 2};   // 保存前
int[] arr = { 3, 1, 2 }; // 保存后
```

这是 Eclipse/JDT 的默认风格。想保留 `{3, 1, 2}` 的写法，把保存格式化关掉即可：
`:lua vim.g.autoformat = false`（全局），或 `:lua vim.b.autoformat = false`（仅当前 buffer）。
手动格式化仍可用 `<leader>cf`。

## 第一次用某个新项目时

jdtls 导入项目时会在项目根目录生成 `.project` / `.classpath` / `.settings/`（Eclipse 工程元数据）。
实测 `java.import.generatesMetadataFilesAtProjectRoot = false` 对它不起作用（导入阶段就已经写好了），
所以建议在自己的项目 `.gitignore` 里加上：

```gitignore
.project
.classpath
.settings/
bin/
target/
```


## 排查

- `:LspInfo` / `:checkhealth vim.lsp` 看 jdtls 有没有挂上。
- `:ConformInfo` 看当前 buffer 用的 formatter。
- jdtls 的日志：`~/.local/state/nvim/lsp.log`；
  每个项目的 workspace 在 `~/.cache/nvim/jdtls/<项目名>/`。
- 改了 JDK 却还报 `Invalid runtime`：`rm -rf ~/.cache/nvim/jdtls/<项目名>` 让它重新索引。
