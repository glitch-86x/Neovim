local M = {}

local API_KEY = os.getenv("NVIM_API_KEY") or "your api "
local CURRENT_MODEL = "meta/muse-glimmer-30b"

local history_buf = nil
local history_win = nil
local input_buf = nil
local input_win = nil
local chat_history = {}

local function read_file(filepath)
    filepath = vim.trim(filepath)
    local f = io.open(filepath, "r")
    if not f then return "Error: Cannot read file " .. filepath end
    local content = f:read("*all")
    f:close()
    return content
end

local function write_file(filepath, content)
    filepath = vim.trim(filepath)
    if filepath:match("^/") or filepath:match("%.%.") then
        return "Error: Writing outside the current project directory is restricted for safety."
    end
    local f = io.open(filepath, "w")
    if not f then return "Error: Cannot write file " .. filepath end
    f:write(content)
    f:close()
    vim.cmd("checktime")
    return "Successfully modified/wrote file: " .. filepath
end

local function run_shell_command(cmd)
    cmd = vim.trim(cmd)
    if cmd:match("rm%s+%-rf%s+/%s*") or cmd:match(":(){:|:&};:") then
        return "Error: Dangerous command blocked for safety."
    end
    local obj = vim.system({ "sh", "-c", cmd }, { text = true }):wait()
    local output = (obj.stdout or "") .. (obj.stderr or "")
    if #output > 4000 then
        output = output:sub(1, 4000) .. "\n[Output truncated...]"
    end
    if output ~= "" then
        return output
    else
        return "Command executed with no output (exit code: " .. obj.code .. ")"
    end
end

local function list_project_files()
    local obj = vim.system({ "find", ".", "-maxdepth", "3", "-not", "-path", "*/.*" }, { text = true }):wait()
    if obj.code ~= 0 or not obj.stdout then
        return "Error: Failed to list project files."
    end
    return obj.stdout
end

local function append_to_history(lines)
    vim.schedule(function()
        if history_buf and vim.api.nvim_buf_is_valid(history_buf) then
            vim.api.nvim_buf_set_option(history_buf, "modifiable", true)
            vim.api.nvim_buf_set_lines(history_buf, -1, -1, false, lines)
            vim.api.nvim_buf_set_option(history_buf, "modifiable", false)
            if history_win and vim.api.nvim_win_is_valid(history_win) then
                local line_count = vim.api.nvim_buf_line_count(history_buf)
                vim.api.nvim_win_set_cursor(history_win, { line_count, 0 })
            end
        end
    end)
end

local function prompt_user_for_action(action_type, target, content)
    local prompt_msg = ""
    if action_type == "WRITE" then
        prompt_msg = "AI wants to write/modify file '" .. target .. "'. Allow?"
    elseif action_type == "READ" then
        prompt_msg = "AI wants to read local file '" .. target .. "'. Allow?"
    elseif action_type == "SHELL" then
        prompt_msg = "AI wants to run shell command: [" .. target .. "]. Allow?"
    end

    vim.ui.select({ "Yes", "No" }, {
        prompt = prompt_msg,
    }, function(choice)
        if choice == "Yes" then
            if action_type == "WRITE" then
                local result = write_file(target, content)
                append_to_history({ "System: " .. result })
            elseif action_type == "READ" then
                local file_content = read_file(target)
                append_to_history({ "System: Read file " .. target })
                table.insert(chat_history, {
                    role = "system",
                    content = "Here is the content of the file " .. target .. " requested by the user:\n" .. file_content
                })
            elseif action_type == "SHELL" then
                append_to_history({ "System: Running command: " .. target .. "..." })
                local cmd_output = run_shell_command(target)
                append_to_history({ "System: Command finished." })
                table.insert(chat_history, {
                    role = "system",
                    content = "Output of shell command '" .. target .. "':\n" .. cmd_output
                })
            end
        else
            append_to_history({ "System: Action " .. action_type .. " cancelled by user." })
        end
    end)
end

local function search_web(query)
    local encoded_query = query:gsub(" ", "+")
    local url = "https://html.duckduckgo.com/html/?q=" .. encoded_query
    local obj = vim.system({ "curl", "-sL", "-A", "Mozilla/5.0 (X11; Linux x86_64)", url }, { text = true }):wait()
    if obj.code ~= 0 or not obj.stdout then
        return "Search failed due to network error."
    end
    local results = {}
    for snippet in obj.stdout:gmatch('class="result__snippet[^"]*">(.-)</a>') do
        local clean = snippet:gsub("<[^<>]+>", ""):gsub("&quot;", '"'):gsub("&#x27;", "'")
        table.insert(results, clean)
        if #results >= 5 then break end
    end
    if #results == 0 then 
        return "No results found on the web for this query. Stop searching and answer the user directly based on your internal knowledge." 
    end
    return table.concat(results, "\n---\n")
