require "nvchad.autocmds"

-- re-theme when pywal regenerates its palette
local wal_json = vim.fn.expand "~/.cache/wal/colors.json"
local wal_mtime = (vim.uv.fs_stat(wal_json) or {}).mtime
vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    local mtime = (vim.uv.fs_stat(wal_json) or {}).mtime
    if mtime and (not wal_mtime or mtime.sec ~= wal_mtime.sec) then
      wal_mtime = mtime
      package.loaded["themes.pywal"] = nil
      require("base46").load_all_highlights()
    end
  end,
})

-- auto-open live preview for typst files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "typst",
  callback = function()
    vim.schedule(function()
      vim.cmd "TypstPreview"
    end)
  end,
})
