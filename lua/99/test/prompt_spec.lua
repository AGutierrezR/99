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
