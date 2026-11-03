defmodule Pdf.TableDeprecatedTest do
  use Pdf.Case, async: true

  alias Pdf.{Page, ObjectCollection, Fonts}

  setup do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    page = Page.new(fonts: fonts, compress: false)

    # Preload fonts so the internal names are fixed (but don't save the resulting stream)
    page
    |> Page.set_font("Helvetica", 12)
    |> Page.set_font("Helvetica", 12, bold: true)
    |> Page.set_font("Helvetica", 12, italic: true)
    |> Page.set_font("Helvetica", 12, bold: true, italic: true)

    {:ok, page: page}
  end

  test "it does nothing with an empty data list", %{page: page} do
    {page, []} = Page.table(page, {20, 600}, {500, 500}, [])

    assert export(page) == "\n"
  end

  test "basic table", %{page: page} do
    data = [
      ["Col 1,1", "Col 1,2", "Col 1,3"],
      ["Col 2,1", "Col 2,2", "Col 2,3"]
    ]

    {page, :complete} =
      page
      |> Page.set_font("Helvetica", 12)
      |> Page.table({20, 600}, {300, 500}, data)

    assert export(page) == """
           q
           20 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           20 590.934 Td
           (Col 1,1) Tj
           0.0 0.0 0.0 rg
           ET
           Q
           q
           120.0 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           120.0 590.934 Td
           (Col 1,2) Tj
           0.0 0.0 0.0 rg
           ET
           Q
           q
           220.0 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           220.0 590.934 Td
           (Col 1,3) Tj
           0.0 0.0 0.0 rg
           ET
           Q
           q
           20 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           20 578.934 Td
           (Col 2,1) Tj
           0.0 0.0 0.0 rg
           ET
           Q
           q
           120.0 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           120.0 578.934 Td
           (Col 2,2) Tj
           0.0 0.0 0.0 rg
           ET
           Q
           q
           220.0 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           220.0 578.934 Td
           (Col 2,3) Tj
           0.0 0.0 0.0 rg
           ET
           Q
           """
  end

  test "row exceeds available space" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    # Tiny paper so we run out of space quickly
    page = Page.new(size: [100, 100], fonts: fonts, compress: false)

    assert {_page,
            {:continue,
             [
               [
                 {[{"Col", 18.0, [_ | _]}, {" ", 3.336, [_ | _]}, {"1", 6.672, [_ | _]}],
                  [width: 26.666666666666664, x: 10]},
                 {[
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]}
                  ], [width: 26.666666666666664, x: 36.666666666666664]},
                 {[{"Col", 18.0, [_ | _]}, {" ", 3.336, [_ | _]}, {"3", 6.672, [_ | _]}],
                  [width: 26.666666666666664, x: 63.33333333333333]}
               ]
             ]}} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table({10, 90}, {80, 80}, [
               ["Header 1", "Header 2", "Header 3"],
               [
                 "Col 1",
                 long_content("Test", 5),
                 "Col 3"
               ]
             ])
  end

  test "row exceeds available space but with partial row allowed" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    # Tiny paper so we run out of space quickly
    page = Page.new(size: [100, 100], fonts: fonts, compress: false)

    assert {page,
            {:continue,
             [
               [
                 {[], [_ | _]},
                 {[
                    {"Test", 23.34, [_ | _]}
                  ], [_ | _]},
                 {[], [_ | _]}
               ]
             ]} = continued_data} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table(
               {10, 90},
               {80, 80},
               [
                 ["Header 1", "Header 2", "Header 3"],
                 [
                   "Col 1",
                   long_content("Test", 5),
                   "Col 3"
                 ]
               ],
               allow_row_overflow: true
             )

    assert {_page, :complete} =
             page |> Page.table({10, 90}, {80, 80}, continued_data, allow_row_overflow: true)
  end

  test "handle empty row generated from trailing whitespace" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    # Tiny paper so we run out of space quickly
    page = Page.new(size: [100, 100], fonts: fonts, compress: false)

    assert {_page, :complete} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table(
               {10, 90},
               {80, 80},
               [
                 ["Header 1", "Header 2", "Header 3"],
                 [
                   "Col 1",
                   "Col 2",
                   #    ↓ the error
                   "mmmm "
                 ]
               ],
               allow_row_overflow: true
             )
  end

  test "Handle empty row error" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    page = Page.new(size: :a4, fonts: fonts, compress: false)

    assert {_page, :complete} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table(
               {10, 90},
               {80, 80},
               [
                 []
               ],
               allow_row_overflow: true
             )
  end

  describe "vertical alignment" do
    @valign_data [["Short", "This description wraps onto three separate lines here"]]

    test "defaults to :top, leaving every cell against the top of the row", %{page: page} do
      assert valign_positions(page, []) == [{20, 590.934}, {80, 590.934}]
      assert valign_positions(page, valign: :top) == valign_positions(page, [])
    end

    test "a nil :valign is treated as absent", %{page: page} do
      assert valign_positions(page, valign: nil) == valign_positions(page, [])

      assert valign_positions(page, cols: [[width: 60, valign: nil], [width: 140]]) ==
               valign_positions(page, [])
    end

    test ":middle centres a short cell within the row", %{page: page} do
      assert valign_positions(page, valign: :middle) == [{20, 578.934}, {80, 590.934}]
    end

    test ":bottom pushes a short cell to the bottom of the row", %{page: page} do
      assert valign_positions(page, valign: :bottom) == [{20, 566.934}, {80, 590.934}]
    end

    test "a cell option overrides the column, which overrides the table", %{page: page} do
      assert valign_positions(page, valign: :bottom, cols: [[width: 60, valign: :top], []]) ==
               [{20, 590.934}, {80, 590.934}]

      assert valign_positions(page,
               valign: :bottom,
               cols: [[width: 60, valign: :top], []],
               rows: %{0 => [cols: [[valign: :middle], []]]}
             ) == [{20, 578.934}, {80, 590.934}]
    end

    test "a row option overrides the column", %{page: page} do
      assert valign_positions(page,
               cols: [[width: 60, valign: :top], []],
               rows: %{0 => [valign: :bottom]}
             ) == [{20, 566.934}, {80, 590.934}]
    end

    test "an unknown :valign raises instead of silently aligning to the top", %{page: page} do
      assert_raise ArgumentError, ~r/invalid :valign :centre/, fn ->
        valign_positions(page, valign: :centre)
      end
    end
  end

  defp long_content(string, repeats) do
    1..repeats
    |> Enum.map(fn _ -> string end)
    |> Enum.join(" ")
  end

  defp valign_positions(page, opts) do
    opts = Keyword.merge([padding: 0, cols: [[width: 60], [width: 140]]], opts)

    {page, :complete} =
      page
      |> Page.set_font("Helvetica", 12)
      |> Page.table({20, 600}, {200, 500}, @valign_data, opts)

    page
    |> export()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case String.split(line, " ") do
        [x, y, "Td"] -> [{parse_number(x), parse_number(y)}]
        _ -> []
      end
    end)
    |> Enum.reject(&match?({0, _}, &1))
  end

  defp parse_number(string) do
    case Integer.parse(string) do
      {integer, ""} -> integer
      _ -> String.to_float(string)
    end
  end

  describe "chunk :highlight" do
    @yellow "1.0 1.0 0.0 rg"

    defp highlighted_table(page, data, opts \\ []) do
      {page, :complete} =
        page
        |> Page.set_font("Helvetica", 12)
        |> Page.table({20, 600}, {300, 500}, data, opts)

      export(page)
    end

    defp boxes(output) do
      ~r/^(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re\nf$/m
      |> Regex.scan(output, capture: :all_but_first)
      |> Enum.map(fn numbers -> Enum.map(numbers, &(&1 |> Float.parse() |> elem(0))) end)
    end

    defp baselines(output) do
      ~r/^(-?[\d.]+) (-?[\d.]+) Td$/m
      |> Regex.scan(output, capture: :all_but_first)
      |> Enum.map(fn [_x, y] -> y |> Float.parse() |> elem(0) end)
    end

    defp colour_of(output, text) do
      output
      |> String.split("\n")
      |> Enum.reduce_while({"black", []}, fn line, {colour, saved} ->
        cond do
          line == "q" -> {:cont, {colour, [colour | saved]}}
          line == "Q" -> {:cont, {hd(saved), tl(saved)}}
          String.ends_with?(line, " rg") -> {:cont, {line, saved}}
          String.contains?(line, text) and String.ends_with?(line, "Tj") -> {:halt, colour}
          true -> {:cont, {colour, saved}}
        end
      end)
    end

    test "paints only the highlighted chunk, before the text", %{page: page} do
      output =
        highlighted_table(page, [[[{"Marked", [highlight: {255, 255, 0}]}, {" plain", []}]]])

      assert [[20.0, 588.0, width, 12.0]] = boxes(output)
      assert_in_delta width, 40.008, 0.001

      [before_text, _text] = String.split(output, "BT", parts: 2)
      assert before_text =~ @yellow
    end

    test "the text keeps its own colour", %{page: page} do
      output =
        highlighted_table(page, [
          [[{"Marked", [highlight: {255, 255, 0}]}], [{"Other", [color: {255, 0, 0}]}]]
        ])

      refute colour_of(output, "Marked") == @yellow
      assert colour_of(output, "Other") == "1.0 0.0 0.0 rg"
    end

    test "follows the alignment of its line", %{page: page} do
      output =
        highlighted_table(page, [[[{"Marked", [highlight: {255, 255, 0}]}]]],
          cols: [[align: :right]]
        )

      assert [[x, _y, width, _h]] = boxes(output)
      assert_in_delta x + width, 320.0, 0.01
    end

    test "each wrapped line gets its own box at its own baseline", %{page: page} do
      words = String.duplicate("marked ", 30) |> String.trim()
      output = highlighted_table(page, [[[{words, [highlight: {255, 255, 0}]}]]])

      box_ys = output |> boxes() |> Enum.map(fn [_x, y, _w, _h] -> y end)
      [first | moves] = baselines(output)

      expected =
        moves
        |> Enum.scan(first, &(&1 + &2))
        |> then(&[first | &1])
        |> Enum.map(&(&1 + 8.616 + 0.45 - 12))

      assert length(box_ys) > 1
      assert length(box_ys) == length(expected)

      for {box_y, line_y} <- Enum.zip(box_ys, expected), do: assert_in_delta(box_y, line_y, 0.01)
    end

    test "is clipped to the cell", %{page: page} do
      output =
        highlighted_table(page, [[[{"Marked", [highlight: {255, 255, 0}]}]]], padding: {2, 4})

      assert output =~ ~r/^24 586 292\.0 12 re\nW n\n#{@yellow}$/m
    end

    test "a table without highlights draws nothing extra", %{page: page} do
      plain = highlighted_table(page, [[[{"Marked", []}]]])
      assert boxes(plain) == []
    end
  end
end
