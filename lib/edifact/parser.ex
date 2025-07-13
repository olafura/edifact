defmodule Edifact.Parser do
  import NimbleParsec

  all_alphanumberic_char = [0..255]

  escaped_char =
    ignore(ascii_string([??], 1))
    |> concat(ascii_string(all_alphanumberic_char, 1))

  level_a =
    choice([
      escaped_char,
      ascii_string([?A..?Z], 1),
      ascii_string([?a..?z], 1),
      ascii_string([?0..?9], 1),
      ascii_string([?\s, ?., ?,, ?-, ?(, ?), ?/, ?=], 1)
    ])

  component_data_element_seperator =
    ignore(ascii_string([?:], 1))

  data_element_seperator =
    ascii_string([{:not, ?:} | all_alphanumberic_char], 1)
    |> unwrap_and_tag(:data_element_seperator)

  decimal_notation =
    ascii_string([?., ?,], 1)
    |> unwrap_and_tag(:decimal_notation)

  release_indicator =
    ascii_string(all_alphanumberic_char, 1)
    |> unwrap_and_tag(:release_indicator)

  segment_terminator =
    ascii_string(all_alphanumberic_char, 1)
    |> unwrap_and_tag(:segment_terminator)

  defparsec(
    :service_string_advice,
    ignore(string("UNA"))
    |> concat(component_data_element_seperator)
    |> concat(data_element_seperator)
    |> concat(decimal_notation)
    |> concat(release_indicator)
    |> ignore(string(" "))
    |> concat(segment_terminator)
    |> post_traverse({:una_check_if_same, []})
  )

  default_data_element_seperator =
    ignore(string("+"))

  controlling_agency =
    ascii_string([?A..?Z], 3)
    |> unwrap_and_tag(:controlling_agency)

  level_identifier =
    ascii_string([?A..?Z], 1)
    |> unwrap_and_tag(:level)

  syntax_identifier =
    controlling_agency
    |> concat(level_identifier)
    |> tag(:syntax_identifier)

  syntax_version_number =
    integer(1)
    |> unwrap_and_tag(:syntax_version_number)

  participant_identification =
    times(level_a, min: 1, max: 35)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:identification)

  partner_identification =
    times(level_a, min: 1, max: 4)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:partner_identification)

  address_for_reverse_routing =
    times(level_a, min: 1, max: 14)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:routing_address)

  interchange_participant =
    participant_identification
    |> optional(
      component_data_element_seperator
      |> optional(partner_identification)
      |> optional(
        component_data_element_seperator
        |> concat(address_for_reverse_routing)
      )
    )

  interchange_sender =
    interchange_participant
    |> tag(:interchange_sender)

  interchange_recipient =
    interchange_participant
    |> tag(:interchange_recipient)

  year =
    ascii_string([?0..?9], 2)
    |> unwrap_and_tag(:year)

  month =
    choice([
      string("01"),
      string("02"),
      string("03"),
      string("04"),
      string("05"),
      string("06"),
      string("07"),
      string("08"),
      string("09"),
      string("10"),
      string("11"),
      string("12")
    ])
    |> unwrap_and_tag(:month)

  day =
    choice([
      string("01"),
      string("02"),
      string("03"),
      string("04"),
      string("05"),
      string("06"),
      string("07"),
      string("08"),
      string("09"),
      string("10"),
      string("11"),
      string("12"),
      string("13"),
      string("14"),
      string("15"),
      string("16"),
      string("17"),
      string("18"),
      string("19"),
      string("20"),
      string("21"),
      string("22"),
      string("23"),
      string("24"),
      string("25"),
      string("26"),
      string("27"),
      string("28"),
      string("29"),
      string("30"),
      string("31")
    ])
    |> unwrap_and_tag(:day)

  hour =
    choice([
      string("01"),
      string("02"),
      string("03"),
      string("04"),
      string("05"),
      string("06"),
      string("07"),
      string("08"),
      string("09"),
      string("10"),
      string("11"),
      string("12"),
      string("13"),
      string("14"),
      string("15"),
      string("16"),
      string("17"),
      string("18"),
      string("19"),
      string("20"),
      string("21"),
      string("22"),
      string("23"),
      string("24")
    ])
    |> unwrap_and_tag(:hour)

  minutes =
    choice([
      string("00"),
      string("01"),
      string("02"),
      string("03"),
      string("04"),
      string("05"),
      string("06"),
      string("07"),
      string("08"),
      string("09"),
      string("10"),
      string("11"),
      string("12"),
      string("13"),
      string("14"),
      string("15"),
      string("16"),
      string("17"),
      string("18"),
      string("19"),
      string("20"),
      string("21"),
      string("22"),
      string("23"),
      string("24"),
      string("25"),
      string("26"),
      string("27"),
      string("28"),
      string("29"),
      string("30"),
      string("31"),
      string("32"),
      string("33"),
      string("34"),
      string("35"),
      string("36"),
      string("37"),
      string("38"),
      string("39"),
      string("40"),
      string("41"),
      string("42"),
      string("43"),
      string("44"),
      string("45"),
      string("46"),
      string("47"),
      string("48"),
      string("49"),
      string("50"),
      string("51"),
      string("52"),
      string("53"),
      string("54"),
      string("55"),
      string("56"),
      string("57"),
      string("58"),
      string("59")
    ])
    |> unwrap_and_tag(:minutes)

  date_time =
    year
    |> concat(month)
    |> concat(day)
    |> concat(component_data_element_seperator)
    |> concat(hour)
    |> concat(minutes)
    |> tag(:date_time)

  interchange_control_reference =
    times(level_a, min: 1, max: 14)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:interchange_control_reference)

  defparsec(
    :interchange_header,
    ignore(string("UNB"))
    |> concat(default_data_element_seperator)
    |> concat(syntax_identifier)
    |> concat(component_data_element_seperator)
    |> concat(syntax_version_number)
    |> concat(default_data_element_seperator)
    |> concat(interchange_sender)
    |> concat(default_data_element_seperator)
    |> concat(interchange_recipient)
    |> concat(default_data_element_seperator)
    |> concat(date_time)
    |> concat(default_data_element_seperator)
    |> concat(interchange_control_reference)
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

  defp una_check_if_same(rest, args, context, _line, _offset) do
    set = MapSet.new(Keyword.values(args))

    if MapSet.size(set) == length(args) do
      {rest, args, context}
    else
      {:error,
       "Service String Advice should have different values for data element separator, decimal notation, release indicator or segment terminator"}
    end
  end
end
