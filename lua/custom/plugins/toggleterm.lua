return {
  'akinsho/toggleterm.nvim',
  version = '*',
  opts = {--[[ things you want to change go here]]
  },
  config = function()
    local Terminal = require('toggleterm.terminal').Terminal
    local powershell = Terminal:new { cmd = 'pwsh -NoLogo', hidden = true }
    local function toggle_pwsh()
      powershell:toggle()
    end
    vim.keymap.set('n', '<leader>tt', toggle_pwsh, { noremap = true, silent = true })
    vim.keymap.set('t', '<C-[>', [[<C-\><C-n>]], { noremap = true })
  end,
}
