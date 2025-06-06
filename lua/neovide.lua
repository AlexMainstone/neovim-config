-- Neovide config

vim.o.guifont = 'FantasqueSansM Nerd Font Mono:h12'

vim.g.neovide_title_background_color = string.format('%x', vim.api.nvim_get_hl(0, { id = vim.api.nvim_get_hl_id_by_name 'Normal' }).bg)
vim.g.neovide_title_text_color = 'pink'
vim.g.neovide_floating_corner_radius = 0.5
vim.g.neovide_remember_window_size = true
vim.g.neovide_cursor_animation_length = 0.150

vim.keymap.set('n', '<C-s>', ':w<CR>') -- Save
vim.keymap.set('v', '<C-c>', '"+y') -- Copy
vim.keymap.set('n', '<C-v>', '"+P') -- Paste normal mode
vim.keymap.set('v', '<C-v>', '"+P') -- Paste visual mode
vim.keymap.set('c', '<C-v>', '<C-R>+') -- Paste command mode
vim.keymap.set('i', '<C-v>', '<ESC>pli') -- Paste insert mode
vim.keymap.set('i', '<C-v>', '<ESC>pli') -- Paste insert mode
vim.keymap.set('i', '<C-BS>', function()
  return vim.api.nvim_replace_termcodes('<C-w>', true, false, true)
end, { expr = true })
vim.keymap.set('t', '<C-BS>', '<C-W>', { noremap = true })
