defmodule Edifact.Parser do
  import NimbleParsec

  component_data_element_seperator =
    ascii_string([?:], 1)

  data_element_seperator =
    ascii_string([0..255], 1)
    |> tag(:data_element_seperator)

  decimal_notation =
    ascii_string([?., ?,], 1)
    |> tag(:decimal_notation)

  release_indicator =
    ascii_string([0..255], 1)
    |> tag(:release_indicator)

  segment_terminator =
    ascii_string([0..255], 1)
    |> tag(:segment_terminator)

  defparsec(
    :service_string_advice,
    ignore(string("UNA"))
    |> concat(ignore(component_data_element_seperator))
    |> concat(data_element_seperator)
    |> concat(decimal_notation)
    |> concat(release_indicator)
    |> ignore(string(" "))
    |> concat(segment_terminator)
  )
end
