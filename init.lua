vim.g.mapleader = " "

-- 1. Escape with 'jj'
vim.keymap.set('i', 'jj', '<Esc>', { silent = true })

-- 2. Basic Options
vim.opt.number = true
vim.opt.relativenumber = true   
vim.opt.termguicolors = true

-- 3. Simple Terminal (Shortcut: ft = fast terminal) 
vim.keymap.set("n", "ft", ":split term://bash<CR>", { silent = true })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { silent = true })

-- 4. Smart Substitution (Shortcut: ff = fast find)
vim.api.nvim_create_user_command("SmartSub", function()
    vim.ui.input({ prompt = "Replace what? : " }, function(old_word)
        if not old_word or old_word == "" then return end
        vim.ui.input({ prompt = "Replace '" .. old_word .. "' with : " }, function(new_word)
            if not new_word then return end
            local cmd = string.format("%%s/%s/%s/gc", old_word, new_word)
            vim.cmd(cmd)
        end)
    end)
end, {})
vim.keymap.set("n", "ff", ":SmartSub<CR>", { silent = true })

-- ==========================================
-- Theme Configuration (Rose-Pine)
-- ==========================================
vim.api.nvim_set_hl(0, "Normal", { bg = "#191724", fg = "#e0def4" })
vim.api.nvim_set_hl(0, "Comment", { fg = "#6e6a86", italic = true })
vim.api.nvim_set_hl(0, "Statement", { fg = "#ebbcba", bold = true })
vim.api.nvim_set_hl(0, "String", { fg = "#f6c177" })
vim.api.nvim_set_hl(0, "Function", { fg = "#9ccfd8" })

vim.cmd('packadd rose-pine')
require('rose-pine').setup({
    variant = 'main',
    dark_variant = 'main',
    dim_inactive_windows = false,
    extend_background_behind_borders = true,
    enable = {
        terminal = true,
        legacy_highlights = true,
        migrations = true,
    },
    styles = {
        bold = true,
        italic = true,
        transparency = false,
    },
})
vim.cmd.colorscheme('rose-pine')

-- ==========================================
-- Tabline Configuration
-- ==========================================
vim.opt.showtabline = 2

function MyTabLine()
    local s = ""
    for i = 1, vim.fn.tabpagenr('$') do
        if i == vim.fn.tabpagenr() then
            s = s .. "%#TabLineSel#"
        else
            s = s .. "%#TabLine#"
        end
        
        local buflist = vim.fn.tabpagebuflist(i)
        local winnr = vim.fn.tabpagewinnr(i)
        local bufnr = buflist[winnr]
        local file = vim.api.nvim_buf_get_name(bufnr)
        local filename = file ~= "" and file:match("([^/]+)$") or "[No Name]"
        
        s = s .. " " .. i .. ":" .. filename .. " "
    end
    s = s .. "%#TabLineFill#"
    return s
end

vim.o.tabline = "%!v:lua.MyTabLine()"

for i = 1, 9 do
    vim.keymap.set('n', '<M-' .. i .. '>', i .. 'gt', { silent = true })
end

-- ==========================================
-- File Tree Sidebar (Shortcut: <leader>e)
-- ==========================================
local M = {}
local buf_id, win_id = nil, nil
local open_folders = { ["."] = true }

local icons = {
    lua  = "󰢱 ", py   = "󰌠 ", js   = "󰌞 ", jsx  = "󰌞 ",
    ts   = "󰛦 ", tsx  = "󰛦 ", c    = "󰙱 ", h    = "󰙲 ",
    cpp  = "󰙲 ", hpp  = "󰙲 ", java = "󰬷 ", rs   = "󱘗 ",
    go   = "󰟓 ", rb   = "󰴭 ", php  = "󰌭 ", cs   = "󰌛 ",
    swift = "󰛥 ", kt   = "󰌱 ", scala = "󰴩 ", r    = "󰟔 ",
    dart = "󰎙 ", sh   = "󰞷 ", bash = "󰞷 ", zsh  = "󰞷 ",
    sql  = "󰆆 ", html = "󰌝 ", htm  = "󰌝 ", css  = "󰌜 ",
    scss = "󰌜 ", less = "󰌜 ", json = "󰘦 ", yaml = "󰅴 ",
    yml  = "󰅴 ", xml  = "󰅴 ", toml = "󰅴 ", md   = "󰍔 ",
    txt  = "󰈙 ", pdf  = "󰈦 ", zip  = "󰛫 ", tar  = "󰛫 ",
    gz   = "󰛫 ", Makefile = " ", dockerfile = "󰡨 ",
}

