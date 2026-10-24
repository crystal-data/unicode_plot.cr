require "./spec_helper"

private def painted_cells(plot : UnicodePlot::Plot) : Int32
  canvas = plot.canvas
  (1..canvas.nrows).sum do |row|
    (1..canvas.ncols).count { |col| canvas.grid_at(row, col) != UnicodePlot::BLANK_BRAILLE }
  end
end

describe "audited axis and line behavior" do
  it "uses the transformed range for a Proc scale" do
    plot = UnicodePlot.scatterplot([1.0, 2.0], [1.0, 2.0],
      xscale: ->(x : Float64) { x * 2.0 }, grid: false)
    plot.canvas.origin_x.should eq(2.0)
    plot.canvas.width.should eq(2.0)
    painted_cells(plot).should eq(2)
  end

  it "keeps positive constant data and large finite constants visible" do
    [0.5, 1.0].each do |x|
      plot = UnicodePlot.scatterplot([x], [1.0], xscale: :log10, grid: false)
      plot.canvas.origin_x.finite?.should be_true
      plot.canvas.width.finite?.should be_true
      painted_cells(plot).should eq(1)
    end
    plot = UnicodePlot.scatterplot([1e20], [0.0], grid: false)
    plot.canvas.origin_x.finite?.should be_true
    plot.canvas.width.finite?.should be_true
    painted_cells(plot).should eq(1)
  end

  it "draws grid and added lines across a logarithmic axis" do
    plot = UnicodePlot.build_plot([0.1, 10.0], [-1.0, 1.0], xscale: :log10, grid: true)
    painted_cells(plot).should be > 10

    added = UnicodePlot.scatterplot([] of Float64, [] of Float64,
      xlim: {1.0, 100.0}, ylim: {0.0, 100.0},
      xscale: :log10, grid: false, width: 20, height: 8)
    UnicodePlot.hline!(added, 50.0)
    painted_cells(added).should eq(20)

    function_plot = UnicodePlot.scatterplot([] of Float64, [] of Float64,
      xlim: {1.0, 100.0}, ylim: {0.0, 100.0},
      xscale: :log10, grid: false, width: 20, height: 8)
    UnicodePlot.lineplot!(function_plot, ->(_x : Float64) { 50.0 })
    painted_cells(function_plot).should eq(20)

    vertical = UnicodePlot.scatterplot([] of Float64, [] of Float64,
      xlim: {0.0, 100.0}, ylim: {1.0, 100.0},
      yscale: :log10, grid: false, width: 20, height: 8)
    UnicodePlot.vline!(vertical, 50.0)
    painted_cells(vertical).should eq(8)
  end

  it "spans the expanded view when an explicit axis has equal endpoints" do
    plot = UnicodePlot.scatterplot([1.0], [-1e20],
      xlim: {1.0, 1.0}, ylim: {-1e20, 1e20}, grid: true, width: 20, height: 8)
    plot.raw_xlim.should eq({0.0, 2.0})
    painted_cells(plot).should be >= 20

    scaled = UnicodePlot.scatterplot([1.0], [-1.0],
      xlim: {1.0, 1.0}, ylim: {-2.0, 2.0}, xscale: :log10,
      grid: true, width: 20, height: 8)
    scaled.raw_xlim.should eq({0.1, 10.0})
    painted_cells(scaled).should be >= 20
  end

  it "clips crossing and long lines before drawing and includes both endpoints" do
    forward = UnicodePlot.lineplot([-1000.0, 0.5], [0.5, 0.5],
      xlim: {0.0, 1.0}, ylim: {0.0, 1.0}, grid: false)
    reverse = UnicodePlot.lineplot([0.5, -1000.0], [0.5, 0.5],
      xlim: {0.0, 1.0}, ylim: {0.0, 1.0}, grid: false)
    painted_cells(forward).should be > 0
    (1..forward.nrows).each do |row|
      (1..forward.ncols).each do |col|
        forward.canvas.grid_at(row, col).should eq(reverse.canvas.grid_at(row, col))
      end
    end

    crossing = UnicodePlot.lineplot([-1.0, 2.0], [0.5, 0.5],
      xlim: {0.0, 1.0}, ylim: {0.0, 1.0}, grid: false)
    painted_cells(crossing).should eq(crossing.ncols)

    canvas = UnicodePlot::BrailleCanvas.new(5, 10)
    canvas.lines!(0.04, 0.5, 0.06, 0.5)
    canvas.grid_at(3, 1).should eq(10276_u32)
  end

  it "rejects a point just outside the visible range" do
    canvas = UnicodePlot::BrailleCanvas.new(5, 10)
    canvas.points!(1.01, 0.5)
    (1..canvas.nrows).each do |row|
      (1..canvas.ncols).each do |col|
        canvas.grid_at(row, col).should eq(UnicodePlot::BLANK_BRAILLE)
      end
    end
  end

  it "keeps the original pixel phase when a vertical line enters the view" do
    canvas = UnicodePlot::BrailleCanvas.new(15, 40,
      origin_x: 1.0, origin_y: 1.0, width: 7.0, height: 6.0)
    canvas.lines!(7.8, 3.5, 7.8, 8.5)
    canvas.grid_at(5, 39).should eq(0x28b8_u32)
  end

  it "expands equal finite limits by one unit when representable" do
    plot = UnicodePlot.lineplot([50.0], [0.0],
      xlim: {50.0, 50.0}, ylim: {-1.0, 1.0})
    plot.raw_xlim.should eq({49.0, 51.0})

    large = UnicodePlot.lineplot([1e20], [0.0],
      xlim: {1e20, 1e20}, ylim: {-1.0, 1.0})
    lower, upper = large.raw_xlim.not_nil!
    lower.should be < 1e20
    upper.should be > 1e20
  end
end
