-- neo-tree y nvim-web-devicons ya vienen por defecto en LazyVim; esto solo
-- ajusta un par de opciones para que sea mas comodo como reemplazo del
-- explorador de archivos de VS Code.
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      window = { width = 32 },
      filesystem = {
        follow_current_file = { enabled = true }, -- sigue el archivo abierto
        use_libuv_file_watcher = true, -- refresca solo cuando cambian archivos afuera
      },
      default_component_configs = {
        git_status = {
          symbols = {
            added = "",
            modified = "",
            deleted = "✖",
            renamed = "",
            untracked = "",
            ignored = "",
            unstaged = "",
            staged = "",
            conflict = "",
          },
        },
      },
    },
  },
}