local function get_files()
    local handle = io.popen("find . -not -path '*/.*' -not -path '.'")
    if not handle then return {} end
    local list = {}
    for line in handle:lines() do
        local clean = line:gsub("^%./", "")
        if clean ~= "" then
            local parent_dir = clean:match("^(.-)/[^/]+$")
            if not parent_dir or open_folders[parent_dir] then
                table.insert(list, clean)
            end
        end
    end
    handle:close()
    table.sort(list)
    return list
end

local function populate_buffer(b)
    local files = get_files()
    local lines = { "  󰉋 ." }

    for _, f in ipairs(files) do
        local icon = "󰈙 "
        local is_dir = vim.fn.isdirectory(f) == 1
        local basename = f:match("([^/]+)$")

        if is_dir then
            local arrow = open_folders[f] and " " or " "
            icon = arrow .. "󰉋 "
        elseif icons[basename] then
            icon = icons[basename] .. " "
        else
            local ext = f:match("^.+(%..+)$")
            if ext then
                ext = ext:sub(2)
                icon = (icons[ext] or "󰈙 ") .. " "
            else
                icon = "  " .. icon
            end
        end

        local _, count = f:gsub("/", "/")
        local indent = string.rep("  ", count + 1)
        table.insert(lines, indent .. icon .. basename)
    end

    vim.api.nvim_buf_set_option(b, "modifiable", true)
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(b, "modifiable", false)
end

local function handle_selection()
    local line = vim.api.nvim_get_current_line()
    if line:match("󰉋") then
        local dir_name = line:match("󰉋%s+(%S+)")
        if dir_name and dir_name ~= "." then
            open_folders[dir_name] = not open_folders[dir_name]
            populate_buffer(buf_id)
        end
    else
        local filename = line:gsub("^%s*[%W%w]-%s+", ""):gsub("^%s*", "")
        if filename ~= "" then
            local handle = io.popen("find . -name '" .. filename .. "' -not -path '*/.*'")
            if handle then
                local full_path = handle:read("*l")
                handle:close()
                if full_path then
                    vim.cmd("wincmd l")
                    vim.cmd("edit " .. full_path:gsub("^%./", ""))
                end
            end
        end
    end
end

function M.toggle()
    if win_id and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
        win_id, buf_id = nil, nil
        return
    end

    buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf_id, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf_id, "swapfile", false)
    
    populate_buffer(buf_id)

    vim.cmd("topleft vsplit")
    win_id = vim.api.nvim_get_current_win()
    
    vim.api.nvim_win_set_buf(win_id, buf_id)
    vim.api.nvim_win_set_width(win_id, 30)
    
    vim.wo[win_id].winfixwidth = true
    vim.wo[win_id].number = false
    vim.wo[win_id].relativenumber = false
    vim.wo[win_id].signcolumn = "no"

    vim.api.nvim_buf_set_keymap(buf_id, "n", "<CR>", "", { noremap = true, silent = true, callback = handle_selection })
    vim.api.nvim_buf_set_keymap(buf_id, "n", "<2-LeftMouse>", "", { noremap = true, silent = true, callback = handle_selection })
end

vim.keymap.set("n", "<leader>e", M.toggle, { silent = true, noremap = true })

