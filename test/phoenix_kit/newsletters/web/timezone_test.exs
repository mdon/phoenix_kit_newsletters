defmodule PhoenixKit.Newsletters.Web.TimezoneTest do
  @moduledoc """
  Unit tests for the shared timezone-resolution/display helper used by
  BroadcastEditor, Broadcasts, and BroadcastDetails.
  """

  use PhoenixKitNewsletters.DataCase, async: false

  alias PhoenixKit.Newsletters.Web.Timezone
  alias PhoenixKit.Settings
  alias PhoenixKit.Users.Auth.User

  defp socket_with_user(user_assign) do
    %Phoenix.LiveView.Socket{assigns: Map.merge(%{__changed__: %{}}, user_assign)}
  end

  describe "user_tz_offset/1 — resolves the viewer's timezone (profile-first)" do
    test "uses the profile timezone when the viewer has set one" do
      # Unsigned, matching how both the profile dropdown (reusing core's
      # Settings.get_setting_options()["time_zone"] values, e.g. "3") and the
      # "use browser timezone" one-click button actually store it.
      user = %User{user_timezone: "3"}

      assert Timezone.user_tz_offset(socket_with_user(%{phoenix_kit_current_user: user})) == "3"
    end

    test "falls back to the system time_zone setting when the profile timezone is unset" do
      Settings.update_setting("time_zone", "-5")
      user = %User{user_timezone: nil}

      assert Timezone.user_tz_offset(socket_with_user(%{phoenix_kit_current_user: user})) == "-5"
    end

    test "falls back to the system time_zone setting when there's no viewer at all" do
      Settings.update_setting("time_zone", "-5")

      assert Timezone.user_tz_offset(socket_with_user(%{})) == "-5"
    end

    test "falls back to UTC if resolving the timezone raises" do
      # A plain map (not a %User{} struct) has no :user_timezone field, so
      # core's get_user_timezone/1 raises a KeyError on it — exercises the
      # rescue clause instead of a well-formed input.
      malformed_user = %{}

      assert Timezone.user_tz_offset(
               socket_with_user(%{phoenix_kit_current_user: malformed_user})
             ) == "0"
    end
  end

  describe "format_datetime/2" do
    test "returns \"-\" for nil" do
      assert Timezone.format_datetime(nil, "3") == "-"
    end

    test "shifts a UTC datetime forward for a positive offset" do
      assert Timezone.format_datetime(~U[2026-07-20 18:58:00Z], "3") == "2026-07-20 21:58"
    end

    test "shifts a UTC datetime backward for a negative offset, including a day rollback" do
      assert Timezone.format_datetime(~U[2026-07-20 02:00:00Z], "-5") == "2026-07-19 21:00"
    end
  end

  describe "tz_label/1" do
    test "is core's label, for an IANA id and for a legacy offset alike" do
      assert Timezone.tz_label("Europe/Warsaw") == Settings.get_timezone_label("Europe/Warsaw")
      assert Timezone.tz_label("Europe/Warsaw") =~ "Europe/Warsaw"
      assert Timezone.tz_label("3") == Settings.get_timezone_label("3")
      assert Timezone.tz_label("3") =~ "UTC+03"
    end
  end

  describe "format_datetime/2 with an IANA zone" do
    test "follows daylight saving on the date shown" do
      assert Timezone.format_datetime(~U[2026-01-15 08:00:00Z], "Europe/Tallinn") ==
               "2026-01-15 10:00"

      assert Timezone.format_datetime(~U[2026-07-15 08:00:00Z], "Europe/Tallinn") ==
               "2026-07-15 11:00"
    end
  end
end
