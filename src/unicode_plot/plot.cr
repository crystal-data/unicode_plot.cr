module UnicodePlot
  class Colormap
    property border : Symbol
    property? bar : Bool
    property lim : {Float64, Float64}
    property callback : Proc(Float64, Float64, Float64, UInt32)

    def initialize(@border, @bar, @lim, @callback)
    end
  end

  class Plot
    getter graphics : GraphicsArea
    property autocolor : Int32
    property series : Int32
    property title : String
    property xlabel : String
    property ylabel : String
    property zlabel : String
    property margin : Int32
    property padding : Int32
    property? unicode_exponent : Bool
    property thousands_separator : Char
    property border : Symbol
    property? compact_labels : Bool
    property? compact : Bool
    property? labels : Bool
    getter labels_left : Hash(Int32, String)
    getter labels_right : Hash(Int32, String)
    getter colors_left : Hash(Int32, UInt32)
    getter colors_right : Hash(Int32, UInt32)
    getter decorations : Hash(Symbol, String)
    getter colors_deco : Hash(Symbol, UInt32)
    getter colormap : Colormap
    property raw_xlim : {Float64, Float64}? = nil
    property raw_ylim : {Float64, Float64}? = nil

    def initialize(
      @graphics : GraphicsArea,
      *,
      title : String = "",
      xlabel : String = "",
      ylabel : String = "",
      zlabel : String = "",
      unicode_exponent : Bool = true,
      thousands_separator : Char = ' ',
      border : Symbol = :solid,
      compact_labels : Bool = false,
      compact : Bool = false,
      margin : Int32 = 3,
      padding : Int32 = 1,
      labels : Bool = true,
      colorbar : Bool = false,
      colorbar_border : Symbol = :solid,
      colorbar_lim : {Float64, Float64} = {0.0, 1.0},
      colormap_callback : Proc(Float64, Float64, Float64, UInt32)? = nil,
    )
      @autocolor = 0
      @series = 0
      @title = title
      @xlabel = xlabel
      @ylabel = ylabel
      @zlabel = zlabel
      @unicode_exponent = unicode_exponent
      @thousands_separator = thousands_separator
      @border = border
      @compact_labels = compact_labels
      @compact = compact
      @margin = margin
      @padding = padding
      @labels = labels && @graphics.visible?
      @labels_left = Hash(Int32, String).new
      @labels_right = Hash(Int32, String).new
      @colors_left = Hash(Int32, UInt32).new
      @colors_right = Hash(Int32, UInt32).new
      @decorations = Hash(Symbol, String).new
      @colors_deco = Hash(Symbol, UInt32).new
      cb = colormap_callback || ->(_z : Float64, _zmin : Float64, _zmax : Float64) { INVALID_COLOR }
      @colormap = Colormap.new(colorbar_border, colorbar, colorbar_lim, cb)
      if compact
        @margin = 0
        @padding = 0
        @compact_labels = true
      end
    end

    def next_color! : Symbol
      cycle = UnicodePlot.color_cycle
      idx = @autocolor % cycle.size
      color = cycle[idx]
      @autocolor = idx + 1
      color
    end

    def nice_repr(x : Number) : String
      UnicodePlot.nice_repr(x.to_f, @unicode_exponent, @thousands_separator)
    end

    # Canvas accessor (raises if graphics is not a Canvas)
    def canvas : Canvas
      @graphics.as(Canvas)
    end

    # --- label! ---

    def label!(loc : Symbol, value : String, color : UInt32 = INVALID_COLOR) : self
      valid_locs = {:t, :b, :l, :r, :tl, :tr, :bl, :br}
      raise ArgumentError.new("unknown location #{loc}") unless valid_locs.includes?(loc)
      if loc == :l || loc == :r
        (1..nrows).each do |row|
          if loc == :l
            if !@labels_left[row]? || @labels_left[row].empty?
              @labels_left[row] = value
              @colors_left[row] = color
              break
            end
          else
            if !@labels_right[row]? || @labels_right[row].empty?
              @labels_right[row] = value
              @colors_right[row] = color
              break
            end
          end
        end
      else
        @decorations[loc] = value
        @colors_deco[loc] = color
      end
      self
    end

    def label!(loc : Symbol, value : String, color : Symbol) : self
      label!(loc, value, UnicodePlot.ansi_color(color))
    end

    def label!(loc : Symbol, row : Int32, value : String, color : UInt32 = INVALID_COLOR) : self
      case loc
      when :l
        @labels_left[row] = value
        @colors_left[row] = color
      when :r
        @labels_right[row] = value
        @colors_right[row] = color
      else
        raise ArgumentError.new("unknown location #{loc}, try :l or :r")
      end
      self
    end

    def label!(loc : Symbol, row : Int32, value : String, color : Symbol) : self
      label!(loc, row, value, UnicodePlot.ansi_color(color))
    end

    def nrows : Int32
      @graphics.nrows
    end

    def ncols : Int32
      @graphics.ncols
    end

    # lines!, points!, pixel! delegates to the canvas
    def lines!(x1 : Float64, y1 : Float64, x2 : Float64, y2 : Float64, *, color : Symbol = :normal) : self
      canvas.lines!(x1, y1, x2, y2, color: color)
      self
    end

    def lines!(x1 : Float64, y1 : Float64, x2 : Float64, y2 : Float64, color : UInt32, blend : Bool) : self
      canvas.lines!(x1, y1, x2, y2, color, blend)
      self
    end

    def lines!(xs : Array(Float64), ys : Array(Float64), color : UInt32, blend : Bool) : self
      canvas.lines!(xs, ys, color, blend)
      self
    end

    def lines!(xs : Array(Float64), ys : Array(Float64), segment_colors : Array(UInt32), blend : Bool) : self
      canvas.lines!(xs, ys, segment_colors, blend)
      self
    end

    def points!(xs : Array(Float64), ys : Array(Float64), color : UInt32, blend : Bool) : self
      canvas.points!(xs, ys, color, blend)
      self
    end

    def points!(xs : Array(Float64), ys : Array(Float64), colors : Array(UInt32), blend : Bool) : self
      canvas.points!(xs, ys, colors, blend)
      self
    end

    def annotate!(x : Float64, y : Float64, char : Char, color : UInt32, blend : Bool) : self
      canvas.annotate!(x, y, char, color, blend)
      self
    end

    def annotate!(x : Float64, y : Float64, text : String, color : UInt32, blend : Bool, **kw) : self
      canvas.annotate!(x, y, text, color, blend)
      self
    end

    def to_s(io : IO) : Nil
      UnicodePlot.show_plot(io, self)
    end
  end

  private def raw_axis_limits(values : Array(Float64), requested : {Float64, Float64},
                              scale : Symbol | Proc(Float64, Float64),
                              transformed : {Float64, Float64}) : {Float64, Float64}
    return requested unless requested == {0.0, 0.0}
    if scale.is_a?(Symbol)
      if inverse = ISCALES[scale]?
        lower = inverse.call(transformed[0])
        upper = inverse.call(transformed[1])
        return {lower, upper} if lower.finite? && upper.finite? && lower < upper
      end
    end
    finite = values.select(&.finite?)
    return {-1.0, 1.0} if finite.empty?
    lower, upper = finite.min, finite.max
    lower == upper ? expand_equal_limits(lower) : {lower, upper}
  end

  # Create a Plot from x/y data, building the canvas automatically.
  # ameba:disable Metrics/CyclomaticComplexity
  def build_plot(
    x : Array(Float64),
    y : Array(Float64),
    *,
    canvas_type : Symbol = :braille,
    title : String = "",
    xlabel : String = "",
    ylabel : String = "",
    xscale : Symbol | Proc(Float64, Float64) = :identity,
    yscale : Symbol | Proc(Float64, Float64) = :identity,
    height : Int32? = nil,
    width : Int32? = nil,
    border : Symbol = :solid,
    compact_labels : Bool = false,
    compact : Bool = false,
    blend : Bool = true,
    xlim : {Float64, Float64} = {0.0, 0.0},
    ylim : {Float64, Float64} = {0.0, 0.0},
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    grid : Bool = true,
    yticks : Bool = true,
    xticks : Bool = true,
    min_height : Int32 = 2,
    min_width : Int32 = 5,
    yflip : Bool = false,
    xflip : Bool = false,
    colorbar : Bool = false,
    colorbar_border : Symbol = :solid,
    colorbar_lim : {Float64, Float64} = {0.0, 1.0},
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
  ) : Plot
    mx, bx = extend_limits(x, xlim, xscale)
    my, by = extend_limits(y, ylim, yscale)
    raw_xmin, raw_xmax = raw_axis_limits(x, xlim, xscale, {mx, bx})
    raw_ymin, raw_ymax = raw_axis_limits(y, ylim, yscale, {my, by})

    h = (height || default_height).clamp(min_height, Int32::MAX)
    w = (width || default_width).clamp(min_width, Int32::MAX)

    can = case canvas_type
          when :braille then BrailleCanvas.new(h, w,
            origin_y: my, origin_x: mx,
            height: by - my, width: bx - mx,
            blend: blend, visible: (w >= 0),
            yflip: yflip, xflip: xflip,
            yscale: yscale.is_a?(Symbol) ? yscale.as(Symbol) : yscale.as(Proc(Float64, Float64)),
            xscale: xscale.is_a?(Symbol) ? xscale.as(Symbol) : xscale.as(Proc(Float64, Float64)))
          when :block then BlockCanvas.new(h, w,
            origin_y: my, origin_x: mx,
            height: by - my, width: bx - mx,
            blend: blend, visible: (w >= 0),
            yflip: yflip, xflip: xflip,
            yscale: yscale.is_a?(Symbol) ? yscale.as(Symbol) : yscale.as(Proc(Float64, Float64)),
            xscale: xscale.is_a?(Symbol) ? xscale.as(Symbol) : xscale.as(Proc(Float64, Float64)))
          when :ascii then AsciiCanvas.new(h, w,
            origin_y: my, origin_x: mx,
            height: by - my, width: bx - mx,
            blend: blend, visible: (w >= 0),
            yflip: yflip, xflip: xflip,
            yscale: yscale.is_a?(Symbol) ? yscale.as(Symbol) : yscale.as(Proc(Float64, Float64)),
            xscale: xscale.is_a?(Symbol) ? xscale.as(Symbol) : xscale.as(Proc(Float64, Float64)))
          when :dot then DotCanvas.new(h, w,
            origin_y: my, origin_x: mx,
            height: by - my, width: bx - mx,
            blend: blend, visible: (w >= 0),
            yflip: yflip, xflip: xflip,
            yscale: yscale.is_a?(Symbol) ? yscale.as(Symbol) : yscale.as(Proc(Float64, Float64)),
            xscale: xscale.is_a?(Symbol) ? xscale.as(Symbol) : xscale.as(Proc(Float64, Float64)))
          when :density then DensityCanvas.new(h, w,
            origin_y: my, origin_x: mx,
            height: by - my, width: bx - mx,
            blend: blend, visible: (w >= 0),
            yflip: yflip, xflip: xflip,
            yscale: yscale, xscale: xscale)
          else
            raise ArgumentError.new("unknown canvas: #{canvas_type}")
          end

    plot = Plot.new(can,
      title: title, xlabel: xlabel, ylabel: ylabel,
      margin: margin, padding: padding,
      border: border, compact_labels: compact_labels, compact: compact,
      labels: labels, colorbar: colorbar, colorbar_border: colorbar_border,
      colorbar_lim: colorbar_lim, unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator)
    plot.raw_xlim = {raw_xmin, raw_xmax}
    plot.raw_ylim = {raw_ymin, raw_ymax}

    bc = ansi_color(border_color)
    if xticks
      m_x = nice_repr(mx, unicode_exponent, thousands_separator)
      b_x = nice_repr(bx, unicode_exponent, thousands_separator)
      base_x = xscale.is_a?(Symbol) ? BASES[xscale.as(Symbol)]? : nil
      if base_x
        pfx = base_x + (unicode_exponent ? "" : "^")
        m_x = pfx + (unicode_exponent ? superscript(m_x) : m_x)
        b_x = pfx + (unicode_exponent ? superscript(b_x) : b_x)
      end
      plot.label!(:bl, xflip ? b_x : m_x, bc)
      plot.label!(:br, xflip ? m_x : b_x, bc)
    end
    if yticks
      m_y = nice_repr(my, unicode_exponent, thousands_separator)
      b_y = nice_repr(by, unicode_exponent, thousands_separator)
      base_y = yscale.is_a?(Symbol) ? BASES[yscale.as(Symbol)]? : nil
      if base_y
        pfx = base_y + (unicode_exponent ? "" : "^")
        m_y = pfx + (unicode_exponent ? superscript(m_y) : m_y)
        b_y = pfx + (unicode_exponent ? superscript(b_y) : b_y)
      end
      plot.label!(:l, can.nrows, yflip ? b_y : m_y, bc)
      plot.label!(:l, 1, yflip ? m_y : b_y, bc)
    end

    if grid
      if raw_ymin < 0.0 && raw_ymax > 0.0
        can.lines!(raw_xmin, 0.0, raw_xmax, 0.0, ansi_color(border_color), true)
      end
      if raw_xmin < 0.0 && raw_xmax > 0.0
        can.lines!(0.0, raw_ymin, 0.0, raw_ymax, ansi_color(border_color), true)
      end
    end

    plot
  end
end
