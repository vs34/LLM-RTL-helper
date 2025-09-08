-- ~/.config/nvim/lua/ai_annotations.lua
-- AI Annotations plugin (robust, avoids out-of-range extmark errors)

local M = {}

M.ns = vim.api.nvim_create_namespace("ai_annotations_ns")

-- plugin state
M.data = {
  entries = {},    -- id -> entry
  by_file = {},    -- file -> { ids ... } (ordered)
  applied = {},    -- id -> { applied = bool, applied_at = ts, skipped = bool }
  json_path = nil
}

-- highlight groups (link to builtin groups)
vim.cmd("highlight default link AiAnnError Error")
vim.cmd("highlight default link AiAnnWarn WarningMsg")
vim.cmd("highlight default link AiAnnSuggest Comment")

-- Helper: Read JSON from path using vim.fn.json_decode
local function read_json(path)
  local f, err = io.open(path, "r")
  if not f then return nil, "cannot open: " .. (path or "<nil>") .. " : " .. tostring(err) end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return nil, "empty json" end
  local ok, tbl = pcall(vim.fn.json_decode, content)
  if not ok or tbl == vim.NIL then return nil, "json decode failed" end
  return tbl
end

-- Populate M.data from JSON table
function M.load_json(path)
  local tbl, err = read_json(path)
  if not tbl then return false, err end
  M.data.entries = {}
  M.data.by_file = {}
  M.data.applied = {}
  M.data.json_path = path

  local entries = tbl.entries or {}
  for _, e in ipairs(entries) do
    if not e.id then
      -- generate a fallback id to avoid crash
      e.id = ("auto-%d"):format(math.random(1, 1e9))
    end
    M.data.entries[e.id] = e
    M.data.applied[e.id] = { applied = false, skipped = false }
    local f = e.file or vim.api.nvim_buf_get_name(0) or "unknown"
    M.data.by_file[f] = M.data.by_file[f] or {}
    table.insert(M.data.by_file[f], e.id)
  end

  -- sort by start_line (if available)
  for f, ids in pairs(M.data.by_file) do
    table.sort(ids, function(a, b)
      local aa = M.data.entries[a] or {}
      local bb = M.data.entries[b] or {}
      return (aa.start_line or 0) < (bb.start_line or 0)
    end)
  end

  return true
end

-- Ensure buffer exists for a file path without switching windows:
-- returns bufnr (and loads buffer contents).
local function ensure_buf_for_file(filepath)
  if not filepath or filepath == "" then
    return vim.api.nvim_get_current_buf()
  end
  local bufnr = vim.fn.bufadd(filepath)    -- adds buffer without loading into window
  vim.fn.bufload(bufnr)
  return bufnr
end

-- clamp a 0-based line index into [0, total_lines-1]
local function clamp_line(bufnr, line0)
  local total = vim.api.nvim_buf_line_count(bufnr)
  if total == 0 then return 0 end
  if line0 < 0 then return 0 end
  if line0 >= total then return total - 1 end
  return line0
end

