return {
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = 'VeryLazy', -- or choose another lazy-loading trigger like "BufReadPost"
    opts = {
      enable = true,
      multiwindow = true,
      max_lines = 0,
      min_window_height = 0,
      line_numbers = true,
      multiline_threshold = 20,
      trim_scope = 'outer',
      mode = 'cursor',
      separator = nil,
      zindex = 20,
      on_attach = nil,
    },
  },
}
