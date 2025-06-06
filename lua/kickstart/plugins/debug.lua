-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)
--

local function msg_with_content_length(msg)
  return string.format('Content-Length: %d\r\n\r\n%s', #msg, msg)
end
local function send_payload(client, payload)
  local msg = msg_with_content_length(vim.json.encode(payload))
  client.write(msg)
end

function RunHandshake(self, request_payload)
  local signResult = io.popen('node C:\\Users\\Alex.Mainstone\\AppData\\Local\\nvim\\node\\vsdbg.js ' .. request_payload.arguments.value)
  print(signResult)
  if signResult == nil then
    print('error while signing handshake', vim.log.levels.ERROR)
    return
  end
  local signature = signResult:read '*a'
  signature = string.gsub(signature, '\n', '')
  local response = {
    type = 'response',
    seq = 0,
    command = 'handshake',
    request_seq = request_payload.seq,
    success = true,
    body = {
      signature = signature,
    },
  }
  send_payload(self.client, response)
end

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F5>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<F7>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'cppdbg',
      },
    }
    dap.adapters.cppvsdbg = {
      id = 'cppvsdbg',
      type = 'executable',
      command = 'C:\\Users\\Alex.Mainstone\\AppData\\Local\\nvim-data\\mason\\packages\\cpptools\\extension\\debugAdapters\\vsdbg\\bin\\vsdbg.exe',
      args = { '--interpreter=vscode' },
      options = {
        externalTerminal = true,
        -- logging = {
        --   moduleLoad = false,
        --   trace = true
        -- }
      },
      runInTerminal = true,
      reverse_request_handlers = {
        handshake = RunHandshake,
      },
    }

    local pick_exe_file = function()
      local scan = require 'plenary.scandir'
      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local sorters = require 'telescope.sorters'
      local actions = require 'telescope.actions'
      local action_state = require 'telescope.actions.state'

      local cwd = vim.fn.getcwd() .. '\\build\\'
      local files = scan.scan_dir(cwd, { depth = 2, search_pattern = '%.exe$' })

      if #files == 1 then
        return files[1]
      end
      return coroutine.create(function(coro)
        pickers
          .new({}, {
            prompt_title = 'Select .exe to launch' .. files[1],
            finder = finders.new_table {
              results = files,
            },
            sorter = sorters.get_generic_fuzzy_sorter(),
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                coroutine.resume(coro, selection[1])
              end)
              return true
            end,
          })
          :find()
      end)
    end

    dap.configurations.cpp = {
      {
        name = 'Try vsdbg',
        type = 'cppvsdbg',
        request = 'launch',
        program = pick_exe_file,
        cwd = vim.fn.getcwd(),
        clientID = 'vscode',
        clientName = 'Visual Studio Code',
        externalTerminal = true,
        columnsStartAt1 = true,
        linesStartAt1 = true,
        locale = 'en',
        pathFormat = 'path',
        externalConsole = true,
        -- console = "externalTerminal"
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '',
          play = '',
          step_into = '󰆹',
          step_over = '󰆷',
          step_out = '󰆸',
          step_back = '',
          run_last = '󰘁',
          terminate = '',
          disconnect = '',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close
  end,
}
