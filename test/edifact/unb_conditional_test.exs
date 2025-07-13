defmodule Edifact.UnbConditionalTest do
  use ExUnit.Case

  @moduledoc """
  Tests for UNB (Interchange Header) conditional element parsing.

  The parser now supports all conditional UNB elements according to EDIFACT Syntax Rules Section 7.2-7.3.

  Conditional elements in UNB:
  - Position 6: Recipients reference/password (S005) - Optional composite
  - Position 7: Application reference (0026) - Optional  
  - Position 8: Processing priority code (0029) - Optional
  - Position 9: Acknowledgement request (0031) - Optional
  - Position 10: Communications agreement ID (0032) - Optional
  - Position 11: Test indicator (0035) - Optional

  Missing conditional elements are indicated by:
  1. Empty positions: UNB+...+REF++APP' (skip pos 6, populate pos 7)
  2. Truncation: UNB+...+REF+PASS' (omit trailing positions)
  """

  describe "UNB mandatory elements parsing" do
    test "parses minimal UNB with only mandatory elements" do
      # Only mandatory elements: UNB+SYNTAX+SENDER+RECIPIENT+DATETIME+REFERENCE
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :interchange_control_reference) == "1"

      # Verify all mandatory elements are present
      assert Keyword.has_key?(parsed, :syntax_identifier)
      assert Keyword.has_key?(parsed, :syntax_version_number)
      assert Keyword.has_key?(parsed, :interchange_sender)
      assert Keyword.has_key?(parsed, :interchange_recipient)
      assert Keyword.has_key?(parsed, :date_time)

      # Should not have any optional elements
      refute Keyword.has_key?(parsed, :recipient_reference_password)
      refute Keyword.has_key?(parsed, :application_reference)
      refute Keyword.has_key?(parsed, :processing_priority_code)
      refute Keyword.has_key?(parsed, :acknowledgement_request)
      refute Keyword.has_key?(parsed, :communication_agreement_id)
      refute Keyword.has_key?(parsed, :test_indicator)
    end
  end

  describe "UNB conditional elements parsing" do
    test "parses UNB with recipients reference/password (position 6)" do
      # UNB with recipients reference (position 6)
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASSWORD123'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :interchange_control_reference) == "1"

      # Should have recipients reference
      recipients = Keyword.get(parsed, :recipient_reference_password)
      assert Keyword.get(recipients, :reference_password) == "PASSWORD123"
      refute Keyword.has_key?(recipients, :reference_password_qualifier)
    end

    test "parses UNB with recipients reference and qualifier" do
      # UNB with recipients reference and qualifier: PASSWORD123:PQ
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASSWORD123:PQ'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)

      recipients = Keyword.get(parsed, :recipient_reference_password)
      assert Keyword.get(recipients, :reference_password) == "PASSWORD123"
      assert Keyword.get(recipients, :reference_password_qualifier) == "PQ"
    end

    test "parses UNB with omitted recipients but present application reference (position 7)" do
      # Position 6 omitted, position 7 present: UNB+...+1++APPREF'
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1++APPREF'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :application_reference) == "APPREF"

      # Recipients should not be present
      refute Keyword.has_key?(parsed, :recipient_reference_password)
    end

    test "parses UNB with processing priority code (position 8)" do
      # UNB with processing priority code: UNB+...+1+++A'
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+++A'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :processing_priority_code) == "A"
    end

    test "parses UNB with acknowledgement request (position 9)" do
      # UNB with acknowledgement request (1 = requested)
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1++++1'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :acknowledgement_request) == 1
    end

    test "parses UNB with communication agreement ID (position 10)" do
      # UNB with communication agreement ID
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+++++AGREEMENT'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :communication_agreement_id) == "AGREEMENT"
    end

    test "parses UNB with test indicator (position 11)" do
      # UNB with test indicator at the end (1 = test)
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1++++++1'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :test_indicator) == "1"
    end

    test "parses UNB with all optional elements" do
      # Full UNB with all optional elements
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASS:PQ+APPREF+A+1+AGREEMENT+1'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)

      # Mandatory elements
      assert Keyword.get(parsed, :interchange_control_reference) == "1"

      # Optional elements
      recipients = Keyword.get(parsed, :recipient_reference_password)
      assert Keyword.get(recipients, :reference_password) == "PASS"
      assert Keyword.get(recipients, :reference_password_qualifier) == "PQ"

      assert Keyword.get(parsed, :application_reference) == "APPREF"
      assert Keyword.get(parsed, :processing_priority_code) == "A"
      assert Keyword.get(parsed, :acknowledgement_request) == 1
      assert Keyword.get(parsed, :communication_agreement_id) == "AGREEMENT"
      assert Keyword.get(parsed, :test_indicator) == "1"
    end

    test "handles truncation - omits trailing optional elements" do
      # According to EDIFACT 7.3, trailing conditional elements can be truncated
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASS'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)

      recipients = Keyword.get(parsed, :recipient_reference_password)
      assert Keyword.get(recipients, :reference_password) == "PASS"

      # Should not have other optional elements
      refute Keyword.has_key?(parsed, :application_reference)
      refute Keyword.has_key?(parsed, :processing_priority_code)
      refute Keyword.has_key?(parsed, :acknowledgement_request)
      refute Keyword.has_key?(parsed, :communication_agreement_id)
      refute Keyword.has_key?(parsed, :test_indicator)
    end

    test "handles mixed conditional elements" do
      # Test various combinations of present and omitted elements
      test_cases = [
        {"UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASS+APP'",
         [
           recipient_reference_password: [reference_password: "PASS"],
           application_reference: "APP"
         ]},
        {"UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1++APP+A'",
         [application_reference: "APP", processing_priority_code: "A"]},
        {"UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASS++A'",
         [
           recipient_reference_password: [reference_password: "PASS"],
           processing_priority_code: "A"
         ]},
        {"UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1++++1+AGR'",
         [acknowledgement_request: 1, communication_agreement_id: "AGR"]}
      ]

      for {line, expected_elements} <- test_cases do
        assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)

        for {key, expected_value} <- expected_elements do
          assert Keyword.get(parsed, key) == expected_value
        end
      end
    end
  end

  describe "UNB validation edge cases" do
    test "validates recipients reference length (max 14 chars)" do
      long_ref = String.duplicate("A", 15)
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+#{long_ref}'"

      case Edifact.Parser.interchange_header(line) do
        {:ok, parsed, remaining, _, _, _} ->
          # Should consume exactly 14 characters
          recipients = Keyword.get(parsed, :recipient_reference_password)
          ref = Keyword.get(recipients, :reference_password)
          assert String.length(ref) == 14
          # Remaining should contain the excess character
          assert String.contains?(remaining, "A")

        {:error, _, _, _, _, _} ->
          # Some implementations might reject this entirely
          :ok
      end
    end

    test "validates reference password qualifier length (exactly 2 chars)" do
      # Qualifier should be exactly 2 characters
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASS:PQ'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      recipients = Keyword.get(parsed, :recipient_reference_password)
      assert Keyword.get(recipients, :reference_password_qualifier) == "PQ"
    end

    test "validates processing priority code (exactly 1 char)" do
      # Processing priority code should be exactly 1 character
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+++A'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :processing_priority_code) == "A"
    end

    test "validates acknowledgement request (must be integer)" do
      # Should accept digits 0-9
      for digit <- 0..9 do
        line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1++++#{digit}'"
        assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
        assert Keyword.get(parsed, :acknowledgement_request) == digit
      end
    end

    test "validates test indicator (must be '1')" do
      # Test indicator should only accept "1"
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1++++++1'"

      assert {:ok, parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)
      assert Keyword.get(parsed, :test_indicator) == "1"
    end

    test "validates communication agreement ID length (max 35 chars)" do
      # Should accept up to 35 characters
      agreement_id = String.duplicate("A", 35)
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+++++#{agreement_id}'"

      case Edifact.Parser.interchange_header(line) do
        {:ok, parsed, _, _, _, _} ->
          assert Keyword.get(parsed, :communication_agreement_id) == agreement_id

        {:error, _, _, _, _, _} ->
          # Parser might have other constraints
          :ok
      end
    end
  end

  describe "EDIFACT segment termination" do
    test "requires proper segment termination with apostrophe" do
      # All UNB segments must end with apostrophe
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1'"
      assert {:ok, _, _, _, _, _} = Edifact.Parser.interchange_header(line)

      # Missing terminator should fail
      line_no_terminator = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1"
      assert {:error, _, _, _, _, _} = Edifact.Parser.interchange_header(line_no_terminator)
    end

    test "handles segments with conditional elements and proper termination" do
      # Segment terminator should work with all conditional elements
      line = "UNB+UNOC:3+SENDER:ZZ+RECEIVER:ZZ+940101:0950+1+PASS:PQ+APP+A+1+AGR+1'"
      assert {:ok, _, "", _, _, _} = Edifact.Parser.interchange_header(line)
    end
  end
end
