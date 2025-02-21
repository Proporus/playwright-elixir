defmodule Playwright.Runner.Config do
  @moduledoc """
  Configuration for Playwright.

  ## Overview

      config :playwright, ConnectOptions,
        [...]

      config :playwright, LaunchOptions,
        [...]

      config :playwright, PlaywrightTest,
        [...]

  ## Details for `ConnectOptions`

  Configuration for connecting to a running Playwright browser server over a
  WebSocket.

  ### `ws_endpoint` (required)

  A browser websocket endpoint to which the runner will connect.

  This option is required when using the `:driver` transport to communicate with
  a Playwright browser server.

  e.g.,

      config :playwright, ConnectOptions,
        ws_endpoint: "ws://localhost:3000/playwright"

  ## Details for `LaunchOptions`

  Configuration for Playwright browser server launch commands.

  ### `args` (optional)

  Additional arguments to pass to the browser instance. The list of Chromium
  flags may be found [online](http://peter.sh/experiments/chromium-command-line-switches/).

  e.g.,

      config :playwright, LaunchOptions,
        args: [
          "--use-fake-ui-for-media-stream",
          "--use-fake-device-for-media-stream"
        ]

  ### `channel` (optional)

  Browser distribution channel for Chromium. Supported values are:

    - `chrome`
    - `chrome-beta`
    - `chrome-dev`
    - `chrome-canary`
    - `msedge`
    - `msedge-beta`
    - `msedge-dev`
    - `msedge-canary`

  Read more about using Google Chrome and Microsoft Edge
  [online](https://playwright.dev/docs/browsers#google-chrome--microsoft-edge).

  e.g.,

      config :playwright, LaunchOptions,
        channel: "chrome"

  ### `chromium_sandbox` (optional)

  Enable Chromium sandboxing. Defaults to `false`.

  e.g.,

      config :playwright, LaunchOptions,
        chromium_sandbox: true

  ### `devtools` (optional)

  With Chromium, specifies whether to auto-open a "Developer Tools" panel for
  each tab. If this option is `true`, the `headless` option will be set to
  `false`.

  Defaults to `false`.

  e.g.,

      config :playwright, LaunchOptions,
        devtools: true

  ### `headless` (optional)

  Specifies whether to run the browser in "headless" mode. See:

    - [headless Chromium](https://developers.google.com/web/updates/2017/04/headless-chrome)
    - [headless Firefox](https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Headless_mode)

  Defaults to `true` unless the `devtools` option is `true`.

  e.g.,

      config :playwright, LaunchOptions,
        headless: false # e.g., see a browser window pop up in "dev".

  ### `downloads_path` (optional)

  **WARNING: not yet implemented**

  If specified, accepted downloads are written to this directory. Otherwise, a
  temporary directory is created and is removed when the browser is closed.

  e.g.,

      config :playwright, LaunchOptions,
        downloads_path: "./doc/downloads"

  ### `env` (optional)

  **WARNING: not yet implemented**

  Environment variables that will be made visible to the browser. Defaults to
  `System.get_env/0`.

  e.g.,

      config :playwright, LaunchOptions,
        env: ["DEBUG", "true"]

  ### `executable_path` (optional)

  A filesystem path to a browser executable to run instead of the bundled
  browser. If `executable_path` is a relative path, then it is resolved relative
  to the current working directory.

  **Chromium-only**

  Playwright can also be used to control the Google Chrome or Microsoft Edge
  browsers, but it works best with the bundled version of Chromium. There is no
  guarantee that it will work with any other version.

  **Use `executable_path` option with extreme caution.**

  e.g.,

      config :playwright, LaunchOptions,
        executable_path: "/Applications/..."

  ## Details for `PlaywrightTest`

  Configuration for usage of `PlaywrightTest.Case`.

  ### `transport` (optional)

  One of `:driver` or `:websocket`, defaults to `:driver`.

  Additional configuration may be required depending on the transport
  configuration:

    - `LaunchOptions` for the `:driver` transport
    - `ConnectOptions` for the `:websocket` transport

  e.g.,

      config :playwright, PlaywrightTest,
        transport: :websocket
  """

  alias Playwright.Extra
  alias Playwright.Runner.Config.Types

  @typedoc false
  @type connect_options :: %{
          ws_endpoint: String.t()
        }

  @typedoc false
  @type launch_options :: %{
          args: [String.t()],
          channel: String.t(),
          chromium_sandbox: boolean(),
          devtools: boolean(),
          downloads_path: String.t(),
          env: any(),
          executable_path: String.t(),
          headless: boolean()
        }

  @typedoc false
  @type playwright_test :: %{
          transport: atom()
        }

  defmodule Types do
    @moduledoc false

    defmodule ConnectOptions do
      @moduledoc false
      defstruct [:ws_endpoint]
    end

    defmodule LaunchOptions do
      @moduledoc false
      defstruct [:args, :channel, :chromium_sandbox, :devtools, :downloads_path, :headless]
    end

    defmodule PlaywrightTest do
      @moduledoc false
      defstruct transport: :driver
    end
  end

  @doc false
  @spec connect_options(boolean()) :: Types.connect_options()
  def connect_options(camelcase \\ false) do
    config_for(ConnectOptions, %Types.ConnectOptions{}, camelcase) || %{}
    # |> clean()
  end

  @doc false
  @spec launch_options(boolean()) :: Types.launch_options()
  def launch_options(camelcase \\ false) do
    config_for(LaunchOptions, %Types.LaunchOptions{}, camelcase) || %{}
    # |> clean()
  end

  @doc false
  @spec playwright_test(boolean()) :: Types.playwright_test()
  def playwright_test(camelcase \\ false) do
    config_for(PlaywrightTest, %Types.PlaywrightTest{}, camelcase)
    # |> Map.from_struct()
  end

  @doc false
  def config_for(key, mod, camelcase \\ false) do
    configured =
      Application.get_env(:playwright, key, %{})
      |> Enum.into(%{})

    result = build(configured, mod) |> clean()
    if camelcase, do: camelize(result), else: result
  end

  # private
  # ----------------------------------------------------------------------------

  defp build(source, mod) do
    result =
      for key <- Map.keys(mod) |> Enum.reject(fn key -> key == :__struct__ end),
          into: %{} do
        case Map.get(source, key) do
          nil ->
            {key, Map.get(mod, key)}

          value ->
            {key, value}
        end
      end

    Map.merge(mod, result)
  end

  defp clean(source) do
    Map.from_struct(source)
    |> Enum.reject(fn
      {_key, value} when is_nil(value) -> true
      {_key, value} when is_list(value) -> value == []
      _otherwise_ -> false
    end)
    |> Enum.into(%{})
  end

  defp camelize(source) do
    Extra.Map.deep_camelize_keys(source)
  end
end
