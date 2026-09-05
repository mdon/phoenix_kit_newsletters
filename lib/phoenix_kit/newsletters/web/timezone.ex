defmodule PhoenixKit.Newsletters.Web.Timezone do
  @moduledoc """
  Shared timezone resolution and display formatting for the
  newsletters admin LiveViews — used by the broadcast composer's schedule
  field (`BroadcastEditor`) and the broadcasts list/details pages, so the
  resolution logic lives in one place instead of being reimplemented per
  LiveView.
  """

  alias PhoenixKit.Settings
  alias PhoenixKit.Utils.Date, as: DateUtils

  @doc """
  Human-readable label for a timezone value — core's own
  (`PhoenixKit.Settings.get_timezone_label/1`): "(UTC+02:00) Europe/Warsaw"
  for an IANA id, "UTC+03:00" for a legacy offset.

  This used to look the value up in a private copy of the old picker list,
  which labelled a legacy "2" with cities that are only on UTC+2 for half
  the year and had nothing to say about an IANA id at all.
  """
  @spec tz_label(String.t() | nil) :: String.t()
  def tz_label(tz), do: Settings.get_timezone_label(tz)

  @doc """
  The viewer's timezone value — user profile → system setting → "0" (UTC),
  via core's `PhoenixKit.Utils.Date.get_user_timezone/1`. An IANA id such as
  `Europe/Warsaw`, or a legacy fixed offset such as `"2"` on a row written
  before core 2.13.9; never a number, so pass it straight to core's
  per-instant helpers (`shift_to_offset/2`, `parse_datetime_local/2`,
  `format_datetime_local/2`), which follow daylight saving on the date
  shown.

  Deliberately profile-first: unlike core's Maintenance module (a single
  site-wide event window, resolved from the system `time_zone` setting
  only), these are personal actions by the admin viewing/scheduling, so
  their own profile timezone — if they've set one — takes precedence.
  """
  def user_tz_offset(socket) do
    case socket.assigns[:phoenix_kit_current_user] do
      %{} = user -> DateUtils.get_user_timezone(user)
      _ -> Settings.get_setting_cached("time_zone", "0")
    end
  rescue
    _ -> "0"
  end

  @doc """
  Displays a stored UTC datetime in the given timezone. Storage stays UTC —
  this is display-only, via `PhoenixKit.Utils.Date.shift_to_offset/2`, which
  resolves the zone for the instant shown. Returns `"-"` for `nil`.
  """
  def format_datetime(nil, _tz_offset), do: "-"

  def format_datetime(dt, tz_offset) do
    dt
    |> DateUtils.shift_to_offset(tz_offset)
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end
end
