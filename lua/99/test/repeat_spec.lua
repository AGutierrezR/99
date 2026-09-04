-- luacheck: globals describe it assert
local _99 = require("99")
local test_utils = require("99.test.test_utils")
local eq = assert.are.same
local Levels = require("99.logger.level")

local content = {
  "local function foo()",
  "    -- TODO: implement",
  "end",
}

describe("repeat last request", function()
  it("repeats the last search with the same prompt", function()
    local p = test_utils.test_setup(content, 1, 1, "lua")
    local state = _99.__get_state()

    local prompt = "find the bug"
    _99.search({ additional_prompt = prompt })
    eq(1, state.tracking:active_count())
    eq(prompt, p.request.prompt.user_prompt)
    eq("search", p.request.prompt.operation)

    p:resolve("success", "no results")
    test_utils.next_frame()
    eq(0, state.tracking:active_count())

    _99.repeat_last()
    eq(1, state.tracking:active_count())
    eq(prompt, p.request.prompt.user_prompt)
    eq("search", p.request.prompt.operation)

    p:resolve("success", "no results")
    test_utils.next_frame()
    eq(0, state.tracking:active_count())
  end)

  it("returns nil and warns when there are no previous requests", function()
    local p = test_utils.test_setup(content, 1, 1, "lua")
    local state = _99.__get_state()

    eq(0, state.tracking:active_count())
    assert.is_nil(_99.repeat_last())
    eq(0, state.tracking:active_count())
    assert.is_nil(p.request)
  end)

  it("repeats a visual request against the current selection", function()
    local p, buffer = test_utils.test_setup(content, 1, 1, "lua")
    local state = _99.__get_state()

    vim.fn.setpos("'<", { buffer, 2, 1, 0 })
    vim.fn.setpos("'>", { buffer, 2, 6, 0 })

    local prompt = "make this cleaner"
    _99.visual({ additional_prompt = prompt })
    eq(1, state.tracking:active_count())
    eq(prompt, p.request.prompt.user_prompt)
    eq("    -- TODO: implement", p.request.prompt:visual_data().range:to_text())

    p:resolve("success", "cleaned")
    test_utils.next_frame()
    eq(0, state.tracking:active_count())

    vim.fn.setpos("'<", { buffer, 1, 1, 0 })
    vim.fn.setpos("'>", { buffer, 1, 1, 0 })

    _99.repeat_last()
    eq(1, state.tracking:active_count())
    eq(prompt, p.request.prompt.user_prompt)
    eq("visual", p.request.prompt.operation)
    eq("local function foo()", p.request.prompt:visual_data().range:to_text())

    p:resolve("success", "done")
    test_utils.next_frame()
    eq(0, state.tracking:active_count())
  end)

  it("repeats the last request with its additional rules", function()
    local rule_path = vim.fn.tempname()
    local rule_file = io.open(rule_path, "w")
    assert.is_not_nil(rule_file)
    rule_file:write("rule content marker")
    rule_file:close()

    local p = test_utils.test_setup(content, 1, 1, "lua")
    local state = _99.__get_state()

    _99.search({
      additional_prompt = "apply the rule",
      additional_rules = { { name = "custom", path = rule_path } },
    })
    eq(1, state.tracking:active_count())
    assert.truthy(p.request.query:find("rule content marker", 1, true))

    p:resolve("success", "no results")
    test_utils.next_frame()
    eq(0, state.tracking:active_count())

    _99.repeat_last()
    eq(1, state.tracking:active_count())
    assert.truthy(p.request.query:find("rule content marker", 1, true))

    p:resolve("success", "no results")
    test_utils.next_frame()
    eq(0, state.tracking:active_count())
  end)
end)