-- parse replacement string into lines (preserve empty lines correctly)
local function replacement_to_lines(replacement)
  if not replacement then return {} end
  local out = {}
  for s in (replacement .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(out, s)
  end
  return out
end

-- Utility to safely set an extmark at the end-of-line with clamped row
local function set_virtual_text(bufnr, row0, virt_text)
  local safe_row = clamp_line(bufnr, row0)
  -- clear any extmark at that row+ns? not necessary; we clear whole ns per render
  vim.api.nvim_buf_set_extmark(bufnr, M.ns, safe_row, 0, {
    virt_text = virt_text,
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
end

-- Render warnings/errors for all loaded files
function M.render_warnings()
  for file, ids in pairs(M.data.by_file) do
    local bufnr = ensure_buf_for_file(file)
    -- clear plugin namespace for this buffer first
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

    for _, id in ipairs(ids) do
      local e = M.data.entries[id]
      if e and (e.type == "error" or e.type == "warning") then
        -- convert 1-based JSON line numbers to 0-based index
        local start_line = tonumber(e.start_line) or tonumber(e.line) or 1
        local row0 = (start_line - 1)
        row0 = clamp_line(bufnr, row0)
        local msg = tostring(e.message or e.msg or "")
        local icon = (e.type == "error") and "❌ " or "⚠️ "
        local hl = (e.type == "error") and "AiAnnError" or "AiAnnWarn"
        set_virtual_text(bufnr, row0, { {icon .. msg, hl} })
        -- highlight entire line background lightly (optional)
        pcall(vim.api.nvim_buf_add_highlight, bufnr, M.ns, hl, row0, 0, -1)
      end
    end
  end
end

-- Render suggestions as short inline snippets (truncated)
function M.render_suggestions()
  for file, ids in pairs(M.data.by_file) do
    local bufnr = ensure_buf_for_file(file)
    -- clear plugin namespace for buffer first (so warnings/suggestions don't accumulate duplicates)
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

    for _, id in ipairs(ids) do
      local e = M.data.entries[id]
      if not e then goto continue end

      if e.type == "suggestion" then
        if M.data.applied[id] and M.data.applied[id].applied then
          local start_line = tonumber(e.start_line) or tonumber(e.line) or 1
          local row0 = clamp_line(bufnr, start_line - 1)
          set_virtual_text(bufnr, row0, { {"🟢 applied", "Comment"} })
        elseif M.data.applied[id] and M.data.applied[id].skipped then
          local start_line = tonumber(e.start_line) or tonumber(e.line) or 1
          local row0 = clamp_line(bufnr, start_line - 1)
          set_virtual_text(bufnr, row0, { {"⚪ skipped", "Comment"} })
        else
          -- pending suggestion: show truncated form of replacement or diff
          local snippet = ""
          if e.replacement and type(e.replacement) == "string" then
            snippet = e.replacement:gsub("\n", " ▸ ")
          elseif e.diff and type(e.diff) == "string" then
            -- take first added line (+) if present, else first diff line
            local added = e.diff:match("\n%+(.-)\n")
            snippet = added or (e.diff:gsub("\n", " ▸ "))
          else
            snippet = "<suggestion>"
          end
          if #snippet > 120 then snippet = snippet:sub(1, 120) .. "..." end
          local start_line = tonumber(e.start_line) or tonumber(e.line) or 1
          local row0 = clamp_line(bufnr, start_line - 1)
          set_virtual_text(bufnr, row0, { { "++ " .. snippet, "AiAnnSuggest" } })
        end
      end

      ::continue::
    end
  end
end

-- Apply suggestion (single)
function M.apply_suggestion(id)
  local e = M.data.entries[id]
  if not e then return false, "id not found" end
  if e.type ~= "suggestion" then return false, "not a suggestion" end
  if M.data.applied[id] and M.data.applied[id].applied then return false, "already applied" end

  local filepath = e.file
  if not filepath then return false, "entry missing file" end
  local bufnr = ensure_buf_for_file(filepath)

  local start_line = tonumber(e.start_line) or tonumber(e.line) or 1
  local end_line = tonumber(e.end_line) or start_line
  local start0 = clamp_line(bufnr, start_line - 1)
  local end0 = clamp_line(bufnr, end_line - 1)

  -- compute replacement lines
  local new_lines = {}
  if e.replacement and type(e.replacement) == "string" then
    new_lines = replacement_to_lines(e.replacement)
  elseif e.diff and type(e.diff) == "string" then
    -- extremely simple unified-diff extraction: collect '+' lines (not '+++')
    for line in (e.diff .. "\n"):gmatch("([^\n]*)\n") do
      if line:match("^%+") and not line:match("^%+%+%+") then
        table.insert(new_lines, line:sub(2))
      end
    end
    -- fallback: if no + lines, try to get all non-@@ context
    if #new_lines == 0 then
      for line in (e.diff .. "\n"):gmatch("([^\n]*)\n") do
        if not line:match("^@@") and not line:match("^%-") then
          table.insert(new_lines, line)
        end
      end
    end
  else
    return false, "no replacement/diff provided"
  end

  -- perform the edit (this creates an undo entry)
  vim.api.nvim_buf_set_lines(bufnr, start0, end0 + 1, false, new_lines)

  -- mark as applied
  M.data.applied[id] = { applied = true, applied_at = os.date("!%Y-%m-%dT%TZ") }

  -- adjust subsequent entry line numbers in same file (simple delta)
  local old_count = (end0 - start0 + 1)
  local new_count = #new_lines
  local delta = new_count - old_count
  if delta ~= 0 then
    local ids = M.data.by_file[filepath] or {}
    for _, other_id in ipairs(ids) do
      if other_id ~= id then
        local oe = M.data.entries[other_id]
        if oe and oe.start_line and tonumber(oe.start_line) > end_line then
          oe.start_line = tonumber(oe.start_line) + delta
          if oe.end_line then oe.end_line = tonumber(oe.end_line) + delta end
        end
      end
    end
  end

  -- re-render for that file
  pcall(M.render_suggestions)
  pcall(M.render_warnings)
  return true
end

-- Skip suggestion (mark as skipped)
function M.skip_suggestion(id)
  if not M.data.entries[id] then return false, "id not found" end
  M.data.applied[id] = { applied = false, skipped = true }
  pcall(M.render_suggestions)
  return true
end

-- Open review buffer showing all suggestions (patch-like)
function M.open_review()
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {}
  table.insert(lines, "AI Review - patch view")
  table.insert(lines, ("Loaded from: %s"):format(tostring(M.data.json_path or "<none>")))
  table.insert(lines, "----")
  for id, e in pairs(M.data.entries) do
    if e.type == "suggestion" then
      local status = (M.data.applied[id] and M.data.applied[id].applied) and "[APPLIED]" or ((M.data.applied[id] and M.data.applied[id].skipped) and "[SKIPPED]" or "[PENDING]")
      table.insert(lines, ("-- %s %s %s:%s-%s"):format(status, id, tostring(e.file or "<nofile>"), tostring(e.start_line or e.line or "?"), tostring(e.end_line or e.start_line or e.line or "?")))
      if e.message then table.insert(lines, ("   msg: %s"):format(e.message)) end
      if e.replacement then
        table.insert(lines, "   replacement:")
        for _, l in ipairs(replacement_to_lines(e.replacement)) do table.insert(lines, "     " .. l) end
      elseif e.diff then
        table.insert(lines, "   diff:")
        for line in (e.diff .. "\n"):gmatch("([^\n]*)\n") do table.insert(lines, "     " .. line) end
      end
      table.insert(lines, "")
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "ai-review")
  -- open in a vertical split at the right
  vim.api.nvim_command("botright vsplit")
  vim.api.nvim_win_set_buf(0, buf)

  -- keymaps local to review buffer
  local opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(buf, "n", "ga", "<Cmd>lua require('ai_annotations').review_apply_current()<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "gs", "<Cmd>lua require('ai_annotations').review_skip_current()<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "gA", "<Cmd>lua require('ai_annotations').review_apply_all()<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>bd!<CR>", opts)
  print("AI Review opened. Use ga (apply), gs (skip), gA (apply all), q (close).")
end

-- helper: parse id at current review line
function M._get_review_id_at_cursor()
  local line = vim.api.nvim_get_current_line()
  -- line example: "-- [PENDING] id file:12-12"
  local id = line:match("%S+%s+([%w%-%_%.]+)%s+[%w%-%_%.]+:%d+%-%d+")
  if not id then
    -- alternate match: -- [PENDING] id ...
    id = line:match("%[%u+%]%s+([%w%-%_%.]+)")
  end
  return id
end

function M.review_apply_current()
  local id = M._get_review_id_at_cursor()
  if not id then print("No suggestion id at cursor") return end
  local ok, err = M.apply_suggestion(id)
  if not ok then print("apply failed: " .. tostring(err)) else print("applied " .. id) end
end

function M.review_skip_current()
  local id = M._get_review_id_at_cursor()
  if not id then print("No suggestion id at cursor") return end
  local ok, err = M.skip_suggestion(id)
  if not ok then print("skip failed: " .. tostring(err)) else print("skipped " .. id) end
end

function M.review_apply_all()
  for id, e in pairs(M.data.entries) do
    if e.type == "suggestion" and not (M.data.applied[id] and M.data.applied[id].applied) then
      pcall(function() M.apply_suggestion(id) end)
    end
  end
  print("applied all suggestions (attempted)")
end

-- Export applied suggestions to JSON
function M.export_patch(path)
  local out = { meta = { exported_at = os.date("!%Y-%m-%dT%TZ") }, applied = {} }
  for id, st in pairs(M.data.applied) do
    if st and st.applied then
      local e = M.data.entries[id]
      table.insert(out.applied, { id = id, file = e.file, start_line = e.start_line, end_line = e.end_line, applied_at = st.applied_at })
    end
  end
  local s = vim.fn.json_encode(out)
  local f, err = io.open(path, "w")
  if not f then return false, "cannot open " .. tostring(err) end
  f:write(s)
  f:close()
  return true
end

-- Commands setup (use safe API)
function M.setup_cmds()
  vim.api.nvim_create_user_command("AILoad", function(opts)
    local path = opts.args
    if path == "" then print("Usage: :AILoad /path/to/file.json") return end
    local ok, err = M.load_json(path)
    if not ok then print("Load error: " .. tostring(err)) return end
    pcall(M.render_warnings)
    pcall(M.render_suggestions)
    print("AI annotations loaded from " .. path)
  end, { nargs = 1 })

  vim.api.nvim_create_user_command("AIWarnings", function() pcall(M.render_warnings) end, {})
  vim.api.nvim_create_user_command("AISuggest", function() pcall(M.render_suggestions) end, {})
  vim.api.nvim_create_user_command("AIReview", function() pcall(M.open_review) end, {})
  vim.api.nvim_create_user_command("AIApply", function(opts) local ok, err = M.apply_suggestion(opts.args) if not ok then print("apply failed: "..tostring(err)) else print("applied "..opts.args) end end, { nargs = 1 })
  vim.api.nvim_create_user_command("AISkip", function(opts) local ok, err = M.skip_suggestion(opts.args) if not ok then print("skip failed: "..tostring(err)) else print("skipped "..opts.args) end end, { nargs = 1 })
  vim.api.nvim_create_user_command("AIExport", function(opts) local ok, err = M.export_patch(opts.args) if not ok then print("export failed: "..tostring(err)) else print("exported to "..opts.args) end end, { nargs = 1 })
end

-- convenience loader
function M.load_json_and_render(path)
  local ok, err = M.load_json(path)
  if not ok then print("load err: " .. tostring(err)) return end
  pcall(M.render_warnings)
  pcall(M.render_suggestions)
  print("Loaded " .. (path or "<none>"))
end

function M.setup()
  M.setup_cmds()
end

return M

