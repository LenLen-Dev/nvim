-- Java 开发环境
--
-- 打底由两个 LazyVim extras 完成（已写入 lazyvim.json）：
--   lazyvim.plugins.extras.lang.java
--     -> nvim-jdtls + jdtls(Eclipse JDT Language Server)：补全 / 跳转 / 引用 /
--        重命名 / 提取变量·方法 / 组织 import / 保存时整理 import
--     -> treesitter java 高亮、java-debug-adapter + java-test 的 mason 安装项
--     -> lombok.jar 已由 mason 的 jdtls 包提供，extra 默认带上 javaagent
--   lazyvim.plugins.extras.dap.core
--     -> nvim-dap / nvim-dap-ui / nvim-dap-virtual-text，<leader>d* 与 <leader>t* 键位
--
-- 本文件只做针对性调整：补齐 mason 包、格式化、Gradle/Spring、构建命令键位。

-- 项目根标记：按「离当前文件最近」逐级向上找，先命中哪个算哪个。
-- 构建文件放在前面，.git 只当兜底——否则像 ~/.git 这种空目录会把根顶到 home。
-- .idea / *.iml 用来兜住 IntelliJ 的「裸项目」（没有 pom/gradle，
-- 比如 ~/Documents/algorithm 下那种，只有一个 .iml 和一个 source root）。
local java_root_markers = {
  "mvnw",
  "mvnw.cmd",
  ".mvn",
  "gradlew",
  "gradlew.bat",
  "settings.gradle",
  "settings.gradle.kts",
  "build.gradle",
  "build.gradle.kts",
  "pom.xml",
  "build.xml",
  ".idea",
  ".git",
}

-- 目录里有没有 *.iml（IntelliJ 模块文件）
local function has_iml(dir)
  for name, kind in vim.fs.dir(dir) do
    if kind == "file" and name:match("%.iml$") then
      return true
    end
  end
  return false
end

-- 逐级向上找项目根。比 vim.fs.root 多几件事：
--   1) 构建文件优先于 .git（vim.fs.root 只看「某层是否命中任意标记」，越外层越容易命中 .git）
--   2) .git 必须是真仓库（目录里有 HEAD），免得空的 ~/.git 把根顶到 home
--   3) 目录里有 *.iml 也算 IntelliJ 项目根（没有 pom/gradle 的裸项目）
local function java_project_root(path)
  local dir = vim.fs.dirname(vim.fs.normalize(path))
  local git_fallback
  while dir and dir ~= "/" and dir ~= vim.fs.dirname(dir) do
    for _, marker in ipairs(java_root_markers) do
      if marker ~= ".git" and vim.uv.fs_stat(dir .. "/" .. marker) then
        return dir
      end
    end
    if has_iml(dir) then
      return dir
    end
    if not git_fallback and vim.uv.fs_stat(dir .. "/.git/HEAD") then
      git_fallback = dir
    end
    dir = vim.fs.dirname(dir)
  end
  return git_fallback
end

-- Java 缩进用 4 空格。
-- LazyVim 全局默认是 2 空格（适合 lua/ts），Java 习惯是 4，所以只在 java buffer 覆盖。
-- 三处必须一致，否则会出现「敲字时一个宽度、保存后另一个宽度」：
--   1) vim 侧 shiftwidth / tabstop / softtabstop（本 autocmd）
--   2) jdtls 侧 java.formatSettings.tabSize（nvim-jdtls 的 opts）
--   3) google-java-format 的 --aosp（conform 的 args）
vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  group = vim.api.nvim_create_augroup("UserJavaIndent", { clear = true }),
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})

-- 在项目根目录跑构建命令，输出留在浮窗里。
-- 交互式命令（run / test / bootRun）用 interactive=true，跑完窗口不关，方便看日志。
local function build(cmd, opts)
  return Snacks.terminal.open(
    cmd,
    vim.tbl_deep_extend("force", {
      cwd = LazyVim.root(),
      interactive = opts and opts.interactive or false,
    }, opts or {})
  )
end

