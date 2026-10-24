require "../support/reference_helpers"
require "set"

# Compare the chart and labels exactly, while allowing contour strokes to move
# by one Braille pixel when traversal order or floating-point rounding differs.
private def contour_reference_pixels(text : String) : {Set({Int32, Int32}), String}
  pixels = Set({Int32, Int32}).new
  frame = String.build do |io|
    normalize_output(strip_ansi(text)).split('\n').each_with_index do |line, row|
      io << '\n' unless row == 0
      line.chars.each_with_index do |char, col|
        code = char.ord
        if 0x2800 <= code <= 0x28ff
          bits = code - 0x2800
          {
            {0, 0, 0x01}, {0, 1, 0x02}, {0, 2, 0x04}, {0, 3, 0x40},
            {1, 0, 0x08}, {1, 1, 0x10}, {1, 2, 0x20}, {1, 3, 0x80},
          }.each do |dx, dy, mask|
            pixels.add({2 * col + dx, 4 * row + dy}) if bits & mask != 0
          end
          io << '⠀'
        else
          io << char
        end
      end
    end
  end
  {pixels, frame}
end

private def contour_pixel_near?(pixels : Set({Int32, Int32}), x : Int32, y : Int32) : Bool
  (-1..1).any? do |dx|
    (-1..1).any? { |dy| pixels.includes?({x + dx, y + dy}) }
  end
end

private def test_contour_ref(relative_path : String, plot : UnicodePlot::Plot) : Nil
  expected, expected_frame = contour_reference_pixels(File.read(File.join(JULIA_REFS, relative_path)))
  actual, actual_frame = contour_reference_pixels(plot.to_s)

  actual_frame.should eq(expected_frame)
  actual.should_not be_empty
  (actual.size - expected.size).abs.should be <= (expected.size * 0.02).ceil.to_i
  actual.count { |x, y| !contour_pixel_near?(expected, x, y) }.should eq(0)
  expected.count { |x, y| !contour_pixel_near?(actual, x, y) }.should eq(0)
end

describe "Julia reference output compatibility - contourplot" do
  describe "contourplot" do
    (0..3).each do |padding|
      it "matches contourplot/padding_#{padding} within one Braille pixel" do
        x = range_by_step(-1.0, 1.0, 0.1)
        z = x.map { |y_value| x.map { |x_value| 1.0e4 * Math.sqrt(x_value**2 + y_value**2) } }
        p = UnicodePlot.contourplot(x, x, z, labels: false, margin: 0, padding: padding)
        test_contour_ref("contourplot/padding_#{padding}.txt", p)
      end
    end

    it "matches contourplot/gauss_cividis" do
      x, y, z = gaussian_2d
      p = UnicodePlot.contourplot(x, y, z, colormap: :cividis)
      test_ref("contourplot/gauss_cividis.txt", p)
    end

    it "matches contourplot/gauss_5levels" do
      x, y, z = gaussian_2d
      p = UnicodePlot.contourplot(x, y, z, levels: 5)
      test_ref("contourplot/gauss_5levels.txt", p)
    end

    it "matches contourplot/gauss_nested" do
      x1, y1, z1 = gaussian_2d
      p = UnicodePlot.contourplot(x1, y1, z1, levels: 2)

      x2, y2, z2 = gaussian_2d(sigma_x: 0.5, sigma_y: 0.25)
      UnicodePlot.contourplot!(p, x2, y2, z2, levels: 1, colormap: :magma)
      test_ref("contourplot/gauss_nested.txt", p)
    end

    it "matches contourplot/function_contour" do
      x = range_by_step(-3.0, 3.0, 0.01)
      y = range_by_step(-3.0, 4.0, 0.01)
      z = y.map do |y_value|
        x.map do |x_value|
          t1 = Math.exp(-(x_value**2) - (y_value**2))
          t2 = Math.exp(-((x_value - 1.0)**2) - 2.0 * ((y_value - 2.0)**2))
          (t1 + t2)**2
        end
      end
      p = UnicodePlot.contourplot(x, y, z)
      test_ref("contourplot/function_contour.txt", p)
    end

    it "matches contourplot/consistency within one Braille pixel" do
      x = range_by_step(-2.0, 2.0, 0.2)
      y = range_by_step(-3.0, 1.0, 0.2)
      z = y.map { |y_value| x.map { |x_value| 10.0 * x_value * Math.exp(-(x_value**2) - (y_value**2)) } }
      p = UnicodePlot.contourplot(x, y, z, levels: 10)
      test_contour_ref("contourplot/consistency.txt", p)
    end
  end
end
