require "./spec_helper"

describe "audited numeric and matrix behavior" do
  it "counts the minimum in a right-closed interval that actually contains it" do
    plot = UnicodePlot.histogram([0.0, 1.0, 2.0], nbins: 2, closed: :right)
    bars = plot.graphics.as(UnicodePlot::BarplotGraphics).bars
    plot.labels_left[1].gsub(/\s+/, "").should eq("(-1.0,0.0]")
    bars.first.should eq(1.0)
    bars.sum.should eq(3.0)
  end

  it "puts an exact Float64 edge in the left-closed bin" do
    edge = 43 * 0.1
    plot = UnicodePlot.histogram([0.0, edge, 5.0], nbins: 50)
    bars = plot.graphics.as(UnicodePlot::BarplotGraphics).bars
    bars[42].should eq(0.0)
    bars[43].should eq(1.0)
    bars.sum.should eq(3.0)
  end

  it "honors closure and display options in vertical histograms" do
    data = [0.0, 0.0, 1.0, 2.0]
    left = UnicodePlot.histogram(data, nbins: 2, vertical: true, closed: :left)
    right = UnicodePlot.histogram(data, nbins: 2, vertical: true, closed: :right)
    left.canvas.should be_a(UnicodePlot::BlockCanvas)
    left.decorations[:bl].should_not eq(right.decorations[:bl])

    plot = UnicodePlot.histogram(data, vertical: true, labels: false, margin: 0, padding: 0)
    plot.labels?.should be_false
    plot.margin.should eq(0)
    plot.padding.should eq(0)
  end

  it "keeps large constant histograms finite and empty display options" do
    plot = UnicodePlot.histogram([1e20, 1e20])
    plot.graphics.as(UnicodePlot::BarplotGraphics).bars.sum.should eq(2.0)

    empty = UnicodePlot.histogram([] of Float64,
      title: "Empty", width: 10, labels: false, margin: 0, padding: 0)
    empty.title.should eq("Empty")
    empty.labels?.should be_false
    empty.margin.should eq(0)
    empty.padding.should eq(0)
  end

  it "preserves heatmap coordinates when visible limits expand" do
    plot = UnicodePlot.heatmap([[1.0, 2.0], [3.0, 4.0]],
      xlim: {0.0, 3.0}, height: 2, width: 4)
    data = plot.graphics.as(UnicodePlot::HeatmapGraphics).data
    data.size.should eq(2)
    data.each do |row|
      row[0].nan?.should be_true
      row[3].nan?.should be_true
    end
    data[0][1..2].should eq([1.0, 2.0])
    data[1][1..2].should eq([3.0, 4.0])
  end

  it "renders cells without source data with Julia's black background" do
    plot = UnicodePlot.heatmap([[1.0, 2.0], [3.0, 4.0]],
      xlim: {50.0, 60.0}, height: 2, width: 2, labels: false)
    area = plot.graphics.as(UnicodePlot::HeatmapGraphics)
    area.data.flatten.all?(&.nan?).should be_true

    colored = IO::Memory.new
    plain = IO::Memory.new
    area.print_row(colored, 1, true)
    area.print_row(plain, 1, false)
    colored.to_s.should eq("\e[38;5;0m\e[48;5;0m▄\e[0m" * 2)
    plain.to_s.should eq("▄▄")
  end

  it "colors only the populated half of a heatmap cell" do
    upper = UnicodePlot.heatmap([[Float64::NAN], [1.0]], height: 2, width: 1)
    lower = UnicodePlot.heatmap([[1.0], [Float64::NAN]], height: 2, width: 1)
    upper_io = IO::Memory.new
    lower_io = IO::Memory.new
    upper.graphics.print_row(upper_io, 1, true)
    lower.graphics.print_row(lower_io, 1, true)
    upper_io.to_s.should contain("▀")
    upper_io.to_s.should_not contain("[48;")
    lower_io.to_s.should contain("▄")
    lower_io.to_s.should_not contain("[48;")
  end

  it "stops contours at missing cells without erasing small coordinates" do
    missing = UnicodePlot::MatrixView.new([[0.0, 0.0, Float64::NAN], [1.0, 1.0, 2.0]])
    level = UnicodePlot::Contour.contour([0.0, 1.0, 2.0], [0.0, 1.0], missing, 0.5)
    level.lines.size.should eq(1)
    level.lines.first.vertices.size.should eq(2)

    small = UnicodePlot::MatrixView.new([[0.0, 0.0], [1.0, 1.0]])
    line = UnicodePlot::Contour.contour([0.0, 1e-16], [0.0, 1e-16], small, 0.5)
    line.lines.first.vertices.map(&.[0]).should contain(1e-16)
    line.lines.first.vertices.map(&.[1]).should contain(5e-17)
  end
end
