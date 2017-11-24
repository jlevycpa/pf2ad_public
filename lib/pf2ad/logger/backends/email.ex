defmodule PF2AD.Logger.Backends.Email do
  @moduledoc """
  A Logger backend that accumulates log lines and then sends the entire log as an email
  when Logger.flush is called.
  """

  import Bamboo.Email

  @behaviour :gen_event

  defstruct [format: nil, metadata: nil, level: nil, device: nil,
             max_buffer: nil, buffer_size: 0, buffer: [], ref: nil, output: nil]

  def init(_) do
    config = []
    # config = Application.get_env(:logger, :email)
    {:ok, init(config, %__MODULE__{})}
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    config = configure_merge(Application.get_env(:logger, :console), opts)
    {:ok, init(config, %__MODULE__{})}
  end

  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    %{level: log_level, ref: ref, buffer_size: buffer_size,
      max_buffer: max_buffer} = state
    cond do
      not meet_level?(level, log_level) ->
        {:ok, state}
      is_nil(ref) ->
        {:ok, log_event(level, msg, ts, md, state)}
    end
  end

  def handle_event(:flush, state) do
    {:ok, flush(state)}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  ## Helpers

  defp meet_level?(_lvl, nil), do: true

  defp meet_level?(lvl, min) do
    Logger.compare_levels(lvl, min) != :lt
  end

  defp configure(options, state) do
    config = configure_merge(Application.get_env(:logger, :console), options)
    Application.put_env(:logger, :console, config)
    init(config, state)
  end

  defp init(config, state) do
    level = Keyword.get(config, :level)
    device = Keyword.get(config, :device, :user)
    format = Logger.Formatter.compile Keyword.get(config, :format)
    metadata = Keyword.get(config, :metadata, []) |> configure_metadata()
    max_buffer = Keyword.get(config, :max_buffer, 32)

    %{state | format: format, metadata: metadata,
              level: level, device: device, max_buffer: max_buffer}
  end

  defp configure_metadata(:all), do: :all
  defp configure_metadata(metadata), do: Enum.reverse(metadata)

  defp configure_merge(env, options) do
    Keyword.merge(env, options, fn
      :colors, v1, v2 -> Keyword.merge(v1, v2)
      _, _v1, v2 -> v2
    end)
  end

  defp log_event(level, msg, ts, md, %{buffer: buffer} = state) do
    output = format_event(level, msg, ts, md, state)
    %{state | buffer: [output | buffer]}
  end

  defp format_event(level, msg, ts, md, state) do
    %{format: format, metadata: keys} = state
    format
    |> Logger.Formatter.format(level, msg, ts, take_metadata(md, keys))
  end

  defp take_metadata(metadata, :all), do: metadata
  defp take_metadata(metadata, keys) do
    Enum.reduce keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error     -> acc
      end
    end
  end

  defp log_buffer(%{buffer_size: 0, buffer: []} = state), do: state

  defp log_buffer(state) do
    %{device: device, buffer: buffer} = state
    %{state | ref: async_io(device, buffer), buffer: [], buffer_size: 0,
      output: buffer}
  end

  defp flush(%{buffer: buffer} = state) do
    config = Application.get_env(:pf2ad, __MODULE__)
    to_emails = Keyword.get(config, :to)
    IO.inspect(to_emails)

    text = buffer
    |> Enum.reverse()
    |> Enum.join("\n")

    new_email
    |> to(to_emails)
    |> from("me@sb.wgempower.com")
    |> subject("PF2AD Logs")
    |> text_body(text)
    |> PF2AD.Mailer.deliver_now
    |> IO.inspect

    %{state | buffer: []}
  end
end

defmodule PF2AD.Mailer do
  use Bamboo.Mailer, otp_app: :pf2ad
end