end
local function fetch_url(url)
    url = vim.trim(url)
    local obj = vim.system({ "curl", "-sL", "-A", "Mozilla/5.0 (X11; Linux x86_64)", url }, { text = true }):wait()
    if obj.code ~= 0 or not obj.stdout then
        return "Error: Failed to fetch URL " .. url
    end
    local text = obj.stdout:gsub("<script[^>]*>.-</script>", "")
                          :gsub("<style[^>]*>.-</style>", "")
                          :gsub("<[^<>]+>", " ")
                          :gsub("%s+", " ")
    if #text > 4000 then
        text = text:sub(1, 4000) .. "\n[Content truncated due to length...]"
    end
    return text
end

-- تم تحسين هذه الدالة لتكون أكثر مرونة في قراءة صيغ الأدوات من الـ AI
local function parse_and_execute_ai_intent(ai_reply)
    local w_file, w_code = ai_reply:match("%[WRITE:%s*([%w%./_-]+)%](.-)%[%/WRITE%]")
    if w_file and w_code then
        vim.schedule(function()
            prompt_user_for_action("WRITE", vim.trim(w_file), vim.trim(w_code))
        end)
        return true
    end

    local r_file = ai_reply:match("%[READ:%s*([%w%./_-]+)%]")
    if r_file then
        vim.schedule(function()
            prompt_user_for_action("READ", vim.trim(r_file), nil)
        end)
        return true
    end

    local shell_cmd = ai_reply:match("%[SHELL:%s*(.-)%]")
    if shell_cmd then
        vim.schedule(function()
            prompt_user_for_action("SHELL", vim.trim(shell_cmd), nil)
        end)
        return true
    end

    if ai_reply:match("%[LIST_FILES%]") then
        append_to_history({ "System: Listing project files..." })
        vim.schedule(function()
            local files_res = list_project_files()
            table.insert(chat_history, {
                role = "system",
                content = "Project files structure:\n" .. files_res
            })
            append_to_history({ "System: File list retrieved. AI is processing..." })
        end)
        return true
    end

    local f_url = ai_reply:match("%[FETCH:%s*(.-)%]")
    if f_url then
        append_to_history({ "System: Fetching URL: " .. f_url .. "..." })
        vim.schedule(function()
            local fetch_res = fetch_url(vim.trim(f_url))
            table.insert(chat_history, {
                role = "system",
                content = "Content fetched from URL '" .. f_url .. "':\n" .. fetch_res
            })
            append_to_history({ "System: Fetch completed. AI is processing results..." })
        end)
        return true
    end

    -- دعم مرن جداً للبحث حتى لو نسي النموذج النقطتين الرأسيتين
    local s_query = ai_reply:match("%[SEARCH:%s*(.-)%]") or ai_reply:match("%[SEARCH%s+(.-)%]")
    if s_query then
        append_to_history({ "System: Searching the web for: " .. s_query .. "..." })
        vim.schedule(function()
            local search_res = search_web(vim.trim(s_query))
            table.insert(chat_history, {
                role = "system",
                content = "Web search results for '" .. s_query .. "':\n" .. search_res
            })
            append_to_history({ "System: Search completed. AI is processing results..." })
        end)
        return true
    end

    return false
end

local function call_api(user_message)
    table.insert(chat_history, { role = "user", content = user_message })
    append_to_history({ "", "User: " .. user_message, "Thinking..." })

    local payload = vim.fn.json_encode({
        model = CURRENT_MODEL,
        messages = chat_history,
        temperature = 0.5,
        top_p = 0.95,
        max_tokens = 4096,
        stream = false
    })

    vim.system({
        "curl", "-s", "https://integrate.api.nvidia.com/v1/chat/completions",
        "-H", "Authorization: Bearer " .. API_KEY,
        "-H", "Content-Type: application/json",
        "-d", payload
    }, { text = true }, function(obj)
        if obj.code ~= 0 then
            append_to_history({ "Error: Failed to connect to API." })
            return
        end

        local ok, decoded = pcall(vim.fn.json_decode, obj.stdout)
        if ok and decoded and decoded.choices and decoded.choices[1] then
            local message = decoded.choices[1].message
            local ai_reply = message.content or message.reasoning or obj.stdout

            table.insert(chat_history, { role = "assistant", content = ai_reply })
            local has_tool = parse_and_execute_ai_intent(ai_reply)

            vim.schedule(function()
                if history_buf and vim.api.nvim_buf_is_valid(history_buf) then
                    vim.api.nvim_buf_set_option(history_buf, "modifiable", true)
                    local line_count = vim.api.nvim_buf_line_count(history_buf)
                    vim.api.nvim_buf_set_lines(history_buf, line_count - 1, line_count, false, {})
                    vim.api.nvim_buf_set_option(history_buf, "modifiable", false)
                end
                -- إذا لم تكن هناك أداة تتنفذ في الخلفية، اعرض رد الـ AI مباشرة
                if not has_tool then
                    local formatted = vim.split(ai_reply, "\n")
                    table.insert(formatted, 1, "AI:")
                    append_to_history(formatted)
                end
            end)
        else
            local extracted = obj.stdout:match('"content"%s*:%s*"(.-)"')
            if extracted then
                local unescaped = extracted:gsub('\\n', '\n'):gsub('\\"', '"')
                table.insert(chat_history, { role = "assistant", content = unescaped })
                local has_tool = parse_and_execute_ai_intent(unescaped)

                vim.schedule(function()
                    if history_buf and vim.api.nvim_buf_is_valid(history_buf) then
                        vim.api.nvim_buf_set_option(history_buf, "modifiable", true)
                        local line_count = vim.api.nvim_buf_line_count(history_buf)
                        vim.api.nvim_buf_set_lines(history_buf, line_count - 1, line_count, false, {})
                        vim.api.nvim_buf_set_option(history_buf, "modifiable", false)
                    end
                    if not has_tool then
                        local formatted = vim.split(unescaped, "\n")
                        table.insert(formatted, 1, "AI:")
                        append_to_history(formatted)
                    end
                end)
            else
                append_to_history({ "API Error / Raw Output: " .. obj.stdout })
            end
        end
    end)
