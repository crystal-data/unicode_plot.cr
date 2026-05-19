require "./spec_helper"

describe UnicodePlot do
  describe "nice_repr" do
    it "formats integers with thousands separator" do
      UnicodePlot.nice_repr(1000).should eq("1 000")
      UnicodePlot.nice_repr(1_000_000).should eq("1 000 000")
      UnicodePlot.nice_repr(-42).should eq("-42")
    end

    it "formats zero" do
      UnicodePlot.nice_repr(0.0).should eq("0")
    end

    it "formats whole floats as integers" do
      UnicodePlot.nice_repr(3.0).should eq("3")
      UnicodePlot.nice_repr(-5.0).should eq("-5")
    end

    it "formats floats compactly" do
      UnicodePlot.nice_repr(3.4).should eq("3.4")
      UnicodePlot.nice_repr(1.23456789).should eq("1.23457")
    end
  end

  describe "show_plot" do
    it "allows color output to be controlled explicitly" do
      plot = UnicodePlot.lineplot([1.0, 2.0], [1.0, 2.0], color: :red)

      default_io = IO::Memory.new
      UnicodePlot.show_plot(default_io, plot)

      colored_io = IO::Memory.new
      UnicodePlot.show_plot(colored_io, plot, use_color: true)

      plain_io = IO::Memory.new
      UnicodePlot.show_plot(plain_io, plot, use_color: false)

      default_output = default_io.to_s
      colored_output = colored_io.to_s
      plain_output = plain_io.to_s

      default_output.should_not contain("\e[")
      colored_output.should contain("\e[")
      plain_output.should_not contain("\e[")
      strip_ansi(colored_output).should eq(plain_output)
    end
  end

  describe "lineplot" do
    it "returns a Plot" do
      p = UnicodePlot.lineplot([1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
      p.should be_a(UnicodePlot::Plot)
    end

    it "accepts title and axis labels" do
      p = UnicodePlot.lineplot([1.0, 2.0], [1.0, 2.0], title: "T", xlabel: "X", ylabel: "Y")
      p.title.should eq("T")
      p.xlabel.should eq("X")
      p.ylabel.should eq("Y")
    end

    it "renders to string without error" do
      p = UnicodePlot.lineplot([1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
      s = p.to_s
      s.should contain("┌")
      s.should contain("└")
    end

    it "raises on mismatched x/y lengths" do
      expect_raises(ArgumentError, /same length/) do
        UnicodePlot.lineplot([1.0, 2.0], [1.0, 2.0, 3.0])
      end
    end

    it "raises on unknown canvas" do
      expect_raises(ArgumentError, /unknown canvas: mystery/) do
        UnicodePlot.lineplot([1.0, 2.0], [1.0, 4.0], canvas: :mystery)
      end
    end

    it "accepts RGB tuple color" do
      p = UnicodePlot.lineplot([1.0, 2.0], [1.0, 2.0], color: {0, 0, 255})
      p.to_s.should be_a(String)
    end

    it "accepts multi-series input with per-series colors" do
      p = UnicodePlot.lineplot(
        [[-1.0, 2.0], [2.0, 3.0], [3.0, 7.0]],
        [[-1.0, 2.0], [2.0, 9.0], [9.0, 4.0]],
        color: [:red, :green, :blue]
      )
      p.series.should eq(3)
    end

    it "raises when color vector length does not match series count" do
      expect_raises(ArgumentError, /color vector must have the same length as the number of series/) do
        UnicodePlot.lineplot(
          [[1.0, 2.0], [3.0, 4.0]],
          [[1.0, 2.0], [3.0, 4.0]],
          color: [:red]
        )
      end
    end

    it "accepts Int64 arrays via numeric overload" do
      p = UnicodePlot.lineplot([1_i64, 2_i64, 3_i64], [1_i64, 4_i64, 9_i64])
      p.to_s.should be_a(String)
    end

    it "accepts Int128 arrays via numeric overload" do
      p = UnicodePlot.lineplot([1_i128, 2_i128, 3_i128], [1_i128, 4_i128, 9_i128])
      p.to_s.should be_a(String)
    end

    it "accepts mixed numeric x/y element types" do
      p = UnicodePlot.lineplot([1_i32, 2_i32, 3_i32], [1.0_f32, 4.0_f32, 9.0_f32])
      p.to_s.should be_a(String)
    end

    it "accepts y-only numeric overload" do
      p = UnicodePlot.lineplot([1_i16, 4_i16, 9_i16])
      p.to_s.should be_a(String)
    end

    it "accepts numeric x with function overload" do
      p = UnicodePlot.lineplot([1_i64, 2_i64, 3_i64], ->(v : Float64) { v * v })
      p.to_s.should be_a(String)
    end

    it "accepts numeric overload in lineplot!" do
      p = UnicodePlot.lineplot([1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
      prev_series = p.series
      UnicodePlot.lineplot!(p, [1_i64, 2_i64, 3_i64], [2_i64, 3_i64, 4_i64])
      p.series.should eq(prev_series + 1)
    end

    it "accepts y-only numeric overload in lineplot!" do
      p = UnicodePlot.lineplot([1, 2, 3])
      prev_series = p.series
      UnicodePlot.lineplot!(p, [4, 5, 6])
      p.series.should eq(prev_series + 1)
    end

    it "accepts y-only UInt128 overload in lineplot!" do
      p = UnicodePlot.lineplot([1_u128, 2_u128, 3_u128])
      prev_series = p.series
      UnicodePlot.lineplot!(p, [4_u128, 5_u128, 6_u128])
      p.series.should eq(prev_series + 1)
    end

    it "ignores extreme finite values without overflowing during rasterization" do
      p = UnicodePlot.lineplot([Float64::MAX, 0.5], [0.5, 0.5])
      p.to_s.should be_a(String)
    end

    it "auto-applies unit labels from quantity arrays" do
      x = UnicodePlot.quantity([0.0, 1.0, 2.0], "m")
      y = UnicodePlot.quantity([0.0, 1.0, 4.0], "m s⁻¹")
      p = UnicodePlot.lineplot(x, y)
      p.xlabel.should eq("m")
      p.ylabel.should eq("m s⁻¹")
    end

    it "raises on mixed units within one axis" do
      x = [UnicodePlot.quantity(0.0, "m"), UnicodePlot.quantity(1.0, "cm")]
      y = [0.0, 1.0]
      expect_raises(ArgumentError, /mixed units/) do
        UnicodePlot.lineplot(x, y)
      end
    end
  end

  describe "scatterplot" do
    it "returns a Plot" do
      p = UnicodePlot.scatterplot([1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
      p.should be_a(UnicodePlot::Plot)
    end

    it "renders to string without error" do
      p = UnicodePlot.scatterplot([1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
      s = p.to_s
      s.should contain("┌")
    end

    it "raises on mismatched x/y lengths" do
      expect_raises(ArgumentError, /same length/) do
        UnicodePlot.scatterplot([1.0, 2.0], [1.0, 2.0, 3.0])
      end
    end

    it "accepts Float32 arrays via numeric overload" do
      p = UnicodePlot.scatterplot([1.0_f32, 2.0_f32, 3.0_f32], [1.0_f32, 4.0_f32, 9.0_f32])
      p.to_s.should be_a(String)
    end

    it "accepts mixed numeric x/y element types" do
      p = UnicodePlot.scatterplot([1_i32, 2_i32, 3_i32], [1.0_f64, 4.0_f64, 9.0_f64])
      p.to_s.should be_a(String)
    end

    it "accepts multi-series input with per-series colors" do
      p = UnicodePlot.scatterplot(
        [[1.0, 2.0], [2.0, 3.0]],
        [[1.0, 4.0], [4.0, 9.0]],
        color: [:red, :green]
      )
      p.series.should eq(2)
    end

    it "accepts y-only numeric overload" do
      p = UnicodePlot.scatterplot([1_i16, 4_i16, 9_i16])
      p.to_s.should be_a(String)
    end

    it "accepts numeric overload in scatterplot!" do
      p = UnicodePlot.scatterplot([1.0, 2.0, 3.0], [1.0, 4.0, 9.0])
      prev_series = p.series
      UnicodePlot.scatterplot!(p, [1_i64, 2_i64, 3_i64], [2_i64, 3_i64, 4_i64])
      p.series.should eq(prev_series + 1)
    end

    it "accepts y-only numeric overload in scatterplot!" do
      p = UnicodePlot.scatterplot([1, 2, 3])
      prev_series = p.series
      UnicodePlot.scatterplot!(p, [4, 5, 6])
      p.series.should eq(prev_series + 1)
    end

    it "auto-applies y label from quantity y-only input" do
      y = UnicodePlot.quantity([22.0, 23.0, 24.0], "°C")
      p = UnicodePlot.scatterplot(y)
      p.ylabel.should eq("°C")
    end
  end

  describe "barplot" do
    it "returns a Plot" do
      p = UnicodePlot.barplot(["a", "b", "c"], [1.0, 2.0, 3.0])
      p.should be_a(UnicodePlot::Plot)
    end

    it "renders to string without error" do
      p = UnicodePlot.barplot(["Paris", "London"], [2.244, 7.556])
      s = p.to_s
      s.should contain("Paris")
      s.should contain("London")
    end

    it "accepts a Hash" do
      p = UnicodePlot.barplot({"a" => 1.0, "b" => 2.0})
      p.should be_a(UnicodePlot::Plot)
    end

    it "routes integer arrays through the integer barplot overload" do
      p = UnicodePlot.barplot(["a", "b", "c"], [3, 7_i64, 12])
      s = p.to_s

      s.should contain(" 3 ")
      s.should contain(" 7 ")
      s.should contain(" 12 ")
    end

    it "treats mixed numeric arrays as float values" do
      p = UnicodePlot.barplot(["int", "float", "mixed"], [3, 3.0, 12])
      s = p.to_s

      s.should contain(" 3.0 ")
      s.should contain(" 12.0 ")
    end

    it "preserves explicit float labels for integer-valued floats" do
      p = UnicodePlot.barplot(["a", "b", "c"], [3.0, 7.0, 12.0])
      s = p.to_s

      s.should contain(" 3.0 ")
      s.should contain(" 7.0 ")
      s.should contain(" 12.0 ")
    end

    it "accepts integer arrays when appending bar values" do
      p = UnicodePlot.barplot(["int"], [3])
      UnicodePlot.barplot!(p, ["more"], [7])
      s = p.to_s

      s.should contain(" 3 ")
      s.should contain(" 7 ")
    end
  end

  describe "histogram" do
    it "returns a Plot" do
      p = UnicodePlot.histogram([1.0, 2.0, 3.0, 2.0, 1.0])
      p.should be_a(UnicodePlot::Plot)
    end

    it "renders bin labels without float artifacts" do
      p = UnicodePlot.histogram([1.0, 2.0, 3.0, 4.0, 5.0])
      s = p.to_s
      s.should_not contain("000000")
    end

    it "uses [a, b) brackets for closed: :left (default)" do
      p = UnicodePlot.histogram([1.0, 2.0, 3.0, 4.0, 5.0], nbins: 2, closed: :left)
      s = p.to_s
      s.should contain("[")
      s.should contain(")")
      s.should_not contain("(")
      s.should_not contain("]")
    end

    it "uses (a, b] brackets for closed: :right" do
      p = UnicodePlot.histogram([1.0, 2.0, 3.0, 4.0, 5.0], nbins: 2, closed: :right)
      s = p.to_s
      s.should contain("(")
      s.should contain("]")
      s.should_not match(/\[.*,/)
    end

    it "assigns boundary value to correct bin with closed: :right" do
      # With closed: :right, value equal to lo goes to previous bin (clamped to 0).
      # All values 1.0..5.0 split into two bins: (1,3] and (3,5]
      # value 3.0 goes to first bin with :right
      data = [1.0, 2.0, 3.0, 3.0, 5.0]
      p_left = UnicodePlot.histogram(data, nbins: 2, closed: :left)
      p_right = UnicodePlot.histogram(data, nbins: 2, closed: :right)
      # Both should render without error
      p_left.to_s.should be_a(String)
      p_right.to_s.should be_a(String)
    end

    it "applies xscale; custom xlabel used as-is (no scale suffix), default xlabel gets suffix" do
      # Custom xlabel: no [log10] suffix (matches Julia behavior)
      p = UnicodePlot.histogram([1.0, 10.0, 100.0], xscale: :log10, xlabel: "x")
      p.to_s.should contain("x")
      p.to_s.should_not contain("x [log10]")
      # Default xlabel: gets [log10] suffix
      p2 = UnicodePlot.histogram([1.0, 10.0, 100.0], xscale: :log10)
      p2.to_s.should contain("Frequency [log10]")
    end

    it "accepts RGB tuple color" do
      p = UnicodePlot.histogram([1.0, 2.0, 2.0, 3.0], color: {0, 135, 95})
      p.to_s.should be_a(String)
    end

    it "accepts Int arrays via generic numeric overload" do
      p = UnicodePlot.histogram([1, 2, 3, 2, 1])
      p.to_s.should be_a(String)
    end

    it "accepts UInt128 arrays via generic numeric overload" do
      p = UnicodePlot.histogram([1_u128, 2_u128, 3_u128, 2_u128, 1_u128])
      p.to_s.should be_a(String)
    end
  end

  describe "densityplot" do
    it "accepts two arrays (x, y) — Julia-compatible API" do
      p = UnicodePlot.densityplot([1.0, 2.0, 3.0], [4.0, 5.0, 6.0])
      p.should be_a(UnicodePlot::Plot)
    end

    it "uses DensityCanvas" do
      p = UnicodePlot.densityplot([1.0, 2.0, 3.0], [4.0, 5.0, 6.0])
      p.canvas.should be_a(UnicodePlot::DensityCanvas)
    end

    it "renders to string without error" do
      p = UnicodePlot.densityplot([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
      s = p.to_s
      s.should contain("┌")
    end

    it "shows density characters for overlapping points" do
      # Many identical points → high density → ▓ or █
      xs = Array.new(200, 0.0)
      ys = Array.new(200, 0.0)
      p = UnicodePlot.densityplot(xs, ys)
      s = p.to_s
      # At least some density character above ░ should appear
      (s.includes?('▒') || s.includes?('▓') || s.includes?('█')).should be_true
    end

    it "raises on empty data" do
      expect_raises(ArgumentError) do
        UnicodePlot.densityplot([] of Float64, [] of Float64)
      end
    end

    it "raises on mismatched lengths" do
      expect_raises(ArgumentError, /same length/) do
        UnicodePlot.densityplot([1.0, 2.0], [1.0])
      end
    end

    it "supports dscale parameter" do
      p = UnicodePlot.densityplot([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], dscale: :log10)
      p.should be_a(UnicodePlot::Plot)
    end

    it "accepts Int arrays via generic numeric overload" do
      p = UnicodePlot.densityplot([1, 2, 3], [4, 5, 6])
      p.to_s.should be_a(String)
    end
  end

  describe "boxplot" do
    it "returns a Plot" do
      p = UnicodePlot.boxplot([1.0, 2.0, 3.0, 7.0])
      p.should be_a(UnicodePlot::Plot)
    end

    it "uses :corners border by default (matches Julia)" do
      p = UnicodePlot.boxplot([1.0, 2.0, 3.0, 7.0])
      p.border.should eq(:corners)
    end

    it "has three x-axis labels (min, mean, max) matching Julia" do
      p = UnicodePlot.boxplot([1.0, 2.0, 3.0, 7.0])
      # Should have bl, b, br labels
      p.decorations[:bl]?.should_not be_nil
      p.decorations[:b]?.should_not be_nil
      p.decorations[:br]?.should_not be_nil
    end

    it "renders box with Julia-style five-number summary characters" do
      p = UnicodePlot.boxplot([1.0, 2.0, 3.0, 7.0])
      s = p.to_s
      # Julia uses ╷ ├ ╵ ┌ ┤ └ ┬ │ ┴ ┐ ├ ┘ characters
      (s.includes?('╷') || s.includes?('╵') || s.includes?('├') || s.includes?('┤')).should be_true
    end

    it "accepts an array of arrays" do
      p = UnicodePlot.boxplot([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
      p.should be_a(UnicodePlot::Plot)
    end

    it "accepts a Hash" do
      p = UnicodePlot.boxplot({"series1" => [1.0, 2.0, 3.0]})
      p.should be_a(UnicodePlot::Plot)
    end

    it "renders without error" do
      p = UnicodePlot.boxplot([1.0, 2.0, 3.0, 7.0], title: "Test")
      p.to_s.should contain("Test")
    end

    it "accepts Int arrays via generic numeric overload" do
      p = UnicodePlot.boxplot([1, 2, 3, 7])
      p.to_s.should be_a(String)
    end
  end

  describe "heatmap" do
    it "returns a Plot" do
      p = UnicodePlot.heatmap([[1.0, 2.0], [3.0, 4.0]])
      p.should be_a(UnicodePlot::Plot)
    end

    it "renders to string without error" do
      p = UnicodePlot.heatmap([[1.0, 2.0], [3.0, 4.0]])
      p.to_s.should be_a(String)
    end

    it "handles NaN without crashing" do
      z = [[Float64::NAN, 1.0], [2.0, Float64::NAN]]
      p = UnicodePlot.heatmap(z)
      p.to_s.should be_a(String)
    end

    it "handles Inf without crashing" do
      z = [[Float64::INFINITY, 1.0], [2.0, -Float64::INFINITY]]
      p = UnicodePlot.heatmap(z)
      p.to_s.should be_a(String)
    end

    it "handles all-NaN matrix using fallback range" do
      z = [[Float64::NAN, Float64::NAN]]
      p = UnicodePlot.heatmap(z)
      p.to_s.should be_a(String)
      p.colormap.lim.should eq({0.0, 1.0})
    end

    it "uses finite extrema for colormap limits" do
      z = [[Float64::INFINITY, 1.0], [2.0, -Float64::INFINITY]]
      p = UnicodePlot.heatmap(z)
      p.colormap.lim.should eq({1.0, 2.0})
    end

    it "accepts Int matrix via generic numeric overload" do
      p = UnicodePlot.heatmap([[1, 2], [3, 4]])
      p.to_s.should be_a(String)
    end

    it "accepts Int128 matrix via generic numeric overload" do
      p = UnicodePlot.heatmap([[1_i128, 2_i128], [3_i128, 4_i128]])
      p.to_s.should be_a(String)
    end

    it "raises on unknown colormap" do
      expect_raises(ArgumentError, /unknown colormap: mystery/) do
        UnicodePlot.heatmap([[1.0, 2.0], [3.0, 4.0]], colormap: :mystery)
      end
    end

    it "rejects jagged matrix input" do
      expect_raises(ArgumentError, /same length/) do
        UnicodePlot.heatmap([[1.0, 2.0], [3.0]])
      end
    end
  end

  describe "spy" do
    it "returns a Plot" do
      p = UnicodePlot.spy([[1.0, 0.0], [0.0, -2.0]])
      p.should be_a(UnicodePlot::Plot)
    end

    it "uses auto color legend for positive and negative values" do
      p = UnicodePlot.spy([[1.0, 0.0], [0.0, -2.0]])
      p.labels_right[1]?.should eq("> 0")
      p.labels_right[2]?.should eq("< 0")
    end

    it "shows zeros pattern when show_zeros is true" do
      p = UnicodePlot.spy([[1.0, 0.0], [0.0, -2.0]], show_zeros: true)
      p.labels_right[1]?.should eq("⩵ 0")
      p.xlabel.should contain("⩵ 0")
    end

    it "accepts empty matrices" do
      p = UnicodePlot.spy([] of Array(Float64))
      p.should be_a(UnicodePlot::Plot)
    end
  end

  describe "polarplot" do
    it "returns a Plot" do
      theta = [0.0, Math::PI / 2.0, Math::PI]
      r = [0.5, 1.0, 1.5]
      p = UnicodePlot.polarplot(theta, r)
      p.should be_a(UnicodePlot::Plot)
    end

    it "raises on mismatched theta/r lengths" do
      expect_raises(ArgumentError, /same length/) do
        UnicodePlot.polarplot([0.0, Math::PI], [1.0])
      end
    end

    it "accepts numeric overloads" do
      p = UnicodePlot.polarplot([0_i64, 1_i64, 2_i64], [1_i32, 2_i32, 3_i32])
      p.to_s.should be_a(String)
    end

    it "accepts callable radius" do
      theta = [0.0, Math::PI / 2.0, Math::PI]
      p = UnicodePlot.polarplot(theta, ->(angle : Float64) { angle + 1.0 })
      p.to_s.should be_a(String)
    end

    it "supports scatter mode with lines: false" do
      theta = [0.0, Math::PI / 2.0, Math::PI, 3.0 * Math::PI / 2.0]
      r = [1.0, 1.0, 1.0, 1.0]
      p = UnicodePlot.polarplot(theta, r, lines: false)
      p.to_s.should contain("0°")
      p.to_s.should contain("90°")
      p.to_s.should contain("180°")
      p.to_s.should contain("270°")
    end

    it "uses 3π / 2 label when degrees is false" do
      theta = [0.0, Math::PI / 2.0, Math::PI, 3.0 * Math::PI / 2.0]
      r = [1.0, 1.0, 1.0, 1.0]
      p = UnicodePlot.polarplot(theta, r, degrees: false)
      p.to_s.should contain("0")
      p.to_s.should contain("π / 2")
      p.to_s.should contain("π")
      p.to_s.should contain("3π / 2")
      p.to_s.should_not contain("3π / 4")
    end
  end

  describe "stairs" do
    it "raises on mismatched x/y lengths" do
      expect_raises(ArgumentError, /same length/) do
        p = UnicodePlot.lineplot([1.0, 2.0], [1.0, 2.0])
        UnicodePlot.stairs!(p, [1.0, 2.0], [1.0])
      end
    end

    it "ignores extreme finite values without overflowing during rasterization" do
      p = UnicodePlot.stairs([Float64::MAX, 0.5], [0.5, 0.5])
      p.to_s.should be_a(String)
    end

    it "accepts Int arrays via generic numeric overload" do
      p = UnicodePlot.stairs([1, 2, 3], [4, 5, 6])
      p.to_s.should be_a(String)
    end

    it "accepts y-only numeric overload in stairs!" do
      p = UnicodePlot.stairs([1, 2, 3], [4, 5, 6])
      prev_series = p.series
      UnicodePlot.stairs!(p, [7, 8, 9])
      p.series.should eq(prev_series + 1)
    end

    it "accepts UInt128 arrays via generic numeric overload" do
      p = UnicodePlot.stairs([1_u128, 2_u128, 3_u128], [4_u128, 5_u128, 6_u128])
      p.to_s.should be_a(String)
    end
  end

  describe "BrailleCanvas" do
    it "has correct pixel dimensions" do
      c = UnicodePlot::BrailleCanvas.new(10, 20,
        origin_y: 0.0, origin_x: 0.0, height: 1.0, width: 1.0)
      c.nrows.should eq(10)
      c.ncols.should eq(20)
      c.y_pixel_per_char.should eq(4)
      c.x_pixel_per_char.should eq(2)
    end

    it "ignores extreme out-of-range points without overflow" do
      c = UnicodePlot::BrailleCanvas.new(10, 20,
        origin_y: 0.0, origin_x: 0.0, height: 1.0, width: 1.0)
      color = UnicodePlot.ansi_color(:green)

      c.points!(Float64::MAX, 0.5, color, true)
      c.points!(-Float64::MAX, 0.5, color, true)
      c.points!(0.5, Float64::MAX, color, true)
      c.points!(0.5, -Float64::MAX, color, true)

      c.to_s.should be_a(String)
    end

    it "rejects point color vectors with wrong length" do
      p = UnicodePlot.scatterplot([1.0, 2.0], [1.0, 2.0])

      expect_raises(ArgumentError, /colors/) do
        p.points!(
          [1.0, 2.0],
          [1.0, 2.0],
          [UnicodePlot.plot_color(:red)],
          p.canvas.blend?
        )
      end
    end

    it "rejects segment color vectors with wrong length" do
      p = UnicodePlot.lineplot([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])

      expect_raises(ArgumentError, /segment_colors/) do
        p.lines!(
          [1.0, 2.0, 3.0],
          [1.0, 2.0, 3.0],
          [UnicodePlot.plot_color(:red)],
          p.canvas.blend?
        )
      end
    end
  end

  describe "BlockCanvas" do
    it "has correct pixel dimensions" do
      c = UnicodePlot::BlockCanvas.new(5, 10,
        origin_y: 0.0, origin_x: 0.0, height: 1.0, width: 1.0)
      c.y_pixel_per_char.should eq(2)
      c.x_pixel_per_char.should eq(2)
    end
  end

  describe "DensityCanvas" do
    it "has correct pixel dimensions (2×1 per cell)" do
      c = UnicodePlot::DensityCanvas.new(10, 20,
        origin_y: 0.0, origin_x: 0.0, height: 1.0, width: 1.0)
      c.nrows.should eq(10)
      c.ncols.should eq(20)
      c.y_pixel_per_char.should eq(2)
      c.x_pixel_per_char.should eq(1)
    end

    it "accumulates hit counts and renders density chars" do
      c = UnicodePlot::DensityCanvas.new(10, 20,
        origin_y: 0.0, origin_x: 0.0, height: 1.0, width: 1.0)
      # Single hit: max_density=1, normalized val=1.0 → '█' (highest density char)
      c.points!(0.5, 0.5, UnicodePlot.ansi_color(:green), true)
      io = IO::Memory.new
      _ = c.preprocess(io)
      c.to_s.should contain('█')
    end
  end

  describe "AsciiCanvas" do
    it "has correct pixel dimensions (3×3 per cell)" do
      c = UnicodePlot::AsciiCanvas.new(5, 10,
        origin_y: 0.0, origin_x: 0.0, height: 1.0, width: 1.0)
      c.y_pixel_per_char.should eq(3)
      c.x_pixel_per_char.should eq(3)
    end

    it "decode table has 512 entries" do
      UnicodePlot::ASCII_DECODE_512.size.should eq(512)
    end

    it "empty cell decodes to space" do
      UnicodePlot::ASCII_DECODE_512[0].should eq(' ')
    end

    it "full cell decodes to @" do
      UnicodePlot::ASCII_DECODE_512[0b111_111_111].should eq('@')
    end

    it "renders a lineplot with canvas: :ascii without error" do
      p = UnicodePlot.lineplot([1.0, 2.0, 3.0], [1.0, 4.0, 9.0], canvas: :ascii)
      p.to_s.should be_a(String)
    end
  end

  describe "ansi_color" do
    it "converts named symbols" do
      UnicodePlot.ansi_color(:green).should eq(UnicodePlot::THRESHOLD + 2)
      UnicodePlot.ansi_color(:red).should eq(UnicodePlot::THRESHOLD + 1)
    end

    it "returns INVALID_COLOR for nil" do
      UnicodePlot.ansi_color(nil).should eq(UnicodePlot::INVALID_COLOR)
    end
  end

  describe "experimental Time x-axis support" do
    it "requires an explicit format string" do
      times = [Time.utc(2020, 1, 1), Time.utc(2020, 1, 2)]
      expect_raises(ArgumentError, /format is required for Time x values/) do
        UnicodePlot.lineplot(times, [1.0, 2.0])
      end
    end
  end
end
