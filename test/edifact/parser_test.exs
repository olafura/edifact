defmodule Edifact.ParserTest do
  use ExUnit.Case
  doctest Edifact.Parser

  test "simple check for service advice" do
    corrected_line = "UNB+UNOC:3+9457386:30+73130012:30+19101:118+8+MPM?| ?+ 2.19+1424'"

    line = "UNB|UNOC:3|9457386:30|73130012:30|19101:118|8|MPM*| + 2.19|1424'"
    {:ok, service_advice} = Edifact.Parser.parse_service_string_advice("UNA:|.* '")

    assert Edifact.Parser.apply_service_advice(line, service_advice) == corrected_line

    line2 = "UNB+UNOC:3+9457386:30+73130012:30+19101:118+8+MPM*| *+ 2.19+1424'"
    {:ok, service_advice2} = Edifact.Parser.parse_service_string_advice("UNA:+.* '")

    assert Edifact.Parser.apply_service_advice(line2, service_advice2) == corrected_line
  end
end
