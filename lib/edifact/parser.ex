defmodule Edifact.Parser do
  import NimbleParsec

  component_data_element_seperator =
    ascii_string([?:], 1)

  data_element_seperator =
    ascii_string([0..255], 1)
    |> unwrap_and_tag(:data_element_seperator)

  decimal_notation =
    ascii_string([?., ?,], 1)
    |> unwrap_and_tag(:decimal_notation)

  release_indicator =
    ascii_string([0..255], 1)
    |> unwrap_and_tag(:release_indicator)

  segment_terminator =
    ascii_string([0..255], 1)
    |> unwrap_and_tag(:segment_terminator)

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

  def parse_service_string_advice(first_line) do
    with {:ok, parsed, "", _, _, _} <-
           service_string_advice(first_line) do
      {:ok, Map.new(parsed)}
    else
      _ -> nil
    end
  end

  def apply_service_advice(
        line,
        %{
          data_element_seperator: data_element_seperator,
          decimal_notation: decimal_notation,
          release_indicator: release_indicator,
          segment_terminator: segment_terminator
        }
      ) do
    release_indicator = if release_indicator == " ", do: "?", else: release_indicator

    base_replacement_list = [data_element_seperator, decimal_notation, segment_terminator]
    replacement_list = for(type <- base_replacement_list, do: "?#{type}") ++ base_replacement_list

    line
    |> String.replace(
      ["+", ".", "'"],
      fn
        "+" when data_element_seperator !== "+" -> "?+"
        "." when decimal_notation !== "." -> "?."
        "'" when segment_terminator !== "'" -> "?'"
        other -> other
      end
    )
    |> String.replace(release_indicator, "?")
    |> String.replace(replacement_list, fn
      <<"?"::binary, _>> = escaped -> escaped
      ^data_element_seperator -> "+"
      ^decimal_notation -> "."
      ^segment_terminator -> "'"
    end)
  end
end
