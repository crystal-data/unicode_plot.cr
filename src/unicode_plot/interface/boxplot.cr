module UnicodePlot
  private def resolve_box_colors(color : Array(Symbol), n : Int32) : Array(UInt32)
    color.map { |sym| ansi_color(sym) }
  end

  private def resolve_box_colors(color : Array(UInt32), n : Int32) : Array(UInt32)
    color
  end

  private def resolve_box_colors(color : Symbol, n : Int32) : Array(UInt32)
    if color == :auto
      (0...n).map { |i| ansi_color(color_cycle[i % color_cycle.size]) }
    else
      Array.new(n, ansi_color(color))
    end
  end

  private def resolve_box_colors(color : Tuple(Int32, Int32, Int32), n : Int32) : Array(UInt32)
    Array.new(n, ansi_color(color))
  end

  private def resolve_box_colors(color : UInt32, n : Int32) : Array(UInt32)
    Array.new(n, color)
  end

  private def boxplot_build(
    area : BoxplotGraphics,
    *,
    title : String,
    xlabel : String,
    border : Symbol,
    margin : Int32,
    padding : Int32,
    labels : Bool,
    unicode_exponent : Bool,
    thousands_separator : Char,
    compact_labels : Bool,
    compact : Bool,
  ) : Plot
    plot = Plot.new(area,
      border: border, title: title, xlabel: xlabel,
      margin: margin, padding: padding,
      labels: labels, compact_labels: compact_labels, compact: compact,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator)
    bc = ansi_color(border_color)
    fmt = ->(v : Float64) { nice_repr(v, unicode_exponent, thousands_separator) }
    plot.label!(:bl, fmt.call(area.xmin), bc)
    plot.label!(:b, fmt.call((area.xmin + area.xmax) / 2.0), bc)
    plot.label!(:br, fmt.call(area.xmax), bc)
    plot
  end

  def boxplot(
    names : Array(String),
    data : Array(Array(Float64)),
    *,
    color : Symbol | UInt32 | {Int32, Int32, Int32} | Array(Symbol) | Array(UInt32) = :green,
    title : String = "",
    xlabel : String = "",
    xlim : {Float64, Float64} = {0.0, 0.0},
    border : Symbol = :corners,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    compact_labels : Bool = false,
    compact : Bool = false,
    width : Int32? = nil,
  ) : Plot
    boxplot(data, names: names,
      color: color, title: title, xlabel: xlabel, xlim: xlim,
      border: border, margin: margin, padding: padding, labels: labels,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
      compact_labels: compact_labels, compact: compact, width: width)
  end

  def boxplot(
    names : Array(String),
    data : Array(Array(T)),
    **kwargs,
  ) : Plot forall T
    boxplot(names, data.map { |series| to_plot_f64(series) }, **kwargs)
  end

  def boxplot(
    data : Array(Array(Float64)),
    *,
    names : Array(String) = [] of String,
    color : Symbol | UInt32 | {Int32, Int32, Int32} | Array(Symbol) | Array(UInt32) = :green,
    title : String = "",
    xlabel : String = "",
    xlim : {Float64, Float64} = {0.0, 0.0},
    border : Symbol = :corners,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    compact_labels : Bool = false,
    compact : Bool = false,
    width : Int32? = nil,
  ) : Plot
    raise ArgumentError.new("data is empty") if data.empty?

    if xlim != {0.0, 0.0}
      xmin, xmax = xlim
    else
      all_vals = data.flatten
      xmin, xmax = extend_limits(all_vals, {0.0, 0.0})
    end
    char_width = width || default_width
    area = BoxplotGraphics.new(char_width, xmin, xmax)

    colors = resolve_box_colors(color, data.size)
    data.each_with_index { |box, i| area.add_box!(box, colors[i]) }

    plot = boxplot_build(area,
      title: title, xlabel: xlabel, border: border,
      margin: margin, padding: padding, labels: labels,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
      compact_labels: compact_labels, compact: compact)

    # Middle row of box i (0-based) = 3*i + 2 (1-based)
    names.each_with_index { |box_name, i| plot.label!(:l, 3 * i + 2, box_name) unless box_name.empty? }
    plot
  end

  def boxplot(data : Array(Array(T)), **kwargs) : Plot forall T
    boxplot(data.map { |series| to_plot_f64(series) }, **kwargs)
  end

  def boxplot(
    data : Array(Float64),
    *,
    name : String = "",
    color : Symbol | UInt32 | {Int32, Int32, Int32} = :green,
    title : String = "",
    xlabel : String = "",
    xlim : {Float64, Float64} = {0.0, 0.0},
    border : Symbol = :corners,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    compact_labels : Bool = false,
    compact : Bool = false,
    width : Int32? = nil,
  ) : Plot
    raise ArgumentError.new("data is empty") if data.empty?

    if xlim != {0.0, 0.0}
      xmin, xmax = xlim
    else
      xmin, xmax = extend_limits(data, {0.0, 0.0})
    end
    char_width = width || default_width
    area = BoxplotGraphics.new(char_width, xmin, xmax)

    col = plot_color(color)
    area.add_box!(data, col)

    plot = boxplot_build(area,
      title: title, xlabel: xlabel, border: border,
      margin: margin, padding: padding, labels: labels,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
      compact_labels: compact_labels, compact: compact)

    plot.label!(:l, 2, name) unless name.empty?
    plot
  end

  def boxplot(
    name : String,
    data : Array(Float64),
    *,
    color : Symbol | UInt32 | {Int32, Int32, Int32} = :green,
    title : String = "",
    xlabel : String = "",
    xlim : {Float64, Float64} = {0.0, 0.0},
    border : Symbol = :corners,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    compact_labels : Bool = false,
    compact : Bool = false,
    width : Int32? = nil,
  ) : Plot
    boxplot(data, name: name,
      color: color, title: title, xlabel: xlabel, xlim: xlim,
      border: border, margin: margin, padding: padding, labels: labels,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
      compact_labels: compact_labels, compact: compact, width: width)
  end

  def boxplot(
    name : String,
    data : Array(T),
    **kwargs,
  ) : Plot forall T
    boxplot(name, to_plot_f64(data), **kwargs)
  end

  def boxplot(
    data : Array(T),
    **kwargs,
  ) : Plot forall T
    boxplot(to_plot_f64(data), **kwargs)
  end

  def boxplot(
    dict : Hash(String, Array(Float64)),
    *,
    color : Symbol | UInt32 | {Int32, Int32, Int32} | Array(Symbol) | Array(UInt32) = :green,
    title : String = "",
    xlabel : String = "",
    border : Symbol = :corners,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    compact_labels : Bool = false,
    compact : Bool = false,
    width : Int32? = nil,
  ) : Plot
    boxplot(dict.values,
      names: dict.keys,
      color: color, title: title, xlabel: xlabel,
      border: border, margin: margin, padding: padding, labels: labels,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
      compact_labels: compact_labels, compact: compact, width: width)
  end

  def boxplot(
    dict : Hash(String, Array(T)),
    *,
    color : Symbol | UInt32 | {Int32, Int32, Int32} | Array(Symbol) | Array(UInt32) = :green,
    title : String = "",
    xlabel : String = "",
    border : Symbol = :corners,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    compact_labels : Bool = false,
    compact : Bool = false,
    width : Int32? = nil,
  ) : Plot forall T
    boxplot(
      dict.transform_values { |v| to_plot_f64(v) },
      color: color, title: title, xlabel: xlabel,
      border: border, margin: margin, padding: padding, labels: labels,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
      compact_labels: compact_labels, compact: compact, width: width)
  end

  def boxplot!(
    plot : Plot,
    data : Array(Float64),
    *,
    name : String = "",
    color : Symbol | UInt32 | {Int32, Int32, Int32} = :auto,
  ) : Plot
    area = plot.graphics.as(BoxplotGraphics)
    c = color == :auto ? plot.next_color! : color
    col = plot_color(c)
    area.add_box!(data, col)

    # Middle row of last box
    plot.label!(:l, area.nrows - 1, name) unless name.empty?

    # Update range using raw min/max of new data (Julia uses same approach)
    new_box = area.boxes.last
    new_xmin = Math.min(new_box.minimum, area.xmin)
    new_xmax = Math.max(new_box.maximum, area.xmax)
    area.xmin = new_xmin
    area.xmax = new_xmax
    bc = ansi_color(border_color)
    fmt = ->(v : Float64) { nice_repr(v, plot.unicode_exponent?, plot.thousands_separator) }
    plot.label!(:bl, fmt.call(new_xmin), bc)
    plot.label!(:b, fmt.call((new_xmin + new_xmax) / 2.0), bc)
    plot.label!(:br, fmt.call(new_xmax), bc)

    plot
  end

  def boxplot!(plot : Plot, data : Array(T), **kwargs) : Plot forall T
    boxplot!(plot, to_plot_f64(data), **kwargs)
  end

  def boxplot!(
    plot : Plot,
    name : String,
    data : Array(Float64),
    *,
    color : Symbol | UInt32 | {Int32, Int32, Int32} = :auto,
  ) : Plot
    boxplot!(plot, data, name: name, color: color)
  end

  def boxplot!(plot : Plot, name : String, data : Array(T), **kwargs) : Plot forall T
    boxplot!(plot, name, to_plot_f64(data), **kwargs)
  end
end
