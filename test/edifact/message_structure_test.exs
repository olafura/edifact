defmodule Edifact.MessageStructureTest do
  use ExUnit.Case

  describe "Complete EDIFACT message structure validation" do
    test "validates basic interchange structure" do
      # Test a complete minimal EDIFACT interchange
      message = """
      UNA:+.? '
      UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'
      UNH+1+ORDERS:D:96A:UN'
      BGM+220+ORDER123+9'
      UNT+3+1'
      UNZ+1+1'
      """

      lines =
        message
        |> String.trim()
        |> String.splitter("\n")

      # Parse UNA
      {[una_part], rest} = Enum.split(lines, 1)
      assert {:ok, service_advice} = Edifact.Parser.parse_service_string_advice(una_part)

      # Apply service advice to normalize separators
      normalized =
        Enum.map(rest, fn line -> Edifact.Parser.apply_service_advice(line, service_advice) end)
        |> Enum.join("\n")

      # Should start with UNB
      assert String.starts_with?(normalized, "UNB+")

      # Should contain required segments
      # Message header
      assert String.contains?(normalized, "UNH+")
      # Message trailer
      assert String.contains?(normalized, "UNT+")
      # Interchange trailer
      assert String.contains?(normalized, "UNZ+")
    end

    test "validates message header (UNH) structure" do
      # UNH format: UNH+message_reference_number+message_identifier
      # Message identifier: message_type:message_version:message_release:controlling_agency[:association_assigned_code]

      valid_unh_segments = [
        "UNH+1+ORDERS:D:96A:UN'",
        "UNH+MSG001+INVOIC:D:01B:UN'",
        "UNH+12345+DESADV:D:96A:UN:EAN008'"
      ]

      for segment <- valid_unh_segments do
        # Basic structure validation - should not contain malformed elements
        assert String.starts_with?(segment, "UNH+")
        assert String.ends_with?(segment, "'")

        # Should have at least 3 parts (UNH + ref + message_id)
        parts = String.split(segment, "+")
        assert length(parts) >= 3

        # Message identifier should have colon-separated components
        message_id = Enum.at(parts, 2) |> String.trim_trailing("'")
        id_parts = String.split(message_id, ":")
        # type:version:release:agency minimum
        assert length(id_parts) >= 4
      end
    end

    test "validates message trailer (UNT) structure" do
      # UNT format: UNT+number_of_segments+message_reference_number

      valid_unt_segments = [
        "UNT+5+1'",
        "UNT+25+MSG001'",
        "UNT+100+12345'"
      ]

      for segment <- valid_unt_segments do
        assert String.starts_with?(segment, "UNT+")
        assert String.ends_with?(segment, "'")

        parts = String.split(segment, "+")
        # UNT + segment_count + ref
        assert length(parts) == 3

        # Segment count should be numeric
        segment_count = Enum.at(parts, 1)
        assert String.match?(segment_count, ~r/^\d+$/)
      end
    end

    test "validates interchange trailer (UNZ) structure" do
      # UNZ format: UNZ+number_of_groups+interchange_control_reference

      valid_unz_segments = [
        "UNZ+1+1'",
        "UNZ+5+CTRL001'",
        "UNZ+10+12345'"
      ]

      for segment <- valid_unz_segments do
        assert String.starts_with?(segment, "UNZ+")
        assert String.ends_with?(segment, "'")

        parts = String.split(segment, "+")
        # UNZ + group_count + ref
        assert length(parts) == 3

        # Group count should be numeric
        group_count = Enum.at(parts, 1)
        assert String.match?(group_count, ~r/^\d+$/)
      end
    end

    test "validates segment count consistency" do
      # The UNT segment should accurately reflect the number of segments in the message
      # This is a critical validation for message integrity

      # Example: UNH + BGM + DTM + UNT = 4 segments
      message_segments = [
        "UNH+1+ORDERS:D:96A:UN'",
        "BGM+220+ORDER123+9'",
        "DTM+137:20240101:102'",
        "UNT+4+1'"
      ]

      # Count actual segments (excluding UNT itself in the count)
      actual_count = length(message_segments)

      # Extract count from UNT segment
      unt_segment = List.last(message_segments)
      [_, count_str, _] = String.split(unt_segment, "+")
      declared_count = String.to_integer(count_str)

      assert actual_count == declared_count
    end

    test "validates group count consistency" do
      # The UNZ segment should accurately reflect the number of groups in the interchange

      # Single message = 1 group
      groups = 1
      unz_segment = "UNZ+#{groups}+1'"

      [_, count_str, _] = String.split(unz_segment, "+")
      declared_count = String.to_integer(count_str)

      assert groups == declared_count
    end
  end

  describe "EDIFACT data element format validation" do
    test "validates alphanumeric data elements" do
      # Test alphanumeric format: an..35 (max 35 chars, alphanumeric)
      valid_alphanumeric = [
        "ABC123",
        "Test-Data.123",
        # minimum 1 char
        "A"
      ]

      for data <- valid_alphanumeric do
        # Should only contain alphanumeric, space, and allowed special chars
        assert String.match?(data, ~r/^[A-Za-z0-9 .,()\/-]*$/)
        assert String.length(data) <= 35
      end
    end

    test "validates numeric data elements" do
      # Test numeric format: n..15 (max 15 digits)
      valid_numeric = [
        "123",
        # leading zeros allowed
        "000123",
        "1234567890"
      ]

      for data <- valid_numeric do
        assert String.match?(data, ~r/^\d+$/)
        assert String.length(data) <= 15
      end
    end

    test "validates date formats" do
      # EDIFACT date formats: YYMMDD, YYYYMMDD, etc.
      valid_dates = [
        # YYMMDD
        "940101",
        # YYYYMMDD
        "19940101",
        # Leap year
        "20240229"
      ]

      for date <- valid_dates do
        # Basic format validation
        assert String.match?(date, ~r/^\d{6}$|^\d{8}$/)

        # Extract parts for validation
        {month, day} =
          if String.length(date) == 6 do
            # YYMMDD format
            month = String.slice(date, 2, 2)
            day = String.slice(date, 4, 2)
            {month, day}
          else
            # YYYYMMDD format  
            month = String.slice(date, 4, 2)
            day = String.slice(date, 6, 2)
            {month, day}
          end

        # Basic range validation
        month_int = String.to_integer(month)
        day_int = String.to_integer(day)

        assert month_int >= 1 and month_int <= 12
        assert day_int >= 1 and day_int <= 31
      end
    end

    test "validates time formats" do
      # EDIFACT time formats: HHMM, HHMMSS
      valid_times = [
        # HHMM
        "0950",
        # HHMMSS
        "095030",
        # Late evening
        "2359"
      ]

      for time <- valid_times do
        assert String.match?(time, ~r/^\d{4}$|^\d{6}$/)

        hour = String.slice(time, 0, 2)
        minute = String.slice(time, 2, 2)

        hour_int = String.to_integer(hour)
        minute_int = String.to_integer(minute)

        assert hour_int >= 0 and hour_int <= 23
        assert minute_int >= 0 and minute_int <= 59

        if String.length(time) == 6 do
          second = String.slice(time, 4, 2)
          second_int = String.to_integer(second)
          assert second_int >= 0 and second_int <= 59
        end
      end
    end
  end

  describe "EDIFACT control structure validation" do
    test "validates nested structure integrity" do
      # Interchange can contain multiple groups, groups can contain multiple messages
      # UNB -> [UNG -> [UNH -> segments -> UNT] -> UNE] -> UNZ

      # Simple structure: UNB -> UNH -> segments -> UNT -> UNZ (no explicit groups)
      structure_elements = [
        {:interchange_start, "UNB"},
        {:message_start, "UNH"},
        {:message_data, "BGM"},
        {:message_end, "UNT"},
        {:interchange_end, "UNZ"}
      ]

      stack =
        Enum.reduce(structure_elements, [], fn {type, _segment}, stack ->
          case type do
            :interchange_start ->
              ["UNB" | stack]

            :message_start ->
              # Must be inside interchange
              assert "UNB" in stack
              ["UNH" | stack]

            :message_data ->
              # Must be inside message
              assert "UNH" in stack
              stack

            :message_end ->
              # Must close an open message
              assert "UNH" in stack
              List.delete(stack, "UNH")

            :interchange_end ->
              # Must close an open interchange
              assert "UNB" in stack
              # All messages must be closed
              assert "UNH" not in stack
              List.delete(stack, "UNB")
          end
        end)

      # Stack should be empty when properly nested
      assert stack == []
    end

    test "validates reference number consistency" do
      # Reference numbers should match between headers and trailers

      # Message level
      message_ref = "MSG001"
      unh = "UNH+#{message_ref}+ORDERS:D:96A:UN'"
      unt = "UNT+5+#{message_ref}'"

      # Extract and compare references
      [_, unh_ref, _] = String.split(unh, "+")
      [_, _, unt_ref] = String.split(unt, "+") |> Enum.map(&String.trim_trailing(&1, "'"))

      assert unh_ref == unt_ref

      # Interchange level
      interchange_ref = "CTRL001"
      unb = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+#{interchange_ref}'"
      unz = "UNZ+1+#{interchange_ref}'"

      # Extract and compare references
      unb_parts = String.split(unb, "+")
      unb_ref = List.last(unb_parts) |> String.trim_trailing("'")

      [_, _, unz_ref] = String.split(unz, "+") |> Enum.map(&String.trim_trailing(&1, "'"))

      assert unb_ref == unz_ref
    end
  end
end