end

local function fetch_provider_models(callback)
    vim.system({
        "curl", "-s", "https://integrate.api.nvidia.com/v1/models",
        "-H", "Authorization: Bearer " .. API_KEY,
        "-H", "Content-Type: application/json"
    }, { text = true }, function(obj)
        local models = {}
        local ok, decoded = pcall(vim.fn.json_decode, obj.stdout)
        if ok and decoded then
            local list = decoded.data or decoded
            if type(list) == "table" then
                for _, item in ipairs(list) do
                    if type(item) == "table" and item.id then
                        table.insert(models, item.id)
                    elseif type(item) == "string" then
                        table.insert(models, item)
                    end
                end
            end
        end
        if #models == 0 then table.insert(models, "meta/muse-glimmer-30b") end
        table.sort(models)
        vim.schedule(function() callback(models) end)
    end)
end

function M.select_model()
    fetch_provider_models(function(models)
        vim.ui.select(models, {
            prompt = "Select AI Model:",
            format_item = function(item) return item == CURRENT_MODEL and (item .. " (current)") or item end,
        }, function(choice)
            if choice then CURRENT_MODEL = choice print("Switched to: " .. CURRENT_MODEL) end
        end)
    end)
end

function M.open_chat_window()
    if not history_buf or not vim.api.nvim_buf_is_valid(history_buf) then
        history_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(history_buf, "buftype", "nofile")
        vim.api.nvim_buf_set_lines(history_buf, 0, -1, false, {
            "# Autonomous AI Agent [Model: " .. CURRENT_MODEL .. "]",
            "--------------------------------------------------"
        })
        vim.api.nvim_buf_set_option(history_buf, "modifiable", false)

        table.insert(chat_history, {
            role = "system",
            content = "You are an autonomous AI agent in Neovim. When you need to search the web, you MUST output EXACTLY this format: [SEARCH: query]. Do not just say you will search without outputting the tag. Available tools: [LIST_FILES], [SHELL: command], [FETCH: url], [SEARCH: query], [READ: file], [WRITE: file]...[/WRITE]."
        })
    end

    if not history_win or not vim.api.nvim_win_is_valid(history_win) then
        local width = math.floor(vim.o.columns * 0.8)
        local height = math.floor(vim.o.lines * 0.8)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)
        history_win = vim.api.nvim_open_win(history_buf, true, {
            style = "minimal", relative = "editor", width = width, height = height - 4, row = row, col = col, border = "rounded"
        })
    end

    if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
        input_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(input_buf, "buftype", "nofile")
    end

    if not input_win or not vim.api.nvim_win_is_valid(input_win) then
        local width = math.floor(vim.o.columns * 0.8)
        local row = math.floor((vim.o.lines - (math.floor(vim.o.lines * 0.8))) / 2) + math.floor(vim.o.lines * 0.8) - 4
        input_win = vim.api.nvim_open_win(input_buf, true, {
            style = "minimal", relative = "editor", width = width, height = 3, row = row + 1, col = math.floor((vim.o.columns - width) / 2), border = "rounded"
        })
    end

    vim.cmd("startinsert")

    vim.keymap.set("i", "<CR>", function()
        local line = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1]
        if not line or line == "" then return end
        vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {})
        call_api(line)
    end, { buffer = input_buf, silent = true })
end

vim.api.nvim_create_user_command("Ai", M.open_chat_window, {})
vim.api.nvim_create_user_command("Model", M.select_model, {})

return M