-- ---------------------------------------------------------------------------
-- JDK 选择
--
-- jdtls 本体有 JDK 版本下限（当前 1.62 需要 JDK 25+），而项目编译目标通常是 21/17。
-- 两者必须分开：服务端用「能跑 jdtls 的 JDK」，项目运行时用 java.configuration.runtimes。
-- ---------------------------------------------------------------------------

-- 从 mise 的安装目录里找 JDK（按主版本号升序）
local function mise_jdks()
  local root = vim.fn.expand("~/.local/share/mise/installs/java")
  local found = {}
  for name, kind in vim.fs.dir(root) do
    local path = root .. "/" .. name
    if kind == "directory" and vim.uv.fs_stat(path .. "/bin/javac") and not name:match("^temurin%-%d+$") then
      local version = name:match("temurin%-(%d+)")
      if version then
        table.insert(found, { path = path, version = tonumber(version) })
      end
    end
  end
  table.sort(found, function(a, b)
    return a.version > b.version
  end)
  return found
end

-- jdtls 服务端要用的 JDK：取本机最新的一个（>= 25 优先），找不到就退回 JAVA_HOME / PATH
local function jdtls_jdk()
  for _, jdk in ipairs(mise_jdks()) do
    if jdk.version >= 25 then
      return jdk.path
    end
  end
  local home = os.getenv("JAVA_HOME")
  if home and home ~= "" then
    return home
  end
  return nil
end

-- 取某个 JDK 的主版本号（读 release 文件，比跑 java -version 快且不依赖 PATH）。
-- 注意 JDK 8 的 release 里写的是 JAVA_VERSION="1.8.0_xxx"，要归一成 8。
local function jdk_major(path)
  local f = io.open(path .. "/release", "r")
  if f then
    local content = f:read("*a")
    f:close()
    local legacy = content:match('JAVA_VERSION="1%.(%d+)')
    if legacy then
      return tonumber(legacy)
    end
    local modern = content:match('JAVA_VERSION="(%d+)')
    if modern then
      return tonumber(modern)
    end
  end
  -- 兜底：从目录名里猜
  return tonumber(tostring(path):match("%-(%d+)%.") or "")
end

-- java.configuration.runtimes：告诉 jdtls 本机有哪些 JDK 可用作编译运行时。
-- 两个坑：
--   1) name 必须是 Eclipse 的枚举 JavaSE-1 / JavaSE-8 .. JavaSE-27，
--      写成裸 "21" 会让保存时报 `Invalid runtime for 25`；
--   2) 新版 jdtls 已经不支持 JDK 8 及以下，把它写进来会让每次保存都报
--      `Invalid runtime for JavaSE-8`，所以低于 11 的直接跳过。
-- default 只标项目当前 JDK（JAVA_HOME，一般由 mise 决定）。
local MIN_JDK = 11

local function java_runtimes()
  local runtimes = {}
  local seen = {}
  local home = os.getenv("JAVA_HOME")
  local home_norm = home and vim.fs.normalize(home) or nil

  local function add(path)
    if not path or seen[path] or not vim.uv.fs_stat(path .. "/bin/javac") then
      return
    end
    local major = jdk_major(path)
    if not major or major < MIN_JDK then
      return
    end
    seen[path] = true
    local entry = { path = path, name = "JavaSE-" .. major }
    if home_norm and vim.fs.normalize(path) == home_norm then
      entry.default = true
    end
    table.insert(runtimes, entry)
  end

  -- 项目自己的 JDK（mise / JAVA_HOME）优先
  add(home)
  for _, jdk in ipairs(mise_jdks()) do
    add(jdk.path)
  end
  return runtimes
end

-- 判断项目用 Maven 还是 Gradle：看根目录里有哪些构建入口文件。
local function pick_build_tool()
  local root = LazyVim.root()
  local function has(name)
    return vim.uv.fs_stat(root .. "/" .. name) ~= nil
  end
  if has("pom.xml") or has("mvnw") or has(".mvn") then
    return "maven"
  end
  if has("build.gradle") or has("build.gradle.kts") or has("settings.gradle") or has("gradlew") then
    return "gradle"
  end
  -- 兜底：默认按 Maven 处理，找不到东西时 mvn 会给出可读的报错
  return "maven"
