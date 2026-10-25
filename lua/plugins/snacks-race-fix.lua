-- snacks.nvim picker 输入框 BufEnter 竞态修复
--
-- 现象：
--   Error in BufEnter 自动命令 "<buffer=N>":
--   Lua callback: .../snacks/win.lua:491: .../picker/core/input.lua:55:
--   Invalid 'name': Expected Lua string
--
-- 原因（upstream 时序 bug，不是配置问题）：
--   1) picker/core/input.lua 给输入框注册了 BufEnter 回调，第一行是
--      vim.bo[self.win.buf].buftype = "prompt"
--   2) snacks/win.lua 的 M:close() 先把 self.buf = nil，之后才（可能延迟/重试地）
--      真正关窗口、删 buffer。这段窗口期里输入 buffer 仍是当前 buffer，
--      BufEnter 一到就用 nil 当 buffer 号 -> nvim_set_option_value(nil, ...)
--      报 "Invalid 'name': Expected Lua string"。
--
-- 处理：
--   buffer/window 级自动命令触发时，如果 win.buf 已经失效，直接跳过回调。
--   不动插件目录，:Lazy update 不会冲突；上游修复后删掉本文件即可。

return {
  "folke/snacks.nvim",
  config = function(_, opts)
    local Snacks = require("snacks")
    Snacks.setup(opts)

    local W = require("snacks.win")
    if W._buf_guard_patched then
      return
    end
    W._buf_guard_patched = true

    local orig_on = W.on
    function W.on(self, event, cb, opts2)
      if type(cb) == "function" then
        local inner = cb
        cb = function(win, ev)
          -- 只保护绑定到具体 buffer / window 的自动命令；win.buf 已被 close() 置空
          -- 或 buffer 已删除时，回调里任何 vim.bo / vim.b 访问都会炸。
          if opts2 and (opts2.buf or opts2.win) then
            if win.buf == nil or not vim.api.nvim_buf_is_valid(win.buf) then
              return
            end
          end
          return inner(win, ev)
        end
      end
      return orig_on(self, event, cb, opts2)
    end
  end,
}
