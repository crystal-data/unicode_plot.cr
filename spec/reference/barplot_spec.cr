require "../support/reference_helpers"

describe "Julia reference output compatibility - barplot" do
  describe "barplot" do
    it "matches barplot/default" do
      p = UnicodePlot.barplot(["bar", "foo"], [23, 37])
      test_ref("barplot/default.txt", p)
    end

    it "matches barplot/default2 (with barplot! appended)" do
      p = UnicodePlot.barplot(["bar", "foo"], [23, 37])
      UnicodePlot.barplot!(p, ["zoom"], [90])
      test_ref("barplot/default2.txt", p)
    end

    it "matches barplot/nocolor" do
      p = UnicodePlot.barplot(["bar", "foo"], [23, 37])
      test_ref("barplot/nocolor.txt", p)
    end

    it "matches barplot/ranges" do
      p = UnicodePlot.barplot(["2", "3", "4", "5", "6"], [11, 12, 13, 14, 15])
      test_ref("barplot/ranges.txt", p)
    end

    it "matches barplot/ranges2" do
      p = UnicodePlot.barplot(["2", "3", "4", "5", "6"], [11, 12, 13, 14, 15])
      UnicodePlot.barplot!(p, ["9", "10"], [20, 21])
      test_ref("barplot/ranges2.txt", p)
    end

    it "matches barplot/parameters1" do
      p = UnicodePlot.barplot(
        ["Paris", "New York", "Moskau", "Madrid"],
        [2.244, 8.406, 11.92, 3.165],
        title: "Relative sizes of cities",
        xlabel: "population [in mil]",
        color: :blue,
        margin: 7,
        padding: 3,
      )
      test_ref("barplot/parameters1.txt", p)
    end

    it "matches barplot/parameters1_nolabels" do
      p = UnicodePlot.barplot(
        ["Paris", "New York", "Moskau", "Madrid"],
        [2.244, 8.406, 11.92, 3.165],
        title: "Relative sizes of cities",
        xlabel: "population [in mil]",
        color: :blue,
        margin: 7,
        padding: 3,
        labels: false,
      )
      test_ref("barplot/parameters1_nolabels.txt", p)
    end

    it "matches barplot/parameters2" do
      p = UnicodePlot.barplot(
        ["Paris", "New York", "Moskau", "Madrid"],
        [2.244, 8.406, 11.92, 3.165],
        title: "Relative sizes of cities",
        xlabel: "population [in mil]",
        color: :yellow,
        border: :solid,
        symbols: ['='],
        width: 60,
      )
      test_ref("barplot/parameters2.txt", p)
    end

    it "matches barplot/edgecase_zeros" do
      p = UnicodePlot.barplot(["5", "4", "3", "2", "1"], [0, 0, 0, 0, 0])
      test_ref("barplot/edgecase_zeros.txt", p)
    end

    it "matches barplot/edgecase_onelarge" do
      p = UnicodePlot.barplot(["a", "b", "c", "d"], [1, 1, 1, 1_000_000])
      test_ref("barplot/edgecase_onelarge.txt", p)
    end

    it "matches barplot/col1 (8-bit terminal color, ANSI stripped)" do
      p = UnicodePlot.barplot(["B", "A"], [2, 1], color: 9_i32)
      test_ref("barplot/col1.txt", p)
    end

    it "matches barplot/log10" do
      p = UnicodePlot.barplot(
        ["a", "b", "c", "d", "e"],
        [0, 1, 10, 100, 1_000],
        title: "Logscale Plot",
        xscale: :log10,
      )
      test_ref("barplot/log10.txt", p)
    end

    it "matches barplot/log10_label" do
      p = UnicodePlot.barplot(
        ["a", "b", "c", "d", "e"],
        [0, 1, 10, 100, 1_000],
        title: "Logscale Plot",
        xlabel: "custom label",
        xscale: :log10,
      )
      test_ref("barplot/log10_label.txt", p)
    end

    it "matches barplot/col2 (RGB tuple color)" do
      p = UnicodePlot.barplot(["B", "A"], [2, 1], color: {200, 50, 0})
      test_ref("barplot/col2.txt", p)
    end

    it "matches barplot/colors (per-bar color vector)" do
      p = UnicodePlot.barplot(
        ["a", "b", "c", "d", "e"],
        [20, 30, 60, 50, 40],
        color: [:red, :green, :blue, :yellow, :normal],
      )
      test_ref("barplot/colors.txt", p)
    end

    it "matches barplot/maximum_series1" do
      p = UnicodePlot.barplot(
        ["1", "2", "3"],
        [1, 2, 3],
        color: :blue,
        name: "1ˢᵗ series",
        maximum: 10.0,
      )
      test_ref("barplot/maximum_series1.txt", p)
    end

    it "matches barplot/maximum_series2" do
      p = UnicodePlot.barplot(
        ["1", "2", "3"],
        [1, 2, 3],
        color: :blue,
        name: "1ˢᵗ series",
        maximum: 10.0,
      )
      UnicodePlot.barplot!(p, ["4", "5", "6"], [6, 1, 10], color: :red, name: "2ⁿᵈ series")
      test_ref("barplot/maximum_series2.txt", p)
    end
  end
end