end

-- 有 wrapper 就用 wrapper（版本跟着项目走），否则回退到全局命令。
local function wrapper_or(name, global)
  local local_bin = LazyVim.root() .. "/" .. name
  if vim.uv.fs_stat(local_bin) then
    return local_bin
  end
  return global
end

return {
  -- mason 包补齐：jdtls 本体、调试适配器、测试、格式化器
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "jdtls",
        "java-debug-adapter",
        "java-test",
        "google-java-format",
      },
    },
  },

  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      opts.root_dir = function(path)
        return java_project_root(path)
      end

      local settings = opts.settings or {}
      settings.java = vim.tbl_deep_extend("force", settings.java or {}, {
        -- 保存时由 conform(LSP fallback) -> jdtls 格式化，jdtls 顺手整理 import
        format = { enabled = true },
        -- 只在客户端不支持 textDocument/formatting 时才让服务端自己保存，
        -- 否则会和 conform 抢着改缓冲区，出现「保存后缩进变成 2 空格」的随机行为
        saveActions = { organizeImports = true },
        signatureHelp = { enabled = true },
        contentProvider = { preferred = "fernflower" },
        -- jdtls 侧格式化用 4 空格（Java 通行风格，对齐 IDEA / Eclipse 默认）
        formatSettings = { tabSize = 4, insertSpaces = true },
        completion = {
          favoriteStaticMembers = {
            "org.junit.jupiter.api.Assertions.*",
            "org.assertj.core.api.Assertions.*",
            "java.util.Objects.requireNonNull",
            "java.util.Objects.requireNonNullElse",
            "org.mockito.Mockito.*",
          },
          filteredTypes = {
            "com.sun.*",
            "io.micrometer.shaded.*",
            "java.awt.*",
            "jdk.*",
            "sun.*",
          },
        },
        sources = {
          organizeImports = {
            starThreshold = 9999,
            staticStarThreshold = 9999,
          },
        },
        codeGeneration = {
          toString = { template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}" },
          hashCodeEquals = { useJava7Objects = true },
          useBlocks = true,
        },
        -- 参数名内联提示，对应 IDEA 的 Parameter Hints
        inlayHints = { parameterNames = { enabled = "all" } },
        -- 本机装的所有 JDK 都注册进去，default 标记当前项目的 JDK，
        -- 这样「Run / Debug」用的编译运行时和 mvn/gradle 一致。
        configuration = { runtimes = java_runtimes() },
      })
      opts.settings = settings

      -- 服务端 JDK：jdtls 依赖的 Eclipse 平台会随版本抬高 JDK 下限
      -- （当前 1.62 的 bundle 要求 JavaSE 25），而项目本身可能还在用 21/17。
      -- 所以显式让 jdtls 启动器用「本机能跑它的 JDK」，项目编译目标由
      -- java.configuration.runtimes + mise/JAVA_HOME 决定，两者互不影响。
      local server_jdk = jdtls_jdk()
      if server_jdk and vim.fn.executable(server_jdk .. "/bin/java") == 1 then
        local cmd = vim.deepcopy(opts.cmd or { "jdtls" })
        -- --java-executable 会被 mason 的启动器转发给 java 进程本身，
        -- 且不会传给 jdtls 主程序。
        if not vim.tbl_contains(cmd, "--java-executable") then
          vim.list_extend(cmd, { "--java-executable", server_jdk .. "/bin/java" })
        end
        -- 内存给足，大项目索引时不至于卡死（-Xmx 与启动器自身参数分开）
        opts.cmd = cmd
      end

      -- 所有要加载进 jdtls 的插件 bundle。
      -- 注意顺序：LazyVim 自己的 init_options.bundles（debug / test 适配器）会被
      -- opts.jdtls 里的同名数组整体替换，而不是合并——所以这里必须自己把
      -- java-debug-adapter / java-test 的 jar 一起列全，否则 <leader>dc 调试和
      -- <leader>tt 跑测试会失效（jdtls 不再注册 vscode.java.resolveMainClass）。
      local bundles = {}
      if LazyVim.has("mason.nvim") then
        local registry = require("mason-registry")
        if registry.is_installed("java-debug-adapter") then
          vim.list_extend(
            bundles,
            vim.fn.glob("$MASON/share/java-debug-adapter/com.microsoft.java.debug.plugin-*.jar", false, true)
          )
        end
        if registry.is_installed("java-test") then
          vim.list_extend(bundles, vim.fn.glob("$MASON/share/java-test/*.jar", false, true))
        end
      end
      -- Spring Tools 的 JDT 扩展：application.properties / yml 的键补全、
      -- @RequestMapping 路径提示、运行中应用的 bean 信息都走这里。
      vim.list_extend(bundles, vim.fn.glob("$MASON/share/vscode-spring-boot-tools/jdtls/*.jar", false, true))

      opts.jdtls = vim.tbl_deep_extend("force", opts.jdtls or {}, {
        settings = settings,
        init_options = { bundles = bundles },
      })
      return opts
    end,
  },

  -- 保存时走 conform(LSP fallback) -> jdtls，缩进 4 空格 + 顺带整理 import。
  -- 想强制 Google 风格：<leader>cF 手动选 google-java-format（--aosp 也是 4 空格）。
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        ["google-java-format"] = {
          -- stdin -> stdout，不原地改文件
          command = "google-java-format",
          -- --aosp = 4 空格缩进（不加就是 Google 的 2 空格）
          args = { "--aosp", "-" },
          stdin = true,
        },
      },
    },
  },

  -- treesitter 补上 Gradle 的 groovy / kts 高亮
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "java", "groovy", "kotlin" } },
  },

  -- 构建 / 运行 / 测试键位：<leader>j 组
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>jb",
        function()
          if pick_build_tool() == "maven" then
            build({ wrapper_or("mvnw", "mvn"), "-q", "compile" }, { interactive = false })
          else
            build({ wrapper_or("gradlew", "gradle"), "compileJava", "--console=plain" }, { interactive = false })
          end
        end,
        desc = "编译项目 (compile)",
      },
      {
        "<leader>ju",
        function()
          if pick_build_tool() == "maven" then
            build({ wrapper_or("mvnw", "mvn"), "test" }, { interactive = true })
          else
            build({ wrapper_or("gradlew", "gradle"), "test", "--console=plain" }, { interactive = true })
          end
        end,
        desc = "跑测试 (test)",
      },
      {
        "<leader>jr",
        function()
          if pick_build_tool() == "maven" then
            -- exec-maven-plugin 的 run goal，失败时退回到提示
            build({ wrapper_or("mvnw", "mvn"), "-q", "exec:java" }, { interactive = true })
          else
            build({ wrapper_or("gradlew", "gradle"), "run", "--console=plain" }, { interactive = true })
          end
        end,
        desc = "运行项目 (run)",
      },
      {
        "<leader>jp",
        function()
          if pick_build_tool() == "maven" then
            build({ wrapper_or("mvnw", "mvn"), "package", "-DskipTests" }, { interactive = true })
          else
            build({ wrapper_or("gradlew", "gradle"), "build", "-x", "test", "--console=plain" }, { interactive = true })
          end
        end,
        desc = "打包 (package, 跳过测试)",
      },
      {
        "<leader>js",
        function()
          if pick_build_tool() == "maven" then
            -- 可选 profile 里跑 spring-boot
            build({ wrapper_or("mvnw", "mvn"), "spring-boot:run" }, { interactive = true })
          else
            build({ wrapper_or("gradlew", "gradle"), "bootRun", "--console=plain" }, { interactive = true })
          end
        end,
        desc = "Spring Boot 运行 (bootRun)",
      },
      {
        "<leader>jd",
        function()
          build({ wrapper_or("mvnw", "mvn"), "dependency:tree" }, { interactive = false })
        end,
        desc = "依赖树 (dependency:tree)",
      },
    },
  },
}
