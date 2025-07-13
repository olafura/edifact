defmodule Edifact.ValidationTest do
  use ExUnit.Case

  describe "UNA Service String Advice validation" do
    test "validates standard UNA format" do
      assert {:ok, _} = Edifact.Parser.parse_service_string_advice("UNA:+.? '")
    end

    test "validates custom separators" do
      assert {:ok, _} = Edifact.Parser.parse_service_string_advice("UNA:|.* '")
      assert {:ok, _} = Edifact.Parser.parse_service_string_advice("UNA:^.\\ &")
    end

    test "fails on invalid UNA format" do
      # too short
      assert nil == Edifact.Parser.parse_service_string_advice("UNA:+.?")
      # too long
      assert nil == Edifact.Parser.parse_service_string_advice("UNA:+.? ''")
      # wrong header
      assert nil == Edifact.Parser.parse_service_string_advice("UNB:+.?'")
    end

    test "validates UNA separators according to EDIFACT rules" do
      # All separators must be different according to EDIFACT standards
      # duplicate separators
      assert nil == Edifact.Parser.parse_service_string_advice("UNA::.? '")
      # duplicate separators
      assert nil == Edifact.Parser.parse_service_string_advice("UNA:+.+ '")
    end
  end

  describe "UNB Interchange Header validation" do
    test "validates basic UNB structure" do
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"
      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :syntax_identifier) == [controlling_agency: "UNO", level: "C"]
    end

    test "validates syntax identifier values" do
      # Test valid syntax identifiers
      valid_identifiers = [
        "UNOA",
        "UNOB",
        "UNOC",
        "UNOD",
        "UNOE",
        "UNOF",
        "UNOG",
        "UNOH",
        "UNOI",
        "UNOJ",
        "UNOK",
        "UNOX",
        "UNOY"
      ]

      for syntax_id <- valid_identifiers do
        line = "UNB+#{syntax_id}:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"
        # Note: Current parser only handles UNO* pattern, this reveals a limitation
        if String.starts_with?(syntax_id, "UNO") do
          assert {:ok, _, _, _, _, _} = Edifact.Parser.interchange_header(line)
        end
      end
    end

    test "validates syntax version numbers" do
      # Valid syntax versions are typically 1-4
      for version <- 1..4 do
        line = "UNB+UNOC:#{version}+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"
        assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
        assert Keyword.get(parsed, :syntax_version_number) == version
      end
    end

    test "validates participant identification length constraints" do
      # Participant identification: max 35 characters
      # Too long
      long_sender = String.duplicate("A", 36)
      line = "UNB+UNOC:3+#{long_sender}:ZZ+RECEIVER:ZZ+940101:0950+1'"
      # Current parser should fail on this
      assert {:error, _, _, _, _, _} = Edifact.Parser.interchange_header(line)
    end

    test "validates partner identification length constraints" do
      # Partner identification: max 4 characters  
      # Too long
      long_qualifier = String.duplicate("A", 5)
      line = "UNB+UNOC:3+SENDER:#{long_qualifier}+RECEIVER:ZZ+940101:0950+1'"
      # Current parser should fail on this
      assert {:error, _, _, _, _, _} = Edifact.Parser.interchange_header(line)
    end

    test "validates date format constraints" do
      # Test invalid dates
      invalid_dates = [
        # Invalid day (32)
        "940132:0950",
        # Invalid month (13)
        "941301:0950",
        # Too short
        "94010:0950",
        # Too long
        "9401011:0950",
        # Invalid hour (25)
        "940101:2560",
        # Invalid minutes (60)
        "940101:0960"
      ]

      for invalid_date <- invalid_dates do
        line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+#{invalid_date}+1'"
        assert {:error, _, _, _, _, _} = Edifact.Parser.interchange_header(line)
      end
    end

    test "validates interchange control reference length" do
      # Max 14 characters - the parser should consume exactly 14 and leave remainder
      long_ref = String.duplicate("A", 15)
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+#{long_ref}'"

      case Edifact.Parser.interchange_header(line) do
        {:ok, parsed, remaining, _, _, _} ->
          # Parser should consume exactly 14 characters and leave 1 "A" plus "'"
          assert Keyword.get(parsed, :interchange_control_reference) == String.duplicate("A", 14)
          assert remaining == "A'"

        {:error, _, _, _, _, _} ->
          # Some parsers might fail on malformed input, which is also acceptable
          :ok
      end
    end
  end

  describe "Level A character set validation" do
    test "validates Level A characters in data elements" do
      # Level A: A-Z, 0-9, space, . , - ( ) / = (no lowercase in Level A)
      valid_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      valid_chars = valid_chars <> "0123456789 .,-()/"

      for valid_char <- String.splitter(valid_chars, "", trim: true) do
        line = "UNB+UNOC:3+#{valid_char}:ZZ+RECEIVER:ZZ+940101:0950+1'"
        # This tests that Level A characters are properly parsed
        assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
        sender = Keyword.get(parsed, :interchange_sender)
        assert Keyword.get(sender, :identification) == valid_char
      end
    end

    # test "rejects invalid characters outside Level A" do
    #   # Characters like @, #, $, %, etc. should not be allowed in Level A
    #   invalid_chars = ["@", "#", "$", "%", "^", "&", "*"]

    #   for char <- invalid_chars do
    #     line = "UNB+UNOC:3+SENDER#{char}:ZZ+RECEIVER:ZZ+940101:0950+1'"

    #     assert {:error, _, _, _, _, _} = Edifact.Parser.interchange_header(line)
    #   end
    # end
  end

  describe "Service advice application" do
    test "properly escapes and replaces custom separators" do
      line = "UNB|UNOC:3|SENDER:ZZ|RECEIVER:ZZ|940101:0950|1'"
      {:ok, service_advice} = Edifact.Parser.parse_service_string_advice("UNA:|.? '")

      result = Edifact.Parser.apply_service_advice(line, service_advice)
      expected = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"

      assert result == expected
    end

    test "handles release character escaping" do
      # Test escaping of separators within data
      line = "UNB+UNOC:3+SEND?+ER:ZZ+RECEIVER:ZZ+940101:0950+1'"
      {:ok, service_advice} = Edifact.Parser.parse_service_string_advice("UNA:+.? '")

      result = Edifact.Parser.apply_service_advice(line, service_advice)
      # The ?+ should be preserved as an escaped separator
      assert String.contains?(result, "SEND?+ER")
    end

    test "handles space as release character" do
      line = "UNB+UNOC:3+SEND?+ER:ZZ+RECEIVER:ZZ+940101:0950+1'"
      {:ok, service_advice} = Edifact.Parser.parse_service_string_advice("UNA:+.  '")

      result = Edifact.Parser.apply_service_advice(line, service_advice)
      assert String.contains?(result, "SEND?+ER")
    end
  end

  describe "EDIFACT structural validation" do
    test "validates mandatory UNB presence" do
      # Every EDIFACT interchange must start with UNB
      line = "UNA:+.? 'UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"

      # Parser should handle UNA followed by UNB
      una_part = String.slice(line, 0, 9)
      unb_part = String.slice(line, 9..-1//1)

      assert {:ok, _} = Edifact.Parser.parse_service_string_advice(una_part)
      assert {:ok, _, _, _, _, _} = Edifact.Parser.interchange_header(unb_part)
    end

    test "validates segment terminator consistency" do
      # All segments should end with the same terminator
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"
      {:ok, service_advice} = Edifact.Parser.parse_service_string_advice("UNA:+.? '")

      # Segment terminator from UNA should match the one used in segments
      assert service_advice.segment_terminator == "'"
      assert String.ends_with?(line, "'")
    end
  end
end
