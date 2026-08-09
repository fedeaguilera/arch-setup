-- Catppuccin Mocha, transparente para que se vea la opacidad de kitty
-- (background_opacity 0.85 en kitty.conf), coherente con Waybar/rofi/SwayNC.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      integrations = {
        neotree = true,
        telescope = true,
        lualine = true,
        bufferline = true,
        cmp = true,
        gitsigns = true,
        treesitter = true,
        which_key = true,
        mason = true,
        noice = true,
        notify = true,
        native_lsp = { enabled = true },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
  -- lualine no detecta el colorscheme solo, hay que pedirle el tema a mano
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = { theme = "catppuccin" },
    },
  },
}
