module UnicodePlot
  # Abstract pixel-based canvas.
  # The grid is stored as a flat row-major array: index = row * ncols + col (0-based).
  abstract class Canvas < GraphicsArea
    getter nrows : Int32 # character rows
    getter ncols : Int32 # character columns
    getter? visible : Bool
    getter? blend : Bool
    getter? yflip : Bool
    getter? xflip : Bool
    getter pixel_height : Int32
    getter pixel_width : Int32
    getter origin_y : Float64
    getter origin_x : Float64
    getter height : Float64
    getter width : Float64
    getter yscale : Proc(Float64, Float64)
    getter xscale : Proc(Float64, Float64)

    @grid : Array(UInt32)
    @colors : Array(UInt32)

    abstract def blank : Char
    abstract def y_pixel_per_char : Int32
    abstract def x_pixel_per_char : Int32
    abstract def pixel!(pixel_x : Int32, pixel_y : Int32, color : UInt32, blend : Bool) : self

    def initialize(
      @nrows : Int32,
      @ncols : Int32,
      @visible : Bool,
      @blend : Bool,
      @yflip : Bool,
      @xflip : Bool,
      @pixel_height : Int32,
      @pixel_width : Int32,
      @origin_y : Float64,
      @origin_x : Float64,
      @height : Float64,
      @width : Float64,
      @yscale : Proc(Float64, Float64),
      @xscale : Proc(Float64, Float64),
      fill_value : UInt32,
    )
      @grid = Array(UInt32).new(@nrows * @ncols, fill_value)
      @colors = Array(UInt32).new(@nrows * @ncols, INVALID_COLOR)
    end

    # Grid and color accessors (1-based row/col)
    def grid_at(row : Int32, col : Int32) : UInt32
      @grid[(row - 1) * @ncols + (col - 1)]
    end

    def grid_set!(row : Int32, col : Int32, val : UInt32) : Nil
      @grid[(row - 1) * @ncols + (col - 1)] = val
    end

    def color_at(row : Int32, col : Int32) : UInt32
      @colors[(row - 1) * @ncols + (col - 1)]
    end

    def color_set!(row : Int32, col : Int32, color : UInt32) : Nil
      @colors[(row - 1) * @ncols + (col - 1)] = color
    end

    # Coordinate transforms: value → pixel
    def y_to_pixel(y : Float64) : Float64
      if @yflip
        (y - @origin_y) / @height * @pixel_height
      else
        (1.0 - (y - @origin_y) / @height) * @pixel_height
      end
    end

    def x_to_pixel(x : Float64) : Float64
      if @xflip
        (1.0 - (x - @origin_x) / @width) * @pixel_width
      else
        (x - @origin_x) / @width * @pixel_width
      end
    end

    def scale_y_to_pixel(y : Float64) : Float64
      y_to_pixel(@yscale.call(y))
    end

    def scale_x_to_pixel(x : Float64) : Float64
      x_to_pixel(@xscale.call(x))
    end

    def valid_y?(y : Float64) : Bool
      return false unless y.finite?
      sy = @yscale.call(y)
      sy.finite? && @origin_y <= sy <= @origin_y + @height
    end

    def valid_x?(x : Float64) : Bool
      return false unless x.finite?
      sx = @xscale.call(x)
      sx.finite? && @origin_x <= sx <= @origin_x + @width
    end

    def valid_y_pixel?(py : Int32) : Bool
      0 <= py <= @pixel_height
    end

    def valid_x_pixel?(px : Int32) : Bool
      0 <= px <= @pixel_width
    end

    # Set the color at char cell (col, row), blending if requested
    def set_color!(col : Int32, row : Int32, color : UInt32, blend : Bool) : Nil
      current = color_at(row, col)
      new_color = if current == INVALID_COLOR || !blend
                    color
                  else
                    UnicodePlot.blend_colors(current, color)
                  end
      color_set!(row, col, new_color)
    end

    # High-level pixel placement (color conversion from symbol/int done by caller)
    def pixel!(pixel_x : Int32, pixel_y : Int32, *, color : UInt32 = INVALID_COLOR) : self
      pixel!(pixel_x, pixel_y, UnicodePlot.ansi_color(color), @blend)
    end

    private def floor_to_i32(value : Float64) : Int32?
      return unless value.finite?
      floored = value.floor
      return if floored < Int32::MIN || floored > Int32::MAX
      floored.to_i32
    end

    # Convert pixel coordinates to 1-based char-cell coordinates.
    # Boundary pixels are nudged one step inward to match Julia's canvas mapping.
    private def pixel_to_char_point(pixel_x : Float64, pixel_y : Float64) : Tuple(Int32, Int32)?
      px = pixel_x >= @pixel_width ? pixel_x - 1.0 : pixel_x
      py = pixel_y >= @pixel_height ? pixel_y - 1.0 : pixel_y
      cx = floor_to_i32(px / x_pixel_per_char.to_f)
      cy = floor_to_i32(py / y_pixel_per_char.to_f)
      return unless cx && cy
      {cx + 1, cy + 1}
    end

    private def plot_pixel_if_visible(
      pixel_x : Float64,
      pixel_y : Float64,
      color : UInt32,
      blend : Bool,
      min_px : Float64,
      max_px : Float64,
      min_py : Float64,
      max_py : Float64,
    ) : Nil
      return unless pixel_x.finite? && pixel_y.finite?
      return if pixel_x < min_px || pixel_x > max_px
      return if pixel_y < min_py || pixel_y > max_py

      ix = floor_to_i32(pixel_x)
      pixel_y_i32 = floor_to_i32(pixel_y)
      return unless ix && pixel_y_i32

      pixel!(ix, pixel_y_i32, color, blend)
    end

    # Plot a single point (canvas coordinates)
    def points!(x : Float64, y : Float64, color : UInt32, blend : Bool) : self
      sx = scale_x_to_pixel(x)
      sy = scale_y_to_pixel(y)
      plot_pixel_if_visible(
        sx, sy, color, blend,
        0.0, @pixel_width.to_f,
        0.0, @pixel_height.to_f,
      )
      self
    end

    def points!(x : Float64, y : Float64, *, color : Symbol = :normal) : self
      c = UnicodePlot.ansi_color(color)
      points!(x, y, c, @blend)
    end

    # Plot a vector of points
    def points!(xs : Array(Float64), ys : Array(Float64), color : UInt32, blend : Bool) : self
      xs.each_with_index do |x, i|
        y = ys[i]
        next unless x.finite? && y.finite?
        points!(x, y, color, blend)
      end
      self
    end

    # Plot a vector of points with per-point colors
    def points!(xs : Array(Float64), ys : Array(Float64), colors : Array(UInt32), blend : Bool) : self
      unless xs.size == ys.size
        raise ArgumentError.new("xs and ys must have the same length")
      end

      unless xs.size == colors.size
        raise ArgumentError.new("colors must have the same length as xs and ys")
      end

      xs.each_with_index do |x, i|
        y = ys[i]
        next unless x.finite? && y.finite?
        points!(x, y, colors[i], blend)
      end
      self
    end

    # Liang-Barsky clipping in pixel coordinates, before rasterization.
    private def clip_line_to_pixels(x1 : Float64, y1 : Float64, x2 : Float64, y2 : Float64) : {Float64, Float64, Float64, Float64}?
      return unless x1.finite? && y1.finite? && x2.finite? && y2.finite?
      dx = x2 - x1
      dy = y2 - y1
      return unless dx.finite? && dy.finite?
      first = 0.0
      last = 1.0
      { {-dx, x1}, {dx, @pixel_width.to_f - x1}, {-dy, y1}, {dy, @pixel_height.to_f - y1} }.each do |p, q|
        if p == 0.0
          return if q < 0.0
        else
          t = q / p
          if p < 0.0
            first = Math.max(first, t)
          else
            last = Math.min(last, t)
          end
          return if first > last
        end
      end
      {x1 + first * dx, y1 + first * dy, x1 + last * dx, y1 + last * dy}
    end

    def lines!(
      x1 : Float64, y1 : Float64,
      x2 : Float64, y2 : Float64,
      color : UInt32,
      blend : Bool,
    ) : self
      clipped = clip_line_to_pixels(
        scale_x_to_pixel(x1), scale_y_to_pixel(y1),
        scale_x_to_pixel(x2), scale_y_to_pixel(y2))
      return self unless clipped
      sx, sy, ex, ey = clipped
      steps = Math.max((ex - sx).abs, (ey - sy).abs).ceil.to_i32
      if steps == 0
        plot_pixel_if_visible(sx, sy, color, blend, 0.0, @pixel_width.to_f, 0.0, @pixel_height.to_f)
      else
        (0..steps).each do |i|
          t = i.to_f / steps
          plot_pixel_if_visible(sx + (ex - sx) * t, sy + (ey - sy) * t,
            color, blend, 0.0, @pixel_width.to_f, 0.0, @pixel_height.to_f)
        end
      end
      self
    end

    def lines!(x1 : Float64, y1 : Float64, x2 : Float64, y2 : Float64, *, color : Symbol = :normal) : self
      c = UnicodePlot.ansi_color(color)
      lines!(x1, y1, x2, y2, c, @blend)
    end

    # Vector line drawing (polyline)
    def lines!(xs : Array(Float64), ys : Array(Float64), color : UInt32, blend : Bool) : self
      (1...xs.size).each do |i|
        x, y = xs[i], ys[i]
        xm1, ym1 = xs[i - 1], ys[i - 1]
        next unless x.finite? && y.finite? && xm1.finite? && ym1.finite?
        lines!(xm1, ym1, x, y, color, blend)
      end
      self
    end

    # Vector line drawing (polyline) with per-segment colors
    def lines!(xs : Array(Float64), ys : Array(Float64), segment_colors : Array(UInt32), blend : Bool) : self
      unless xs.size == ys.size
        raise ArgumentError.new("xs and ys must have the same length")
      end

      expected = xs.size > 0 ? xs.size - 1 : 0
      unless segment_colors.size == expected
        raise ArgumentError.new("segment_colors must have xs.size - 1 elements")
      end

      (1...xs.size).each do |i|
        x, y = xs[i], ys[i]
        xm1, ym1 = xs[i - 1], ys[i - 1]
        next unless x.finite? && y.finite? && xm1.finite? && ym1.finite?
        lines!(xm1, ym1, x, y, segment_colors[i - 1], blend)
      end
      self
    end

    # Annotate a character at canvas coords (x, y)
    def annotate!(x : Float64, y : Float64, char : Char, color : UInt32, blend : Bool) : self
      return self unless valid_x?(x) && valid_y?(y)
      point = pixel_to_char_point(scale_x_to_pixel(x), scale_y_to_pixel(y))
      return self unless point
      cx, cy = point
      char_point!(cx, cy, char, color, blend)
      self
    end

    def annotate!(x : Float64, y : Float64, text : String, color : UInt32, blend : Bool,
                  halign : Symbol = :center, valign : Symbol = :center) : self
      return self unless valid_x?(x) && valid_y?(y)
      px = scale_x_to_pixel(x)
      py = scale_y_to_pixel(y)
      point = pixel_to_char_point(px, py)
      return self unless point
      cx, cy = point
      n = text.size
      cx = case halign
           when :center, :hcenter then cx - n // 2
           when :left             then cx
           when :right            then cx - (n - 1)
           else                        cx
           end
      cy = case valign
           when :top    then cy + 1
           when :bottom then cy - 1
           else              cy
           end
      text.each_char.with_index do |chr, idx|
        char_point!(cx + idx, cy, chr, color, blend)
      end
      self
    end

    def char_point!(col : Int32, row : Int32, char : Char, color : UInt32, blend : Bool) : Nil
      return unless 1 <= row <= @nrows && 1 <= col <= @ncols
      grid_set!(row, col, char.ord.to_u32)
      set_color!(col, row, color, blend)
    end

    def print_row(io : IO, row : Int32, use_color : Bool) : Nil
      raise ArgumentError.new("`row` out of bounds: #{row}") unless 1 <= row <= @nrows
      (1..@ncols).each do |col|
        c = grid_char_at(row, col)
        color = color_at(row, col)
        UnicodePlot.print_color(io, color, c.to_s, use_color)
      end
    end

    # Map grid value to display character. Must be overridden by subclasses.
    abstract def grid_char_at(row : Int32, col : Int32) : Char
  end
end
