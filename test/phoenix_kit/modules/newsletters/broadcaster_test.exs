defmodule PhoenixKit.Modules.Newsletters.BroadcasterTest do
  use ExUnit.Case, async: true

  alias PhoenixKit.Newsletters.Broadcast
  alias PhoenixKit.Newsletters.Broadcaster

  describe "module structure" do
    test "Broadcaster module is loadable" do
      assert Code.ensure_loaded?(Broadcaster)
    end

    test "exports send/1" do
      assert function_exported?(Broadcaster, :send, 1)
    end
  end

  describe "send/1 guards" do
    test "rejects broadcast with invalid status" do
      broadcast = %Broadcast{
        uuid: "test-uuid",
        status: "sent",
        list_uuid: "list-uuid",
        markdown_body: "Hello"
      }

      assert {:error, {:invalid_status, "sent"}} = Broadcaster.send(broadcast)
    end

    test "rejects broadcast with 'sending' status" do
      broadcast = %Broadcast{
        uuid: "test-uuid",
        status: "sending",
        list_uuid: "list-uuid",
        markdown_body: "Hello"
      }

      assert {:error, {:invalid_status, "sending"}} = Broadcaster.send(broadcast)
    end
  end

  describe "strip_html/1" do
    test "removes HTML tags" do
      assert Broadcaster.strip_html("<p>Hello <strong>world</strong></p>") == "Hello world"
    end

    test "converts br tags to newlines" do
      assert Broadcaster.strip_html("Line one<br>Line two<br/>Line three") ==
               "Line one\nLine two\nLine three"
    end

    test "converts paragraph tags to double newlines" do
      assert Broadcaster.strip_html("<p>First</p><p>Second</p>") == "First\n\nSecond"
    end

    test "returns empty string for empty input" do
      assert Broadcaster.strip_html("") == ""
    end
  end
end
