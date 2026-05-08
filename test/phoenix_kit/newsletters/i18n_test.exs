defmodule PhoenixKit.Newsletters.I18nTest do
  @moduledoc """
  Smoke test for the per-module i18n wiring.

  Confirms that:
    * Every admin tab registered by `PhoenixKit.Newsletters.admin_tabs/0`
      carries `gettext_backend: PhoenixKit.Newsletters.Gettext`.
    * Locale switching on the module's own backend produces translated
      labels for at least one well-known msgid (regression guard for
      the `priv/gettext/<locale>/LC_MESSAGES/default.po` shipping with
      the package).
    * Falls back to the raw msgid for an unknown locale.
  """

  use ExUnit.Case, async: false

  # Excluded by `test/test_helper.exs` when running against a `phoenix_kit`
  # release that pre-dates the `gettext_backend` API (PR BeamLabEU/phoenix_kit#522).
  # Once the consumer's `phoenix_kit` dep resolves to a release that ships
  # `Tab.localized_label/1`, the helper detects it and these tests run
  # automatically — no follow-up edit needed.
  @moduletag :requires_phoenix_kit_i18n_api

  alias PhoenixKit.Dashboard.Tab
  alias PhoenixKit.Newsletters
  alias PhoenixKit.Newsletters.Gettext, as: NewslettersGettext

  setup do
    original = Gettext.get_locale(NewslettersGettext)
    on_exit(fn -> Gettext.put_locale(NewslettersGettext, original) end)
    :ok
  end

  describe "admin_tabs/0 wiring" do
    test "every tab carries the module's own gettext backend" do
      for tab <- Newsletters.admin_tabs() do
        assert tab.gettext_backend == NewslettersGettext,
               "Tab #{inspect(tab.id)} is missing or wrong gettext_backend " <>
                 "(got #{inspect(tab.gettext_backend)})"

        assert tab.gettext_domain == "default"
      end
    end
  end

  describe "Tab.localized_label/1 against the module's catalogue" do
    test "ru locale resolves the parent 'Newsletters' tab to 'Рассылки'" do
      Gettext.put_locale(NewslettersGettext, "ru")

      parent = Enum.find(Newsletters.admin_tabs(), &(&1.id == :admin_newsletters))
      assert Tab.localized_label(parent) == "Рассылки"
    end

    test "et locale resolves the parent 'Newsletters' tab to 'Uudiskirjad'" do
      Gettext.put_locale(NewslettersGettext, "et")

      parent = Enum.find(Newsletters.admin_tabs(), &(&1.id == :admin_newsletters))
      assert Tab.localized_label(parent) == "Uudiskirjad"
    end

    test "unknown locale falls back to the raw msgid" do
      Gettext.put_locale(NewslettersGettext, "zz")

      parent = Enum.find(Newsletters.admin_tabs(), &(&1.id == :admin_newsletters))
      assert Tab.localized_label(parent) == "Newsletters"
    end
  end
end
