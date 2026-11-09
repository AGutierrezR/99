-- luacheck: globals describe it assert
local _99 = require("99")
local test_utils = require("99.test.test_utils")
local Prompt = require("99.prompt")
local eq = assert.are.same

describe("prompt", function()
  it("should deserialize a serialized prompt", function()
    local provider = test_utils.TestProvider.new()
    _99.setup(test_utils.get_test_setup_options({}, provider))

    local state = _99.__get_state()
    local prompt = Prompt.deserialize(state, {
      user_prompt = "find important changes",
      data = {
        type = "search",
        qfix_items = {},
        response = "",
      },
    })

    eq("search", prompt.operation)
    eq("search", prompt.data.type)
    eq("find important changes", prompt.user_prompt)
    eq("search: find important changes", prompt:summary())
  end)

  it("auto-saves successful prompt", function()
    local provider = test_utils.TestProvider.new()
    _99.setup(test_utils.get_test_setup_options({}, provider))

    _99.search({ additional_prompt = "saved prompt text" })
    provider:resolve("success", "ok")
    test_utils.next_frame()

    local state = _99.__get_state()
    local found = false
    for _, p in ipairs(state.saved_prompts) do
      if p == "saved prompt text" then
        found = true
      end
    end
    assert.is_true(found)
  end)

  it("deletes saved prompt", function()
    local provider = test_utils.TestProvider.new()
    _99.setup(test_utils.get_test_setup_options({}, provider))

    local state = _99.__get_state()
    state:save_prompt("to delete")

    local original_select = vim.ui.select
    local called = false
    vim.ui.select = function(_, _, cb)
      if not called then
        called = true
        cb("to delete")
      else
        cb(nil)
      end
    end
    _99.delete_saved_prompt()
    vim.ui.select = original_select

    local found = false
    for _, p in ipairs(state.saved_prompts) do
      if p == "to delete" then
        found = true
      end
    end
    assert.is_false(found)
  end)

  it("injects role prompt into agent_context on finalize", function()
    local provider = test_utils.TestProvider.new()
    _99.setup(test_utils.get_test_setup_options({}, provider))

    local state = _99.__get_state()
    local prompt = Prompt.search(state)
    prompt:finalize()
    local joined = table.concat(prompt:content(), "\n")
    assert.is_true(
      joined:find("software engineering assistant", 1, true) ~= nil
    )
  end)
end)
