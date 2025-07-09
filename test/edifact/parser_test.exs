defmodule Edifact.ParserTest do
  use ExUnit.Case
  doctest Edifact.Parser

  test "simple check for service advice" do
    corrected_line = "UNB+UNOC:3+9457386:30+73130012:30+940101:0950+8+MPM?| ?+ 2.19+1424'"

    line = "UNB|UNOC:3|9457386:30|73130012:30|940101:0950|8|MPM*| + 2.19|1424'"
    {:ok, service_advice} = Edifact.Parser.parse_service_string_advice("UNA:|.* '")

    assert Edifact.Parser.apply_service_advice(line, service_advice) == corrected_line

    line2 = "UNB+UNOC:3+9457386:30+73130012:30+940101:0950+8+MPM*| *+ 2.19+1424'"
    {:ok, service_advice2} = Edifact.Parser.parse_service_string_advice("UNA:+.* '")

    assert Edifact.Parser.apply_service_advice(line2, service_advice2) == corrected_line
  end

  test "simple check for interchange header" do
    line = "UNB+UNOC:3+9457386:30+73130012:30+940101:0950+8+MPM?| ?+ 2.19+1424'"

    parsed = [
      syntax_identifier: [controlling_agency: "UNO", level: "C"],
      syntax_version_number: 3,
      interchange_sender: [identification: "9457386", partner_identification: "30"],
      interchange_recipient: [identification: "73130012", partner_identification: "30"],
      date_time: [year: "94", month: "01", day: "01", hour: "09", minutes: "50"],
      interchange_control_reference: "8"
    ]

    assert {:ok, ^parsed, _, _, _, _} = Edifact.Parser.interchange_header(line)

    line2 = "UNB+UNOC:3+9457386:30:300a+73130012:30+940101:0950+8+MPM?| ?+ 2.19+1424'"

    parsed2 = [
      syntax_identifier: [controlling_agency: "UNO", level: "C"],
      syntax_version_number: 3,
      interchange_sender: [
        identification: "9457386",
        partner_identification: "30",
        routing_address: "300a"
      ],
      interchange_recipient: [identification: "73130012", partner_identification: "30"],
      date_time: [year: "94", month: "01", day: "01", hour: "09", minutes: "50"],
      interchange_control_reference: "8"
    ]

    assert {:ok, ^parsed2, _, _, _, _} = Edifact.Parser.interchange_header(line2)
  end
end
