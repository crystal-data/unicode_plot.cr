module UnicodePlot
  class BarplotGraphics < GraphicsArea
    getter bars : Array(Float64)
    getter spacer_rows : Array(Bool)
    getter colors : Array(UInt32)
    getter ncols : Int32 # char width
    getter? visible : Bool
    getter maximum : Float64
    getter symbols : Array(Char)
    getter formatter : Proc(Float64, String)
    getter xscale : Proc(Float64, Float64)

    # Computed per-render (set in preprocess, cleared in cleanup)
    property max_val : Float64 = -Float64::INFINITY
    property max_len : Int32 = 0

    def initialize(
      bars : Array(Float64),
      char_width : Int32,
      *,
      symbols : Array(Char) = ['■'],
      color : Symbol | Int32 | {Int32, Int32, Int32} | Array(Symbol) | Array(Int32) | Array(UInt32) | UInt32 = :green,
      maximum : Float64? = nil,
      formatter : Proc(Float64, String)? = nil,
      spacer_rows : Array(Bool)? = nil,
      visible : Bool = true,
      xscale : Symbol | Proc(Float64, Float64) = :identity,
    )
      @bars = bars.dup
      @spacer_rows = spacer_rows || Array.new(bars.size, false)
      raise ArgumentError.new("spacer_rows must match bars") unless @spacer_rows.size == bars.size
      @visible = visible
      @symbols = symbols
      @formatter = formatter || ->(x : Float64) { UnicodePlot.nice_repr(x) }
      @xscale = xscale.is_a?(Symbol) ? UnicodePlot.scale_callback(xscale.as(Symbol)) : xscale.as(Proc(Float64, Float64))
      @maximum = maximum || -Float64::INFINITY

      # Compute minimum needed width
      max_val_str_len = bars.each_with_index.max_of? { |bar, i| @spacer_rows[i] ? 0 : @formatter.call(bar).size } || 1
      @ncols = Math.max(10, Math.max(char_width, max_val_str_len + 7))

      @colors = resolve_colors(color, bars.size)
      raise ArgumentError.new("colors must match bars") unless @colors.size == bars.size
    end

    private def resolve_colors(color : Array(Symbol), size : Int32) : Array(UInt32)
      color.map { |col| UnicodePlot.ansi_color(col) }
    end

    private def resolve_colors(color : Array(Int32), size : Int32) : Array(UInt32)
      color.map { |col| UnicodePlot.ansi_color(col) }
    end

    private def resolve_colors(color : Array(UInt32), size : Int32) : Array(UInt32)
      color
    end

    private def resolve_colors(color : Symbol, size : Int32) : Array(UInt32)
      Array.new(size, UnicodePlot.ansi_color(color))
    end

    private def resolve_colors(color : Int32, size : Int32) : Array(UInt32)
      Array.new(size, UnicodePlot.ansi_color(color))
    end

    private def resolve_colors(color : Tuple(Int32, Int32, Int32), size : Int32) : Array(UInt32)
      Array.new(size, UnicodePlot.ansi_color(color))
    end

    private def resolve_colors(color : UInt32, size : Int32) : Array(UInt32)
      Array.new(size, color)
    end

    def nrows : Int32
      @bars.size
    end

    def blank : Char
      ' '
    end

    def preprocess(io : IO) : GraphicsArea ->
      if @bars.empty?
        @max_val = Math.max(0.0, @maximum)
        @max_len = 0
        return ->(grph : GraphicsArea) {
          bg = grph.as(BarplotGraphics)
          bg.max_val = -Float64::INFINITY
          bg.max_len = 0
        }
      end
      real_bars = @bars.each_with_index.compact_map { |bar, i| bar unless @spacer_rows[i] }.to_a
      if real_bars.empty?
        @max_val = Math.max(0.0, @maximum)
        @max_len = 0
        return ->(grph : GraphicsArea) {
          bg = grph.as(BarplotGraphics)
          bg.max_val = -Float64::INFINITY
          bg.max_len = 0
        }
      end
      scaled = real_bars.map { |bar| @xscale.call(bar) }
      @max_val = Math.max(scaled.max, @maximum)
      @max_len = real_bars.max_of { |bar| @formatter.call(bar).size }
      ->(grph : GraphicsArea) {
        bg = grph.as(BarplotGraphics)
        bg.max_val = -Float64::INFINITY
        bg.max_len = 0
      }
    end

    def print_row(io : IO, row : Int32, use_color : Bool) : Nil
      raise ArgumentError.new("`row` out of bounds: #{row}") unless 1 <= row <= nrows
      idx = row - 1
      if @spacer_rows[idx]
        io << " " * @ncols
        return
      end
      bar = @bars[idx]
      val = @xscale.call(bar)
      nsyms = @symbols.size
      frac = @max_val > 0 ? Math.max(val, 0.0) / @max_val : 0.0
      max_bar_width = Math.max(@ncols - 2 - @max_len, 1)
      bar_head = if nsyms > 1
                   (frac * max_bar_width).floor.to_i32
                 else
                   (frac * max_bar_width).round(mode: :ties_away).to_i32
                 end
      color = @colors[idx]
      UnicodePlot.print_color(io, color, @symbols[nsyms - 1].to_s * bar_head, use_color)
      if nsyms > 1
        frac_cells = frac * max_bar_width - bar_head
        rem = frac_cells * (nsyms - 2)
        sub_char = if rem <= 0
                     ' '
                   else
                     ri = rem.round.to_i32
                     @symbols[ri.clamp(0, nsyms - 2)]
                   end
        UnicodePlot.print_color(io, color, sub_char.to_s, use_color)
        bar_head += 1
      end
      bar_lbl = bar >= 0 ? @formatter.call(bar) : ""
      len = if bar >= 0
              UnicodePlot.print_color(io, INVALID_COLOR, " #{bar_lbl}", use_color)
              bar_lbl.size
            else
              -1
            end
      pad_len = Math.max(max_bar_width + 1 + @max_len - bar_head - len, 0)
      io << " " * pad_len
    end

    def add_row!(bars : Array(Float64), color : (Symbol | Int32 | UInt32 | {Int32, Int32, Int32})? = nil,
                 spacer_rows : Array(Bool)? = nil) : self
      new_spacers = spacer_rows || Array.new(bars.size, false)
      raise ArgumentError.new("spacer_rows must match bars") unless new_spacers.size == bars.size
      @bars.concat(bars)
      @spacer_rows.concat(new_spacers)
      new_colors = append_colors(bars.size, color)
      @colors.concat(new_colors)
      @ncols = Math.max(@ncols, @bars.each_with_index.max_of { |bar, i| @spacer_rows[i] ? 0 : @formatter.call(bar).size } + 7)
      self
    end

    def add_row!(bar : Float64, color : (Symbol | Int32 | UInt32 | {Int32, Int32, Int32})? = nil) : self
      add_row!([bar], color)
    end

    private def append_colors(size : Int32, color : Nil) : Array(UInt32)
      Array.new(size, @colors.last? || UnicodePlot.ansi_color(:green))
    end

    private def append_colors(size : Int32, color : Symbol) : Array(UInt32)
      Array.new(size, UnicodePlot.ansi_color(color))
    end

    private def append_colors(size : Int32, color : Int32) : Array(UInt32)
      Array.new(size, UnicodePlot.ansi_color(color))
    end

    private def append_colors(size : Int32, color : Tuple(Int32, Int32, Int32)) : Array(UInt32)
      Array.new(size, UnicodePlot.ansi_color(color))
    end

    private def append_colors(size : Int32, color : UInt32) : Array(UInt32)
      Array.new(size, color)
    end
  end
end
