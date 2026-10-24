module UnicodePlot
  # Multi-stop colormap: each stop is {t, r, g, b} with t in [0,1].
  COLORMAP_STOPS = {
    :viridis => [
      {0.00, 68, 1, 84}, {0.25, 59, 82, 139},
      {0.50, 33, 145, 140}, {0.75, 94, 201, 98},
      {1.00, 253, 231, 37},
    ],
    :plasma => [
      {0.00, 13, 8, 135}, {0.25, 126, 3, 167},
      {0.50, 203, 71, 120}, {0.75, 248, 149, 64},
      {1.00, 240, 249, 33},
    ],
    :inferno => [
      {0.00, 0, 0, 4}, {0.25, 87, 16, 110},
      {0.50, 188, 55, 84}, {0.75, 249, 142, 9},
      {1.00, 252, 255, 164},
    ],
    :magma => [
      {0.00, 0, 0, 4}, {0.25, 81, 18, 124},
      {0.50, 183, 55, 121}, {0.75, 252, 137, 97},
      {1.00, 252, 253, 191},
    ],
    :cividis => [
      {0.00, 0, 32, 76}, {0.25, 50, 82, 130},
      {0.50, 119, 136, 138}, {0.75, 181, 188, 101},
      {1.00, 254, 233, 55},
    ],
    :gray => [
      {0.00, 0, 0, 0},
      {1.00, 255, 255, 255},
    ],
  }

  def colormap_callback(name : Symbol) : Proc(Float64, Float64, Float64, UInt32)
    stops = COLORMAP_STOPS[name]? || raise ArgumentError.new("unknown colormap: #{name}")
    ->(z : Float64, zmin : Float64, zmax : Float64) {
      return INVALID_COLOR unless z.finite?
      t = zmax > zmin ? ((z - zmin) / (zmax - zmin)).clamp(0.0, 1.0) : 0.5
      i = 0
      while i < stops.size - 2 && stops[i + 1][0] <= t
        i += 1
      end
      s0 = stops[i]
      s1 = stops[i + 1]
      alpha = s1[0] > s0[0] ? (t - s0[0]) / (s1[0] - s0[0]) : 0.0
      r = (s0[1] + alpha * (s1[1] - s0[1])).round.to_i32
      g = (s0[2] + alpha * (s1[2] - s0[2])).round.to_i32
      b = (s0[3] + alpha * (s1[3] - s0[3])).round.to_i32
      UnicodePlot.ansi_color(r, g, b)
    }
  end

  # HeatmapGraphics renders a 2D color matrix using half-block characters (▄).
  # Each display row combines two data rows: upper half (bg) and lower half (fg).
  # This matches Julia's HeatmapCanvas layout.
  class HeatmapGraphics < GraphicsArea
    getter nrows : Int32
    getter ncols : Int32
    getter? visible : Bool
    getter data : Array(Array(Float64))
    getter colormap_fn : Proc(Float64, Float64, Float64, UInt32)
    getter zmin : Float64
    getter zmax : Float64
    getter? yflip : Bool

    def initialize(
      @data : Array(Array(Float64)),
      @colormap_fn : Proc(Float64, Float64, Float64, UInt32),
      @zmin : Float64,
      @zmax : Float64,
      @visible : Bool = true,
      @yflip : Bool = false,
    )
      char_height = data.size # = data_nrows; each display row uses 2 data rows
      data_ncols = data.empty? ? 0 : data[0].size
      # nrows(c::HeatmapCanvas) = div(char_height + 1, 2) in Julia
      @nrows = char_height == 0 ? 0 : (char_height + 1) // 2
      @ncols = data_ncols
    end

    def blank : Char
      ' '
    end

    # Render one display row using two data rows packed as half-block characters.
    # Row 1 = topmost display row. Each display row uses pixel rows 2r-1 and 2r
    # (adjusted for odd char_height), matching Julia's HeatmapCanvas.print_row.
    def print_row(io : IO, row : Int32, use_color : Bool) : Nil # ameba:disable Metrics/CyclomaticComplexity
      char_height = @data.size
      return if char_height == 0

      # Julia: row *= y_pixel_per_char; isodd(grid_size) && (row -= 1)
      pixel_row = row * 2
      pixel_row -= 1 if char_height.odd?

      # Map Julia pixel index p (1-indexed from top) to Crystal data index (0-indexed):
      # Normal mode (yflip=false): data[0]=bottom, data[char_height-1]=top
      #   colors[p] = data[char_height - p]
      # Array mode (yflip=true): data[0]=top, data[char_height-1]=bottom
      #   colors[p] = data[p - 1]
      lower_p = pixel_row     # fg (lower half of ▄)
      upper_p = pixel_row - 1 # bg (upper half of ▄), 0 = no upper color

      if @yflip
        lower_idx = lower_p - 1
        upper_idx = upper_p > 0 ? upper_p - 1 : -1
      else
        lower_idx = char_height - lower_p
        upper_idx = upper_p > 0 ? char_height - upper_p : -1
      end

      (0...@ncols).each do |col|
        lower_row = (lower_idx >= 0 && lower_idx < char_height) ? @data[lower_idx]? : nil
        upper_row = (upper_idx >= 0 && upper_idx < char_height) ? @data[upper_idx]? : nil
        lower_val = lower_row ? lower_row[col]? : nil
        upper_val = upper_row ? upper_row[col]? : nil

        fg = lower_val ? @colormap_fn.call(lower_val, @zmin, @zmax) : INVALID_COLOR
        bg = upper_val ? @colormap_fn.call(upper_val, @zmin, @zmax) : INVALID_COLOR

        if use_color
          if fg != INVALID_COLOR && bg != INVALID_COLOR
            io << UnicodePlot.ansi_fg_escape(fg)
            io << UnicodePlot.ansi_bg_escape(bg)
            io << HALF_BLOCK << ANSI_RESET
          elsif fg != INVALID_COLOR
            io << UnicodePlot.ansi_fg_escape(fg) << HALF_BLOCK << ANSI_RESET
          elsif bg != INVALID_COLOR
            io << UnicodePlot.ansi_fg_escape(bg) << '▀' << ANSI_RESET
          else
            io << ' '
          end
        else
          io << (fg == INVALID_COLOR && bg == INVALID_COLOR ? ' ' :
            fg == INVALID_COLOR ? '▀' : HALF_BLOCK)
        end
      end
    end
  end
end
