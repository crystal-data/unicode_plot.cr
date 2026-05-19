module UnicodePlot
  def barplot(
    text : Array(String),
    heights : Array(Float64),
    *,
    color : Symbol | Int32 | {Int32, Int32, Int32} | Array(Symbol) | Array(Int32) | Array(UInt32) | UInt32 = :green,
    width : Int32? = nil,
    xscale : Symbol | Proc(Float64, Float64) = :identity,
    name : String = "",
    symbols : Array(Char) = ['■'],
    maximum : Float64? = nil,
    xlabel : String = "",
    border : Symbol = :barplot,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    compact_labels : Bool = false,
    compact : Bool = false,
    title : String = "",
    integer_labels : Bool = false,
  ) : Plot
    raise ArgumentError.new("text and heights must have the same length") unless text.size == heights.size
    raise ArgumentError.new("all values must be >= 0") unless heights.all? { |val| val >= 0 }

    # Handle multi-line labels with negative placeholder heights
    final_text = [] of String
    final_heights = [] of Float64
    text.each_with_index do |label, i|
      if label.includes?('\n')
        lines = label.split('\n')
        lines.each_with_index do |line, j|
          final_text << line
          final_heights << (j == lines.size - 1 ? heights[i] : -1.0)
        end
      else
        final_text << label
        final_heights << heights[i]
      end
    end

    char_width = width || default_width
    fmt = if integer_labels
            ->(x : Float64) { nice_repr(x.round.to_i64, unicode_exponent, thousands_separator) }
          else
            ->(x : Float64) { bar_float_label(x, unicode_exponent, thousands_separator) }
          end
    area = BarplotGraphics.new(
      final_heights, char_width,
      symbols: symbols, color: color, maximum: maximum,
      formatter: fmt, xscale: xscale
    )

    xlab = xlabel.empty? ? transform_name(xscale, xlabel) : xlabel
    plot = Plot.new(area,
      border: border, title: title, xlabel: xlab,
      margin: margin, padding: padding,
      labels: labels, compact_labels: compact_labels, compact: compact,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator)

    unless name.empty?
      plot.label!(:r, name, suitable_color(area, color))
    end

    final_text.each_with_index do |label, i|
      plot.label!(:l, i + 1, label)
    end

    plot
  end

  def barplot(text : Array(String), heights : Array(Int), **kwargs) : Plot
    barplot_integer(text, heights, **kwargs)
  end

  def barplot(text : Array(String), heights : Array(Number), **kwargs) : Plot
    barplot(text, heights.map(&.to_f), **kwargs)
  end

  def barplot(dict : Hash(String, Float64), **kwargs) : Plot
    pairs = dict.to_a.sort_by { |k, _| k }
    barplot(pairs.map { |k, _| k }, pairs.map { |_, v| v }, **kwargs)
  end

  def barplot(dict : Hash(String, T), **kwargs) : Plot forall T
    pairs = dict.to_a.sort_by { |k, _| k }
    barplot(pairs.map { |k, _| k }, pairs.map { |_, v| v }, **kwargs)
  end

  def barplot!(
    plot : Plot,
    text : Array(String),
    heights : Array(Float64),
    *,
    color : (Symbol | Int32 | UInt32 | {Int32, Int32, Int32})? = nil,
    name : String = "",
  ) : Plot
    raise ArgumentError.new("text and heights must have the same length") unless text.size == heights.size
    raise ArgumentError.new("cannot append empty array to barplot") if text.empty?
    area = plot.graphics.as(BarplotGraphics)
    cur_idx = area.nrows
    area.add_row!(heights, color)
    text.each_with_index do |label, i|
      plot.label!(:l, cur_idx + i + 1, label)
    end
    plot.label!(:r, name, suitable_color(area, color)) unless name.empty?
    plot
  end

  def barplot!(plot : Plot, text : Array(String), heights : Array(Int), **kwargs) : Plot
    barplot!(plot, text, heights.map(&.to_f), **kwargs)
  end

  def barplot!(plot : Plot, text : Array(String), heights : Array(Number), **kwargs) : Plot
    barplot!(plot, text, heights.map(&.to_f), **kwargs)
  end

  def barplot!(plot : Plot, label : String, height : Float64, **kwargs) : Plot
    barplot!(plot, [label], [height], **kwargs)
  end

  def barplot!(plot : Plot, label : String, height : Number, **kwargs) : Plot
    barplot!(plot, [label], [height.to_f], **kwargs)
  end

  private def barplot_integer(text : Array(String), heights : Array(T), **kwargs) : Plot forall T
    barplot(text, heights.map(&.to_f), **kwargs, integer_labels: true)
  end

  private def bar_float_label(value : Float64, unicode_exponent : Bool, thousands_separator : Char) : String
    if value.finite? && value == value.round
      "#{nice_repr(value.round.to_i64, unicode_exponent, thousands_separator)}.0"
    else
      nice_repr(value, unicode_exponent, thousands_separator)
    end
  end

  # Get a representative color from a BarplotGraphics for legend labeling
  private def suitable_color(area : BarplotGraphics, color : Array(Symbol)) : UInt32
    color.empty? ? INVALID_COLOR : ansi_color(color.first)
  end

  private def suitable_color(area : BarplotGraphics, color : Array(Int32)) : UInt32
    color.empty? ? INVALID_COLOR : ansi_color(color.first)
  end

  private def suitable_color(area : BarplotGraphics, color : Array(UInt32)) : UInt32
    color.first? || INVALID_COLOR
  end

  private def suitable_color(area : BarplotGraphics, color : Symbol) : UInt32
    plot_color(color)
  end

  private def suitable_color(area : BarplotGraphics, color : Int32) : UInt32
    ansi_color(color)
  end

  private def suitable_color(area : BarplotGraphics, color : Tuple(Int32, Int32, Int32)) : UInt32
    plot_color(color)
  end

  private def suitable_color(area : BarplotGraphics, color : UInt32) : UInt32
    plot_color(color)
  end

  private def suitable_color(area : BarplotGraphics, color : Nil) : UInt32
    area.colors.last? || INVALID_COLOR
  end
end
