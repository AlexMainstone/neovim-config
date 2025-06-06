return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = {
    'nvim-tree/nvim-web-devicons', -- optional but recommended
  },
  config = function()
    require('bufferline').setup {
      options = {
        mode = 'buffers', -- or "tabs"
        numbers = 'none',
        diagnostics = 'nvim_lsp',
        offsets = {
          {
            filetype = 'neo-tree',
            text_align = 'left',
            separator = true,
          },
          {
            filetype = 'dapui_scopes',
            text_align = 'left',
            separator = true,
          },
        },
        show_close_icon = false,
        show_buffer_close_icons = false,
        separator_style = 'thin', -- options: "slant" | "thick" | "thin" | { 'any', 'any' }
        enforce_regular_tabs = false,
      },
    }
  end,
}
