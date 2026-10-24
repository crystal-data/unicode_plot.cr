require "./spec_helper"

describe "audited rendering and public APIs" do
  it "shows character markers on every canvas without corrupting pixels" do
    [:braille, :block, :ascii, :dot, :density].each do |canvas|
      plot = UnicodePlot.scatterplot([0.5], [0.5], marker: 'X', canvas: canvas, grid: false)
      plot.to_s.should contain('X')
    end
  end

  it "uses display columns for wide labels and annotations" do
    UnicodePlot.display_width("日本").should eq(4)
    UnicodePlot.display_width("e\u0301").should eq(1)
    plot = UnicodePlot.barplot(["A", "日本"], [1.0, 2.0], width: 10)
    lines = plot.to_s.lines
    ascii_line = lines.find(&.includes?("A")) || ""
    wide_line = lines.find(&.includes?("日本")) || ""
    ascii_col = ascii_line.index('┤') || -1
    wide_col = wide_line.index('┤') || -1
    UnicodePlot.display_width(ascii_line[0...ascii_col]).should eq(UnicodePlot.display_width(wide_line[0...wide_col]))

    canvas_plot = UnicodePlot.build_plot([0.0, 1.0], [0.0, 1.0], grid: false)
    canvas_plot.annotate!(0.5, 0.5, "日本", UnicodePlot::INVALID_COLOR, false, halign: :left)
    canvas_plot.to_s.should contain("日本")
  end

  it "passes alignment through Plot#annotate! and does not retain compact labels" do
    left = UnicodePlot.build_plot([0.0, 1.0], [0.0, 1.0], grid: false)
    right = UnicodePlot.build_plot([0.0, 1.0], [0.0, 1.0], grid: false)
    left.annotate!(0.5, 0.5, "ABC", UnicodePlot::INVALID_COLOR, false, halign: :left, valign: :top)
    right.annotate!(0.5, 0.5, "ABC", UnicodePlot::INVALID_COLOR, false, halign: :right, valign: :bottom)
    left.to_s.should contain("ABC")
    left.to_s.should_not eq(right.to_s)

    compact = UnicodePlot.lineplot([1.0, 2.0], [1.0, 2.0],
      xlabel: "OLD_LABEL", compact_labels: true)
    compact.to_s.should contain("OLD_LABEL")
    compact.xlabel = ""
    compact.to_s.should_not contain("OLD_LABEL")
  end

  it "keeps multiline bar rows, colors, and scales aligned" do
    plot = UnicodePlot.barplot(["a\nb", "c"], [100.0, 1000.0],
      color: [:red, :blue], xscale: :log10)
    area = plot.graphics.as(UnicodePlot::BarplotGraphics)
    area.spacer_rows.should eq([true, false, false])
    area.colors.size.should eq(3)
    plot.to_s.should contain("1 000.0")

    UnicodePlot.barplot!(plot, ["d\ne"], [1e12])
    area.spacer_rows.last(2).should eq([true, false])
    plot.labels_left[4].should eq("d")
    plot.labels_left[5].should eq("e")
    area.ncols.should be >= 20
    plot.to_s.should contain("d")
    cleanup = area.preprocess(IO::Memory.new)
    last_row = IO::Memory.new
    area.print_row(last_row, area.nrows, false)
    UnicodePlot.display_width(last_row.to_s).should eq(area.ncols)
    cleanup.call(area)
  end

  it "renders large finite bars and polar radii without integer overflow" do
    UnicodePlot.barplot(["a"], [1e20]).to_s.should contain("a")
    UnicodePlot.barplot(["a"], [Int64::MAX]).to_s.should contain("a")
    UnicodePlot.polarplot([0.0, 1.0], [3e9, 4e9]).to_s.should contain("0°")
  end

  it "accepts integer boxplot series and Quantity lineplot keywords" do
    UnicodePlot.boxplot([[1, 2], [3, 4]]).graphics.as(UnicodePlot::BoxplotGraphics).boxes.size.should eq(2)
    quantity_y = UnicodePlot.quantity([1, 2], "m")
    UnicodePlot.lineplot(quantity_y, title: "distance").title.should eq("distance")
    UnicodePlot.lineplot([1, 2], quantity_y, title: "distance").title.should eq("distance")
  end

  it "flips density axis labels and supports advertised scales and borders" do
    flipped = UnicodePlot.densityplot([1.0, 2.0], [10.0, 20.0],
      xlim: {1.0, 2.0}, ylim: {10.0, 20.0}, xflip: true, yflip: true,
      width: 10, height: 5)
    flipped.decorations[:bl].should eq("2")
    flipped.decorations[:br].should eq("1")
    flipped.labels_left[1].should eq("10")
    flipped.labels_left[5].should eq("20")

    UnicodePlot.barplot(["a"], [8.0], xscale: :cbrt, border: :double).to_s.should contain("╔")
    UnicodePlot.scatterplot([1.0], [2.0], canvas: :density).graphics.should be_a(UnicodePlot::DensityCanvas)
  end
end
