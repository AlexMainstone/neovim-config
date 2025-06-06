return {
  {
    'stevearc/overseer.nvim',
    -- Lazily load when `<leader>dd` is pressed or any Overseer command runs
    cmd = { 'OverseerRun', 'OverseerToggle', 'OverseerQuickAction' },
    keys = {
      {
        '<leader>dd',
        function() end, -- placeholder so Lazy.nvim knows to load this plugin
        desc = 'Overseer: Build & Debug C++ or Debug Python (with ToggleTerm output)',
      },
      {
        '<leader>tbc',
        function() end, -- placeholder
        desc = 'Toggle CMake terminal visibility',
      },
      {
        '<leader>tbn',
        function() end, -- placeholder
        desc = 'Toggle Ninja terminal visibility',
      },
    },
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'mfussenegger/nvim-dap',
      'akinsho/toggleterm.nvim',
    },
    config = function()
      local overseer = require 'overseer'
      local dap_ok, dap = pcall(require, 'dap')
      if not dap_ok then
        vim.notify('[Overseer dd] nvim-dap not found! Install nvim-dap first.', vim.log.levels.ERROR)
        return
      end

      -- Load ToggleTerm
      local toggleterm_ok, toggleterm = pcall(require, 'toggleterm.terminal')
      if not toggleterm_ok then
        vim.notify('[Overseer dd] toggleterm.nvim not found! Install it to redirect output.', vim.log.levels.ERROR)
        return
      end
      local Terminal = toggleterm.Terminal

      -- Telescope components for selecting among multiple executables
      local has_telescope, pickers = pcall(require, 'telescope.pickers')
      local has_finders, finders = pcall(require, 'telescope.finders')
      local has_conf, conf = pcall(require, 'telescope.config')
      local has_actions, actions = pcall(require, 'telescope.actions')
      local has_state, action_state = pcall(require, 'telescope.actions.state')

      if not (has_telescope and has_finders and has_conf and has_actions and has_state) then
        vim.notify('[Overseer dd] Telescope is not fully available; multiple-exe picking will fail.', vim.log.levels.WARN)
      end

      ------------------------------------------------------------------
      -- Ensure Python adapter + configuration exist (for debugpy)
      ------------------------------------------------------------------
      if not dap.adapters.python then
        dap.adapters.python = {
          type = 'executable',
          command = 'python',
          args = { '-m', 'debugpy.adapter' },
        }
      end

      if not dap.configurations.python then
        dap.configurations.python = {
          {
            type = 'python',
            request = 'launch',
            name = 'Debug Current File',
            program = '${file}',
            pythonPath = function()
              return 'python'
            end,
          },
        }
      end

      ------------------------------------------------------------------
      -- Helper: Launch a given .exe path under nvim-dap (C++ codelldb)
      ------------------------------------------------------------------
      local function launch_cpp_debug(build_dir, exe_path)
        dap.run {
          name = 'Debug C++: ' .. vim.fn.fnamemodify(exe_path, ':t'),
          type = 'cppvsdbg', -- assumes you have codelldb configured elsewhere
          request = 'launch',
          program = exe_path,
          cwd = build_dir,
          stopOnEntry = false,
          args = {},
        }
      end

      ------------------------------------------------------------------
      -- Keep ToggleTerm terminals around so we can re‐toggle them later
      ------------------------------------------------------------------
      local cmake_term = nil
      local ninja_term = nil

      ------------------------------------------------------------------
      -- Functions to create (or recreate) terminals if needed
      ------------------------------------------------------------------
      local function create_cmake_term()
        local cwd = vim.fn.getcwd()
        local build_dir = cwd .. '/build'
        return Terminal:new {
          cmd = table.concat({
            'cd ' .. build_dir,
            '&& cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Debug',
            '-DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl ..',
          }, ' '),
          direction = 'float',
          close_on_exit = true, -- automatically close when CMake finishes
          on_exit = function(_, _, exit_code)
            if exit_code ~= 0 then
              vim.notify('[Overseer dd] CMake failed; aborting Ninja + Debug.', vim.log.levels.ERROR)
              return
            end
            -- After CMake succeeds, toggle Ninja terminal
            if not ninja_term then
              ninja_term = create_ninja_term()
            end
            ninja_term:toggle()
          end,
        }
      end

      function create_ninja_term()
        local cwd = vim.fn.getcwd()
        local build_dir = cwd .. '/build'
        return Terminal:new {
          cmd = 'cd ' .. build_dir .. ' && ninja',
          direction = 'float',
          close_on_exit = true, -- automatically close when Ninja finishes
          on_exit = function(_, _, ninja_code)
            if ninja_code ~= 0 then
              vim.notify('[Overseer dd] Ninja failed; aborting debug.', vim.log.levels.ERROR)
              return
            end
            -- After Ninja succeeds, scan for executables
            local exe_list = vim.fn.glob(build_dir .. '/*.exe')
            if exe_list == '' then
              vim.notify('[Overseer dd] No .exe found in ' .. build_dir, vim.log.levels.WARN)
              return
            end
            local executables = vim.split(exe_list, '\n', { trimempty = true })
            if #executables == 1 then
              launch_cpp_debug(build_dir, executables[1])
            else
              if not (has_telescope and has_finders and has_conf and has_actions and has_state) then
                vim.notify('[Overseer dd] Multiple executables found, but Telescope is unavailable.', vim.log.levels.ERROR)
                return
              end
              pickers
                .new({}, {
                  prompt_title = 'Select executable to debug',
                  finder = finders.new_table {
                    results = executables,
                  },
                  sorter = conf.values.generic_sorter {},
                  attach_mappings = function(prompt_bufnr, map)
                    actions.select_default:replace(function()
                      actions.close(prompt_bufnr)
                      local entry = action_state.get_selected_entry()
                      if entry and entry[1] then
                        launch_cpp_debug(build_dir, entry[1])
                      else
                        vim.notify('[Overseer dd] No selection made.', vim.log.levels.WARN)
                      end
                    end)
                    return true
                  end,
                })
                :find()
            end
          end,
        }
      end

      ------------------------------------------------------------------
      -- Core function: build via ToggleTerm → Ninja → debug, or debug Python
      ------------------------------------------------------------------
      local function overseer_build_and_debug()
        local ft = vim.bo.filetype

        --------------------------------------------------------
        -- If filetype == "cpp": run CMake/Ninja with ToggleTerm
        --------------------------------------------------------
        if ft == 'cpp' then
          local cwd = vim.fn.getcwd()
          local build_dir = cwd .. '/build'
          local cache_file = build_dir .. '/CMakeCache.txt'

          -- 1) Create build/ if missing
          if vim.fn.isdirectory(build_dir) == 0 then
            local ok = vim.fn.mkdir(build_dir)
            if ok ~= 1 then
              vim.notify('[Overseer dd] Failed to create build dir: ' .. build_dir, vim.log.levels.ERROR)
              return
            end
          end

          -- Decide if we need to run CMake
          local need_cmake = vim.fn.filereadable(cache_file) == 0

          if need_cmake then
            -- Create or reuse CMake terminal, then toggle
            if not cmake_term then
              cmake_term = create_cmake_term()
            end
            cmake_term:toggle()
          else
            -- Skip CMake, go straight to Ninja
            vim.notify '[Overseer dd] CMake cache found—skipping CMake step.'
            if not ninja_term then
              ninja_term = create_ninja_term()
            end
            ninja_term:toggle()
          end

        --------------------------------------------------------
        -- If filetype == "python": debug via debugpy immediately
        --------------------------------------------------------
        elseif ft == 'python' then
          local file_to_debug = vim.fn.expand '%:p'
          if file_to_debug == '' then
            vim.notify('[Overseer dd] No Python file detected in buffer.', vim.log.levels.WARN)
            return
          end

          -- Launch the current Python file under debugpy
          dap.run {
            name = 'Debug Python: ' .. vim.fn.fnamemodify(file_to_debug, ':t'),
            type = 'python',
            request = 'launch',
            program = file_to_debug,
            cwd = vim.fn.getcwd(),
            stopOnEntry = false,
            args = {},
          }

        --------------------------------------------------------
        -- Otherwise: not supported
        --------------------------------------------------------
        else
          vim.notify('[Overseer dd] This command only works on C++ or Python files.', vim.log.levels.INFO)
        end
      end -- end of overseer_build_and_debug()

      ------------------------------------------------------------
      -- Map <leader>dd in normal mode:
      ------------------------------------------------------------
      vim.keymap.set('n', '<leader>dd', overseer_build_and_debug, { desc = 'Overseer: Build & Debug C++ or Debug Python (with ToggleTerm)' })

      ------------------------------------------------------------
      -- Map <leader>tbc to toggle CMake terminal visibility:
      ------------------------------------------------------------
      vim.keymap.set('n', '<leader>tbc', function()
        if cmake_term then
          cmake_term:toggle()
        else
          vim.notify('[Overseer dd] No CMake terminal to toggle.', vim.log.levels.INFO)
        end
      end, { desc = 'Toggle CMake terminal visibility' })

      ------------------------------------------------------------
      -- Map <leader>tbn to toggle Ninja terminal visibility:
      ------------------------------------------------------------
      vim.keymap.set('n', '<leader>tbn', function()
        if ninja_term then
          ninja_term:toggle()
        else
          vim.notify('[Overseer dd] No Ninja terminal to toggle.', vim.log.levels.INFO)
        end
      end, { desc = 'Toggle Ninja terminal visibility' })
    end, -- end of config function
  }, -- end of plugin spec table
} -- end of return list
