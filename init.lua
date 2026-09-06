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

-- Quick tab switching with Alt + Number (Alt+1, Alt+2, etc.)
for i = 1, 9 do
    vim.keymap.set('n', '<M-' .. i .. '>', i .. 'gt', { silent = true })
end

-- ==========================================
-- File Tree Sidebar (Shortcut: <leader>e)
-- ==========================================
local M = {}
local buf_id, win_id = nil, nil

local open_folders = {
    ["."] = true,
}

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

    vim.api.nvim_buf_set_keymap(buf_id, "n", "<Right>", "", {
        noremap = true, silent = true,
        callback = function()
            local line = vim.api.nvim_get_current_line()
            if line:match("󰉋") then
                local dir_name = line:match("󰉋%s+(%S+)")
                if dir_name and dir_name ~= "." then
                    open_folders[dir_name] = true
                    populate_buffer(buf_id)
                end
            end
        end
    })

    vim.api.nvim_buf_set_keymap(buf_id, "n", "<Left>", "", {
        noremap = true, silent = true,
        callback = function()
            local line = vim.api.nvim_get_current_line()
            if line:match("󰉋") then
                local dir_name = line:match("󰉋%s+(%S+)")
                if dir_name and dir_name ~= "." then
                    open_folders[dir_name] = false
                    populate_buffer(buf_id)
                end
            end
        end
    })
end

vim.keymap.set("n", "<leader>e", M.toggle, { silent = true, noremap = true })
