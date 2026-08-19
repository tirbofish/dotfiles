require("nvchad.configs.lspconfig").defaults()

local esp_tools = vim.fn.expand "~/.espressif/tools"
vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--enable-config",
    "--query-driver=" .. esp_tools .. "/xtensa-esp-elf/*/*/bin/*," .. esp_tools .. "/riscv32-esp-elf/*/*/bin/*",
  },
})

local servers = { "html", "cssls", "clangd", "zls", "rust_analyzer" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
