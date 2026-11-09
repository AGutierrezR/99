-- luacheck: globals describe it assert
local eq = assert.are.same
local Providers = require("99.providers")

describe("providers", function()
  describe("OpenCodeProvider", function()
    it("builds correct command with model", function()
      local request = { model = "anthropic/claude-sonnet-4-5" }
      local cmd =
        Providers.OpenCodeProvider._build_command(nil, "test query", request)
      eq({
        "opencode",
        "run",
        "--agent",
        "build",
        "-m",
        "anthropic/claude-sonnet-4-5",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq(
        "opencode/claude-sonnet-4-5",
        Providers.OpenCodeProvider._get_default_model()
      )
    end)
  end)

  describe("ClaudeCodeProvider", function()
    it("builds correct command with model", function()
      local request = { model = "anthropic/claude-sonnet-4-5" }
      local cmd =
        Providers.ClaudeCodeProvider._build_command(nil, "test query", request)
      eq({
        "claude",
        "--dangerously-skip-permissions",
        "--model",
        "anthropic/claude-sonnet-4-5",
        "--print",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("claude-sonnet-4-5", Providers.ClaudeCodeProvider._get_default_model())
    end)
  end)

  describe("CopilotProvider", function()
    it("builds correct command with model", function()
      local request = { model = "claude-sonnet-4.5" }
      local cmd =
        Providers.CopilotProvider._build_command(nil, "test query", request)
      eq({
        "copilot",
        "--allow-all",
        "--model",
        "claude-sonnet-4.5",
        "--prompt",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("claude-sonnet-4.5", Providers.CopilotProvider._get_default_model())
    end)
  end)

  describe("CursorAgentProvider", function()
    it("builds correct command with model", function()
      local request = { model = "anthropic/claude-sonnet-4-5" }
      local cmd =
        Providers.CursorAgentProvider._build_command(nil, "test query", request)
      eq({
        "cursor-agent",
        "--model",
        "anthropic/claude-sonnet-4-5",
        "--print",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("sonnet-4.5", Providers.CursorAgentProvider._get_default_model())
    end)
  end)

  describe("GeminiCLIProvider", function()
    it("builds correct command with model", function()
      local request = { model = "gemini-2.5-pro" }
      local cmd =
        Providers.GeminiCLIProvider._build_command(nil, "test query", request)
      eq({
        "gemini",
        "--approval-mode",
        "auto_edit",
        "--model",
        "gemini-2.5-pro",
        "--prompt",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("auto", Providers.GeminiCLIProvider._get_default_model())
    end)
  end)

  describe("PiProvider", function()
    it("builds correct command with model", function()
      local request = { model = "anthropic/claude-sonnet-4-5" }
      local cmd =
        Providers.PiProvider._build_command(nil, "test query", request)
      eq({
        "pi",
        "--print",
        "--model",
        "anthropic/claude-sonnet-4-5",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq(
        "anthropic/claude-sonnet-4-5",
        Providers.PiProvider._get_default_model()
      )
    end)
  end)

  describe("provider integration", function()
    it("can be set as provider override", function()
      local _99 = require("99")

      _99.setup({ provider = Providers.ClaudeCodeProvider })
      local state = _99.__get_state()
      eq(Providers.ClaudeCodeProvider, state.provider_override)
    end)

    it(
      "uses OpenCodeProvider default model when no provider or model specified",
      function()
        local _99 = require("99")

        _99.setup({})
        local state = _99.__get_state()
        eq("opencode/claude-sonnet-4-5", state.model)
      end
    )

    it(
      "uses ClaudeCodeProvider default model when provider specified but no model",
      function()
        local _99 = require("99")

        _99.setup({ provider = Providers.ClaudeCodeProvider })
        local state = _99.__get_state()
        eq("claude-sonnet-4-5", state.model)
      end
    )

    it(
      "uses CursorAgentProvider default model when provider specified but no model",
      function()
        local _99 = require("99")

        _99.setup({ provider = Providers.CursorAgentProvider })
        local state = _99.__get_state()
        eq("sonnet-4.5", state.model)
      end
    )

    it(
      "uses GeminiCLIProvider default model when provider specified but no model",
      function()
        local _99 = require("99")

        _99.setup({ provider = Providers.GeminiCLIProvider })
        local state = _99.__get_state()
        eq("auto", state.model)
      end
    )

    it(
      "uses CopilotProvider default model when provider specified but no model",
      function()
        local _99 = require("99")

        _99.setup({ provider = Providers.CopilotProvider })
        local state = _99.__get_state()
        eq("claude-sonnet-4.5", state.model)
      end
    )

    it(
      "uses PiProvider default model when provider specified but no model",
      function()
        local _99 = require("99")

        _99.setup({ provider = Providers.PiProvider })
        local state = _99.__get_state()
        eq("anthropic/claude-sonnet-4-5", state.model)
      end
    )

    it("uses custom model when both provider and model specified", function()
      local _99 = require("99")

      _99.setup({
        provider = Providers.ClaudeCodeProvider,
        model = "custom-model",
      })
      local state = _99.__get_state()
      eq("custom-model", state.model)
    end)
  end)

  describe("provider_extra_args", function()
    it("stores provider_extra_args on state", function()
      local _99 = require("99")
      _99.setup({
        provider_extra_args = { "--no-session-persistence" },
      })
      local state = _99.__get_state()
      eq({ "--no-session-persistence" }, state.provider_extra_args)
    end)

    it("defaults provider_extra_args to empty table", function()
      local _99 = require("99")
      _99.setup({})
      local state = _99.__get_state()
      eq({}, state.provider_extra_args)
    end)
  end)

  describe("BaseProvider", function()
    it("all providers have make_request", function()
      eq("function", type(Providers.OpenCodeProvider.make_request))
      eq("function", type(Providers.ClaudeCodeProvider.make_request))
      eq("function", type(Providers.CursorAgentProvider.make_request))
      eq("function", type(Providers.GeminiCLIProvider.make_request))
      eq("function", type(Providers.CopilotProvider.make_request))
      eq("function", type(Providers.PiProvider.make_request))
    end)

    it("falls back to stdout when tmp_file is empty", function()
      local _99 = require("99")
      _99.setup({})

      local state = _99.__get_state()
      local Prompt = require("99.prompt")
      local context = Prompt.search(state)
      context.tmp_file = vim.fn.tempname()
      local file = io.open(context.tmp_file, "w")
      file:write("")
      file:close()

      local stdout_provider = setmetatable({}, { __index = Providers.BaseProvider })
      function stdout_provider._build_command(_, _, _)
        return { "bash", "-c", "echo 'stdout response'" }
      end
      function stdout_provider._get_provider_name()
        return "stdout_test"
      end

      local result = nil
      local completed = false
      local observer = {
        on_start = function() end,
        on_stdout = function() end,
        on_stderr = function() end,
        on_complete = function(status, text)
          result = { status = status, text = text }
          completed = true
        end,
      }

      stdout_provider:make_request("test", context, observer)

      vim.wait(2000, function()
        return completed
      end)

      eq("success", result.status)
      eq("stdout response", vim.trim(result.text))
    end)

    it("uses tmp_file when it has content", function()
      local _99 = require("99")
      _99.setup({})

      local state = _99.__get_state()
      local Prompt = require("99.prompt")
      local context = Prompt.search(state)
      context.tmp_file = vim.fn.tempname()

      local file = io.open(context.tmp_file, "w")
      file:write("file response")
      file:close()

      local file_provider = setmetatable({}, { __index = Providers.BaseProvider })
      function file_provider._build_command(_, _, _)
        return { "bash", "-c", "echo 'stdout response'" }
      end
      function file_provider._get_provider_name()
        return "file_test"
      end

      local result = nil
      local completed = false
      local observer = {
        on_start = function() end,
        on_stdout = function() end,
        on_stderr = function() end,
        on_complete = function(status, text)
          result = { status = status, text = text }
          completed = true
        end,
      }

      file_provider:make_request("test", context, observer)

      vim.wait(2000, function()
        return completed
      end)

      eq("success", result.status)
      eq("file response", result.text)
    end)

    it("retries when command exits non-zero", function()
      local _99 = require("99")
      _99.setup({ max_retries = 1 })

      local state = _99.__get_state()
      local Prompt = require("99.prompt")
      local context = Prompt.search(state)
      context.tmp_file = vim.fn.tempname()
      local tmpf = io.open(context.tmp_file, "w")
      if tmpf then tmpf:write("") tmpf:close() end

      local attempts = 0
      local retry_provider = setmetatable({}, { __index = Providers.BaseProvider })
      function retry_provider._build_command(_, _, _)
        attempts = attempts + 1
        if attempts == 1 then
          return { "bash", "-c", "exit 1" }
        end
        return { "bash", "-c", "echo ok" }
      end
      function retry_provider._get_provider_name()
        return "retry_test"
      end

      local result = nil
      local completed = false
      local observer = {
        on_start = function() end,
        on_stdout = function() end,
        on_stderr = function() end,
        on_complete = function(status, text)
          result = { status = status, text = text }
          completed = true
        end,
      }

      assert.are.equal(1, context._99.max_retries)
      retry_provider:make_request("test", context, observer)

      vim.wait(5000, function()
        return completed
      end)

      eq("success", result.status)
      eq("ok", vim.trim(result.text))
    end)
  end)
end)
