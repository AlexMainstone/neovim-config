return {
  'lewis6991/satellite.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  config = function()
    require('satellite').setup()
  end,
}