-- ==========================================
-- Clean Custom Key Reader Manager (Strict Filter)
-- ==========================================
local function show_interactive_menu()
    local buf = vim.api.nvim_create_buf(false, true)
    
    local width = 40
    local height = 7
    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)

    local lines = {
        " === Keybinding Manager ===",
        " 1. Add Key",
        " 2. Remove Key",
        " 3. Show  Keys",
        " 4. Close Menu",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local function close_menu()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local function add_new_keybinding()
        close_menu()
        vim.ui.input({ prompt = "What it does : " }, function(action_name)
            if not action_name or action_name == "" then return end
            vim.ui.input({ prompt = "The key : " }, function(key_name)
                if not key_name or key_name == "" then return end
                
                local init_path = vim.fn.stdpath("config") .. "/init.lua"
                local file = io.open(init_path, "a")
                if file then
                    file:write("\n-- NOTE_KEY3: " .. key_name .. " -> " .. action_name)
                    file:close()
                    print("Saved successfully!")
                end
            end)
        end)
    end

    local function remove_keybinding()
        close_menu()
        vim.ui.input({ prompt = "Enter key to remove: " }, function(key_name)
            if not key_name or key_name == "" then return end
            
            local init_path = vim.fn.stdpath("config") .. "/init.lua"
            local file = io.open(init_path, "r")
            if not file then return end
            
            local content = file:read("*a")
            file:close()
            
            local new_content = ""
            for line in content:gmatch("[^\r\n]+") do
                if not line:match("NOTE_KEY3: " .. key_name .. " %->") then
                    new_content = new_content .. line .. "\n"
                end
            end
            
            file = io.open(init_path, "w")
            if file then
                file:write(new_content)
                file:close()
                print("Key removed successfully!")
            end
        end)
    end

    local function show_added_keys()
        close_menu()
        local init_path = vim.fn.stdpath("config") .. "/init.lua"
        local file = io.open(init_path, "r")
        local custom_keys = { " === Your Added Keys ===", "" }
        
        if file then
            for line in file:lines() do
                -- الفلترة المشددة: تجاهل أي سطر يحتوي على كود برمجي أو غير مصنف كـ NOTE_KEY3 حقيقي
                if line:match("%-%- NOTE_KEY3:") and not line:match("file:write") then
                    local clean_text = line:gsub("%-%- NOTE_KEY3: ", "")
                    table.insert(custom_keys, " • " .. clean_text)
                end
            end
            file:close()
        end

        if #custom_keys <= 2 then
            table.insert(custom_keys, " No custom keys found.")
        end

        local b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(b, 0, -1, false, custom_keys)
        
        local w_width = 45
        local w_height = math.min(#custom_keys + 2, 15)
        local w_opts = {
            style = "minimal",
            relative = "editor",
            width = w_width,
            height = w_height,
            row = math.floor((vim.o.lines - w_height) / 2),
            col = math.floor((vim.o.columns - w_width) / 2),
            border = "rounded",
        }
        local w = vim.api.nvim_open_win(b, true, w_opts)
        vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(w, true) end, { buffer = b })
        vim.keymap.set('n', '<Esc>', function() vim.api.nvim_win_close(w, true) end, { buffer = b })
    end

    local function execute_action(action_num)
        if action_num == 1 then
            add_new_keybinding()
        elseif action_num == 2 then
            remove_keybinding()
        elseif action_num == 3 then
            show_added_keys()
        else
            close_menu()
        end
    end

    vim.keymap.set('n', '1', function() execute_action(1) end, { buffer = buf })
    vim.keymap.set('n', '2', function() execute_action(2) end, { buffer = buf })
    vim.keymap.set('n', '3', function() execute_action(3) end, { buffer = buf })
    vim.keymap.set('n', '4', close_menu, { buffer = buf })
    
    vim.keymap.set('n', '<CR>', function()
        local cursor_row = vim.api.nvim_win_get_cursor(win)[1]
        if cursor_row >= 2 and cursor_row <= 5 then
            execute_action(cursor_row - 1)
        else
            close_menu()
        end
    end, { buffer = buf })

    vim.keymap.set('n', 'q', close_menu, { buffer = buf })
    vim.keymap.set('n', '<Esc>', close_menu, { buffer = buf })
end

vim.keymap.set('n', 'wh', show_interactive_menu, { silent = true })
vim.keymap.set('n', '<F2>', show_interactive_menu, { silent = true })


-- NOTE_KEY3: jj -> enter to normal mode

-- NOTE_KEY3: ff -> fast find

-- NOTE_KEY3: ft -> fast terminal