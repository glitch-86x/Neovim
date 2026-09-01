
vim.g.mapleader = " "

-- 1. Escape with 'jj'
-- ==========================================
vim.keymap.set('i', 'jj', '<Esc>', { silent = true })

-- ==========================================
-- 2. File Picker Command (:File) - No Hidden Files
-- ==========================================
vim.api.nvim_create_user_command("File", function()
    local files = {}
    
    -- Use Neovim's system command alternative or filter out hidden files safely
    local handle = io.popen("find . -maxdepth 2 -not -path '*/.*' -not -path './.*'")
    if handle then
        for line in handle:lines() do
            -- Double check to ignore any path containing hidden items
            if not line:match("/%.") and line ~= "." then
                table.insert(files, line)
            end
        end
        handle:close()
    end

    if #files == 0 then
        print("No files found!")
        return
    end

    vim.ui.select(files, {
        prompt = "Choose a file to open: ",
        format_item = function(item)
            return "📁 " .. item
        end,
    }, function(choice)
        if choice then
            vim.cmd("edit " .. choice)
        end
    end)
end, {})

vim.keymap.set("n", "<leader>f", ":File<CR>", { silent = true })


-- ==========================================
-- 3. Directory Switcher Command (:Dir) - Enhanced
-- ==========================================
vim.api.nvim_create_user_command("Dir", function()
    local dirs = {}
    
    table.insert(dirs, "..")

    local handle = io.popen("find . -maxdepth 2 -type d -not -path '*/.*' -not -path './.*'")
    if handle then
        for line in handle:lines() do
            if line ~= "." and line ~= "./" and not line:match("/%.") then
                table.insert(dirs, line)
            end
        end
        handle:close()
    end

    vim.ui.select(dirs, {
        prompt = "Select directory to switch to: ",
        format_item = function(item)
            if item == ".." then
                return "🔙 .. (Parent Directory)"
            end
            return "📂 " .. item
        end,
    }, function(choice)
        if choice then
            vim.cmd("lcd " .. choice)
            print("Switched to: " .. vim.fn.getcwd())
        end
    end)
end, {})

vim.keymap.set("n", "<leader>cd", ":Dir<CR>", { silent = true })





-- ==========================================
-- 1. Simple Terminal (Shortcut: ft = fast terminal ) 
-- ==========================================
vim.keymap.set("n", "ft", ":split term://bash<CR>", { silent = true })

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { silent = true })


-- ==========================================
-- 2. Smart Substitution (Shortcut: ff = fast find )
-- ==========================================
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


vim.opt.termguicolors = true

-- ==========================================
-- ==========================================
-- 1. Simple Terminal (Shortcut: ft = fast terminal ) 
-- ==========================================
vim.keymap.set("n", "ft", ":split term://bash<CR>", { silent = true })

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { silent = true })


-- ==========================================
-- 2. Smart Substitution (Shortcut: ff = fast find )
-- ==========================================
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


vim.opt.termguicolors = true

-- ==========================================
-- File Explorer ; (shortcut = ee ) 
-- ==========================================
vim.keymap.set("n", "ee", ":Ex<CR>", { desc = "Open File Explorer" })


--==========================================
-- theme  for nvim 
--==========================================

vim.opt.termguicolors = true

vim.api.nvim_set_hl(0, "Normal", { bg = "#191724", fg = "#e0def4" })
vim.api.nvim_set_hl(0, "Comment", { fg = "#6e6a86", italic = true })
vim.api.nvim_set_hl(0, "Statement", { fg = "#ebbcba", bold = true })
vim.api.nvim_set_hl(0, "String", { fg = "#f6c177" })
vim.api.nvim_set_hl(0, "Function", { fg = "#9ccfd8" })



-- Load the plugin using Neovim's built-in package manager
vim.cmd('packadd rose-pine')

-- (Optional) Configure Rose Pine variants and options
require('rose-pine').setup({
    variant = 'main',      -- 'main' (default), 'moon', or 'dawn'
    dark_variant = 'main', -- 'main', 'moon', or 'dawn'
    dim_inactive_windows = false,
    extend_background_behind_borders = true,

    enable = {
        terminal = true,
        legacy_highlights = true, -- Improves compatibility with older plugins
        migrations = true,
    },

    styles = {
        bold = true,
        italic = true,
        transparency = false, -- Set to true to remove background
    },
})

-- Apply the colorscheme
vim.cmd.colorscheme('rose-pine')
--- ==========================================
-- Neovim Configuration (Sidebar & Tabs)
-- ==========================================

-- Enable tabline at the top
vim.opt.showtabline = 2

-- Custom Tabline styling
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
-- Sidebar Configuration
-- ==========================================
local sidebar_buf = nil
local sidebar_win = nil

local function toggle_sidebar()
    if sidebar_win and vim.api.nvim_win_is_valid(sidebar_win) then
        vim.api.nvim_win_close(sidebar_win, true)
        sidebar_win = nil
        return
    end

    sidebar_buf = vim.api.nvim_create_buf(false, true)
    
    vim.bo[sidebar_buf].buftype = "nofile"
    vim.bo[sidebar_buf].bufhidden = "wipe"
    vim.bo[sidebar_buf].swapfile = false

    local menu_items = {
        "   >>>>  Sidebar <<<<",
        "  > [1] File Explorer",
        "  > [2] New Tab      ",
        "  --------------------",
    }

    vim.api.nvim_buf_set_lines(sidebar_buf, 0, -1, false, menu_items)

    vim.keymap.set("n", "<CR>", function()
        local current_line = vim.api.nvim_get_current_line()
        
        vim.cmd("wincmd l")

        if current_line:find("1") then
            vim.cmd("Ex")
        elseif current_line:find("2") then
            vim.cmd("tabnew")
        end
    end, { buffer = sidebar_buf, silent = true })

    vim.cmd("topleft vsplit")
    sidebar_win = vim.api.nvim_get_current_win()
    
    vim.api.nvim_win_set_buf(sidebar_win, sidebar_buf)
    vim.cmd("vertical resize 30")
    
    vim.wo[sidebar_win].number = false
    vim.wo[sidebar_win].relativenumber = false
    vim.wo[sidebar_win].signcolumn = "no"
    vim.wo[sidebar_win].cursorline = true
end

-- Commands
vim.api.nvim_create_user_command("Bar", function()
    if not (sidebar_win and vim.api.nvim_win_is_valid(sidebar_win)) then
        toggle_sidebar()
    end
end, {})

vim.api.nvim_create_user_command("Cbar", function()
    if sidebar_win and vim.api.nvim_win_is_valid(sidebar_win) then
        vim.api.nvim_win_close(sidebar_win, true)
        sidebar_win = nil
    end
end, {})

-- Keymaps as requested:
vim.keymap.set("n", "<leader>t", toggle_sidebar, { silent = true })   -- Open sidebar with Space + t
vim.keymap.set("n", "<leader>tc", ":CloseBar<CR>", { silent = true }) -- Close sidebar with Space + t + c- ==========================================
