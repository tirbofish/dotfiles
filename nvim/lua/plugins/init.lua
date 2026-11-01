return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "coder/claudecode.nvim",
    cmd = { "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeAdd", "ClaudeCodeSend" },
    opts = { terminal = { provider = "native" } },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude toggle" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude focus" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude add buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude send selection" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude deny diff" },
    },
  },

  -- typst: live preview in browser (:TypstPreview), cursor-synced
  {
    "chomosuke/typst-preview.nvim",
    ft = "typst",
    version = "1.*",
    opts = { dependencies_bin = { tinymist = "tinymist" } }, -- reuse mason's tinymist
    keys = { { "<leader>tp", "<cmd>TypstPreviewToggle<cr>", ft = "typst", desc = "Typst preview" } },
  },

  -- latex: \ll toggles continuous compile, zathura auto-reloads on save
  {
    "lervag/vimtex",
    lazy = false, -- vimtex must not be lazy-loaded
    init = function()
      vim.g.vimtex_view_method = "zathura"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "vim", "lua", "vimdoc", "html", "css", "c", "cpp", "cmake", "kconfig", "rust", "zig", "typst" },
    },
  },
}
