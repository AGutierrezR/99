local utils = require("99.utils")
local Agents = require("99.extensions.agents")
local Extensions = require("99.extensions")
local Tracking = require("99.state.tracking")
local Window = require("99.window")

local _99_STATE_FILE = "state"
local function default_completion()
  return { source = nil, custom_rules = {} }
end

--- @class _99.StateProps
--- @field model string
--- @field md_files string[]
--- @field prompts _99.Prompts
--- @field ai_stdout_rows number
--- @field display_errors boolean
--- @field auto_add_skills boolean
--- @field provider_override _99.Providers.BaseProvider | nil
--- @field __view_log_idx number
--- @field __tmp_dir string | nil

--- unanswered question -- will i need to queue messages one at a time or
--- just send them all...  So to prepare ill be sending around this state object
--- @class _99.State
--- @field completion _99.Completion
--- @field model string
--- @field md_files string[]
--- @field prompts _99.Prompts
--- @field ai_stdout_rows number
--- @field display_errors boolean
--- @field provider_override _99.Providers.BaseProvider?
--- @field provider_extra_args string[]
--- @field max_retries number
--- @field auto_save_prompts boolean
--- @field prompts_file string
--- @field saved_prompts string[]
--- @field validate_output function?
--- @field rules _99.Agents.Rules
--- @field tracking _99.State.Tracking
--- @field __tmp_dir string | nil
local State = {}
State.__index = State

--- @return _99.StateProps
local function create()
  return {
    model = "opencode/claude-sonnet-4-5",
    md_files = {},
    ai_stdout_rows = 3,
    display_errors = false,
    provider_override = nil,
    tmp_dir = nil,
    auto_save_prompts = true,
    prompts_file = nil,
    saved_prompts = {},
  }
end

--- @param oos _99.Options | _99.State
local function get_tmp_dir(oos)
  local tmp_dir = oos.tmp_dir and type(oos.tmp_dir) == "string" and oos.tmp_dir
    or oos.__tmp_dir and oos.__tmp_dir
    or "./tmp"
  if tmp_dir then
    tmp_dir = vim.fn.expand(tmp_dir)
  end
  return tmp_dir
end

--- @param opts _99.Options
--- @return _99.State.Tracking.Serialized | nil
local function read_state_from_tmp(opts)
  local state_file = utils.named_tmp_file(get_tmp_dir(opts), _99_STATE_FILE)
  return utils.read_file_json_safe(state_file) --[[@as _99.State.Tracking.Serialized]]
end

--- @param opts _99.Options
--- @return _99.State
function State.new(opts)
  local props = create()
  local _99_state = setmetatable(props, State) --[[@as _99.State]]

  _99_state.provider_override = opts.provider
  _99_state.provider_extra_args = opts.provider_extra_args or {}
  _99_state.max_retries = opts.max_retries or 1
  _99_state.validate_output = opts.validate_output
  _99_state.auto_save_prompts = (opts.auto_save_prompts ~= false)
  _99_state.prompts_file = opts.prompts_file
  _99_state.completion = opts.completion or default_completion()
  _99_state.completion.custom_rules = _99_state.completion.custom_rules or {}
  _99_state.completion.files = _99_state.completion.files or {}

  --- Allow overriding prompt templates via opts.prompts.
  --- opts.prompts may be a full prompt-settings module shape:
  ---   { prompts = { role = function() ... end, ... }, tmp_file_location = fn, ... }
  --- or a partial table merged on top of the defaults.
  local default_prompts = require("99.prompt-settings")
  local prompt_overrides = opts.prompts
  if type(prompt_overrides) == "table" then
    local merged = vim.deepcopy(default_prompts)
    if type(prompt_overrides.prompts) == "table" then
      merged.prompts = merged.prompts or {}
      for key, value in pairs(prompt_overrides.prompts) do
        merged.prompts[key] = value
      end
    end
    for key, value in pairs(prompt_overrides) do
      if key ~= "prompts" then
        if default_prompts.prompts and default_prompts.prompts[key] ~= nil then
          merged.prompts = merged.prompts or {}
          merged.prompts[key] = value
        else
          merged[key] = value
        end
      end
    end
    _99_state.prompts = merged
  else
    _99_state.prompts = default_prompts
  end

  local previous = read_state_from_tmp(opts)
  _99_state.tracking = Tracking.new(_99_state, previous)

  _99_state.prompts_file = _99_state.prompts_file or (vim.fn.stdpath("data") .. "/99/prompts.json")
  _99_state.saved_prompts = _99_state:_load_saved_prompts()

  return _99_state
end

function State:sync()
  local tracking = self.tracking:serialize()
  local tmp = self:tmp_dir()
  local file = utils.named_tmp_file(tmp, _99_STATE_FILE)
  utils.write_file_json_safe(tracking, file)
end

--- @return string
function State:tmp_dir()
  return get_tmp_dir(self)
end

--- @return boolean
function State:active()
  _ = self
  if Window.has_active_window() then
    return true
  end

  local qf = vim.fn.getqflist({ winid = 0 })
  return qf.winid ~= 0
end

--- TODO: This is something to understand.  I bet that this is going to need
--- a lot of performance tuning.  I am just reading every file, and this could
--- take a decent amount of time if there are lots of rules.
---
--- Simple perfs:
--- 1. read 4096 bytes at a tiem instead of whole file and parse out lines
--- 2. don't show the docs
--- 3. do the operation once at setup instead of every time.
---    likely not needed to do this all the time.
function State:refresh_rules()
  self.rules = Agents.rules(self)
  Extensions.refresh(self)
end



--- @return string[]
function State:_load_saved_prompts()
  local path = self.prompts_file
  local file = io.open(path, "r")
  if not file then
    return {}
  end
  local content = file:read("*a")
  file:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    return decoded
  end
  return {}
end

--- @param text string
function State:save_prompt(text)
  if not self.auto_save_prompts then
    return
  end
  if type(text) ~= "string" or vim.trim(text) == "" then
    return
  end
  text = vim.trim(text)
  for i, existing in ipairs(self.saved_prompts) do
    if existing == text then
      table.remove(self.saved_prompts, i)
      break
    end
  end
  table.insert(self.saved_prompts, text)
  local dir = vim.fn.fnamemodify(self.prompts_file, ":h")
  vim.fn.mkdir(dir, "p")
  local file = io.open(self.prompts_file, "w")
  if file then
    file:write(vim.json.encode(self.saved_prompts))
    file:close()
  end
end

--- @param text string
function State:delete_saved_prompt(text)
  for i, existing in ipairs(self.saved_prompts) do
    if existing == text then
      table.remove(self.saved_prompts, i)
      break
    end
  end
  local dir = vim.fn.fnamemodify(self.prompts_file, ":h")
  vim.fn.mkdir(dir, "p")
  local file = io.open(self.prompts_file, "w")
  if file then
    file:write(vim.json.encode(self.saved_prompts))
    file:close()
  end
end

return State
