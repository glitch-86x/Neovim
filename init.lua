-- ==========================================
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
