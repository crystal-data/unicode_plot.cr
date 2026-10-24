module UnicodePlot
  def lineplot(
    x : Array(Float64),
    y : Array(Float64),
    *,
    canvas : Symbol = :braille,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
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
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    xunit : String? = nil,
    yunit : String? = nil,
  ) : Plot
    raise ArgumentError.new("x and y must have the same length") unless x.size == y.size
    lineplot(
      [x], [y],
      canvas: canvas,
      name: name,
      color: color,
      head_tail: head_tail,
      head_tail_frac: head_tail_frac,
      title: title,
      xlabel: unit_label(xlabel, xunit),
      ylabel: unit_label(ylabel, yunit),
      xscale: xscale,
      yscale: yscale,
      height: height,
      width: width,
      border: border,
      compact_labels: compact_labels,
      compact: compact,
      blend: blend,
      xlim: xlim,
      ylim: ylim,
      margin: margin,
      padding: padding,
      labels: labels,
      grid: grid,
      yticks: yticks,
      xticks: xticks,
      min_height: min_height,
      min_width: min_width,
      yflip: yflip,
      xflip: xflip,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
      xunit: nil,
      yunit: nil,
    )
  end

  def lineplot(
    x : Array(Array(Float64)),
    y : Array(Array(Float64)),
    *,
    canvas : Symbol = :braille,
    name : String = "",
    color : PlotColorArg = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
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
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    xunit : String? = nil,
    yunit : String? = nil,
  ) : Plot
    raise ArgumentError.new("x and y must have the same number of series") unless x.size == y.size
    if color.is_a?(Array)
      raise ArgumentError.new("color vector must have the same length as the number of series") unless color.size == x.size
    end

    x.each_with_index do |x_values, i|
      yv = y[i]
      raise ArgumentError.new("x and y series must have the same length") unless x_values.size == yv.size
    end

    flat_x = x.flatten
    flat_y = y.flatten
    xlabel_with_unit = unit_label(xlabel, xunit)
    ylabel_with_unit = unit_label(ylabel, yunit)
    plot = build_plot(
      flat_x, flat_y,
      canvas_type: canvas,
      title: title, xlabel: xlabel_with_unit, ylabel: ylabel_with_unit,
      xscale: xscale, yscale: yscale,
      height: height, width: width,
      border: border, compact_labels: compact_labels, compact: compact,
      blend: blend, xlim: xlim, ylim: ylim,
      margin: margin, padding: padding,
      labels: labels, grid: grid, yticks: yticks, xticks: xticks,
      min_height: min_height, min_width: min_width,
      yflip: yflip, xflip: xflip,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator
    )
    lineplot!(plot, x, y, name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
    plot
  end

  # Convenience overloads
  def lineplot(y : Array(Float64), **kwargs) : Plot
    x = (1..y.size).map(&.to_f)
    lineplot(x, y, **kwargs)
  end

  def lineplot(y : Array(Quantity), **kwargs) : Plot
    x = (1..y.size).map(&.to_f64)
    y_nu = number_unit(y)
    y_values = y_nu[0]
    y_unit = y_nu[1]
    lineplot(x, y_values, **{yunit: y_unit}.merge(kwargs))
  end

  def lineplot(y : Array(T), **kwargs) : Plot forall T
    x = (1..y.size).map(&.to_f64)
    {% if T <= Number %}
      lineplot(x, to_plot_f64(y), **kwargs)
    {% else %}
      raise ArgumentError.new("lineplot(y) requires numeric y values")
    {% end %}
  end

  def lineplot(
    x : Array(Quantity),
    y : Array(Quantity),
    *,
    canvas : Symbol = :braille,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
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
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    xunit : String? = nil,
    yunit : String? = nil,
  ) : Plot
    x_nu = number_unit(x)
    x_values = x_nu[0]
    inferred_xunit = x_nu[1]
    y_nu = number_unit(y)
    y_values = y_nu[0]
    inferred_yunit = y_nu[1]
    lineplot(
      x_values,
      y_values,
      canvas: canvas,
      name: name,
      color: color,
      head_tail: head_tail,
      head_tail_frac: head_tail_frac,
      title: title,
      xlabel: xlabel,
      ylabel: ylabel,
      xscale: xscale,
      yscale: yscale,
      height: height,
      width: width,
      border: border,
      compact_labels: compact_labels,
      compact: compact,
      blend: blend,
      xlim: xlim,
      ylim: ylim,
      margin: margin,
      padding: padding,
      labels: labels,
      grid: grid,
      yticks: yticks,
      xticks: xticks,
      min_height: min_height,
      min_width: min_width,
      yflip: yflip,
      xflip: xflip,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
      xunit: xunit || inferred_xunit,
      yunit: yunit || inferred_yunit,
    )
  end

  def lineplot(x : Array(T), y : Array(Quantity), **kwargs) : Plot forall T
    y_nu = number_unit(y)
    y_values = y_nu[0]
    y_unit = y_nu[1]
    {% if T == Quantity %}
      x_nu = number_unit(x)
      x_values = x_nu[0]
      x_unit = x_nu[1]
      lineplot(x_values, y_values, **{xunit: x_unit, yunit: y_unit}.merge(kwargs))
    {% else %}
      lineplot(to_plot_f64(x), y_values, **{yunit: y_unit}.merge(kwargs))
    {% end %}
  end

  def lineplot(x : Array(Quantity), y : Array(T), **kwargs) : Plot forall T
    x_nu = number_unit(x)
    x_values = x_nu[0]
    x_unit = x_nu[1]
    {% if T == Quantity %}
      y_nu = number_unit(y)
      y_values = y_nu[0]
      y_unit = y_nu[1]
      lineplot(x_values, y_values, **{xunit: x_unit, yunit: y_unit}.merge(kwargs))
    {% else %}
      lineplot(x_values, to_plot_f64(y), **{xunit: x_unit}.merge(kwargs))
    {% end %}
  end

  # EXPERIMENTAL: Time x-axis support requires an explicit Crystal Time#to_s format string.
  def lineplot(
    x : Array(Time),
    y : Array(T),
    *,
    format : String? = nil,
    canvas : Symbol = :braille,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
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
    xlim : {Time, Time}? = nil,
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
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    yunit : String? = nil,
  ) : Plot forall T
    {% unless T <= Number %}
      {% raise "lineplot(Time x, y) requires numeric y values" %}
    {% end %}
    fmt = time_axis_format!(format)
    limits = time_axis_limits(x, xlim)
    plot = lineplot(
      time_axis_values(x),
      to_plot_f64(y),
      canvas: canvas,
      name: name,
      color: color,
      head_tail: head_tail,
      head_tail_frac: head_tail_frac,
      title: title,
      xlabel: xlabel,
      ylabel: ylabel,
      xscale: xscale,
      yscale: yscale,
      height: height,
      width: width,
      border: border,
      compact_labels: compact_labels,
      compact: compact,
      blend: blend,
      xlim: time_axis_limits_to_f64(limits),
      ylim: ylim,
      margin: margin,
      padding: padding,
      labels: labels,
      grid: grid,
      yticks: yticks,
      xticks: false,
      min_height: min_height,
      min_width: min_width,
      yflip: yflip,
      xflip: xflip,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
      yunit: yunit,
    )
    label_time_xaxis!(plot, limits, fmt, xflip) if xticks
    plot
  end

  def lineplot(x : Array(Float64), f : Float64 -> Float64, **kwargs) : Plot
    lineplot(x, x.map { |v| f.call(v) }, **kwargs)
  end

  def lineplot(x : Array(T), f : Float64 -> Float64, **kwargs) : Plot forall T
    lineplot(to_plot_f64(x), f, **kwargs)
  end

  def lineplot(startx : Float64, endx : Float64, f : Float64 -> Float64, **kwargs) : Plot
    w = kwargs[:width]?.try(&.as(Int32)) || default_width
    n = 3 * w
    span = endx - startx
    x = (0..n).map { |i| startx + span * i.to_f / n }
    lineplot(x, f, **kwargs)
  end

  def lineplot(f : Float64 -> Float64, **kwargs) : Plot
    lineplot(-10.0, 10.0, f, **kwargs)
  end

  # Generic numeric overloads for lineplot
  def lineplot(x : Array(T), y : Array(U), **kwargs) : Plot forall T, U
    {% if T <= Number && U <= Number %}
      lineplot(to_plot_f64(x), to_plot_f64(y), **kwargs)
    {% else %}
      raise ArgumentError.new("lineplot(x, y) requires numeric arrays")
    {% end %}
  end

  def lineplot(x : Array(Array(T)), y : Array(Array(U)), **kwargs) : Plot forall T, U
    {% if T <= Number && U <= Number %}
      xs = x.map { |vals| to_plot_f64(vals) }
      ys = y.map { |vals| to_plot_f64(vals) }
      lineplot(xs, ys, **kwargs)
    {% else %}
      raise ArgumentError.new("lineplot multi-series requires numeric arrays")
    {% end %}
  end

  def lineplot!(
    plot : Plot,
    x : Array(Float64),
    y : Array(Float64),
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    raise ArgumentError.new("x and y must have the same length") unless x.size == y.size
    lineplot!(plot, [x], [y], name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    x : Array(Array(Float64)),
    y : Array(Array(Float64)),
    *,
    name : String = "",
    color : PlotColorArg = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    raise ArgumentError.new("x and y must have the same number of series") unless x.size == y.size
    if color.is_a?(Array)
      raise ArgumentError.new("color vector must have the same length as the number of series") unless color.size == x.size
    end

    x.each_with_index do |x_values, i|
      yv = y[i]
      raise ArgumentError.new("x and y series must have the same length") unless x_values.size == yv.size

      series_color = color.is_a?(Array) ? color[i] : color
      lineplot_single!(plot, x_values, yv, name: name, color: series_color, head_tail: head_tail, head_tail_frac: head_tail_frac)
    end
    plot
  end

  private def lineplot_single!(
    plot : Plot,
    x : Array(Float64),
    y : Array(Float64),
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    c = color == :auto ? plot.next_color! : color
    col = plot_color(c)
    plot.label!(:r, name, col) unless name.empty?
    nx = x.size
    plot.lines!(x, y, col, plot.canvas.blend?)
    if head_tail && nx > 0
      n = Math.min((head_tail_frac * nx).to_i32, nx - 1)
      comp = complement(col)
      callable = n > 0 ? :lines : :points
      if head_tail == :head || head_tail == :both
        xs_head = x[(nx - 1 - n)..]
        ys_head = y[(nx - 1 - n)..]
        if callable == :lines
          plot.lines!(xs_head, ys_head, comp, plot.canvas.blend?)
        else
          plot.points!(xs_head, ys_head, comp, plot.canvas.blend?)
        end
      end
      if head_tail == :tail || head_tail == :both
        xs_tail = x[..n]
        ys_tail = y[..n]
        if callable == :lines
          plot.lines!(xs_tail, ys_tail, comp, plot.canvas.blend?)
        else
          plot.points!(xs_tail, ys_tail, comp, plot.canvas.blend?)
        end
      end
    end
    plot.series += 1
    plot
  end

  # EXPERIMENTAL: appends Time x-axis data to an existing plot using Unix seconds internally.
  def lineplot!(
    plot : Plot,
    x : Array(Time),
    y : Array(T),
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot forall T
    {% unless T <= Number %}
      {% raise "lineplot!(Time x, y) requires numeric y values" %}
    {% end %}
    lineplot!(plot, time_axis_values(x), to_plot_f64(y), name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    x : Array,
    y : Array,
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    lineplot!(plot, to_plot_f64(x), to_plot_f64(y), name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    x : Array(Quantity),
    y : Array(Quantity),
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    x_values = number_unit(x)[0]
    y_values = number_unit(y)[0]
    lineplot!(plot, x_values, y_values, name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    x : Array,
    y : Array(Quantity),
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    y_values = number_unit(y)[0]
    lineplot!(plot, to_plot_f64(x), y_values, name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    x : Array(Quantity),
    y : Array,
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    x_values = number_unit(x)[0]
    lineplot!(plot, x_values, to_plot_f64(y), name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    x : Array(Array),
    y : Array(Array),
    *,
    name : String = "",
    color : PlotColorArg = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    xs = x.map { |vals| to_plot_f64(vals) }
    ys = y.map { |vals| to_plot_f64(vals) }
    lineplot!(plot, xs, ys, name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    y : Array,
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    x = (1..y.size).map(&.to_f64)
    lineplot!(plot, x, to_plot_f64(y), name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(
    plot : Plot,
    y : Array(Quantity),
    *,
    name : String = "",
    color : PlotColor = :auto,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    x = (1..y.size).map(&.to_f64)
    y_values = number_unit(y)[0]
    lineplot!(plot, x, y_values, name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
  end

  def lineplot!(plot : Plot, intercept : Number, slope : Number, **kwargs) : Plot
    xmin, xmax = plot.raw_xlim || {plot.canvas.origin_x, plot.canvas.origin_x + plot.canvas.width}
    intercept_f = intercept.to_f64
    slope_f = slope.to_f64
    lineplot!(plot,
      [xmin, xmax],
      [intercept_f + xmin * slope_f, intercept_f + xmax * slope_f],
      **kwargs)
  end

  def lineplot!(plot : Plot, f : Float64 -> Float64, **kwargs) : Plot
    can = plot.canvas
    n = 3 * can.ncols
    xmin, xmax = plot.raw_xlim || {can.origin_x, can.origin_x + can.width}
    x = (0..n).map { |i| xmin + (xmax - xmin) * i.to_f / n }
    lineplot!(plot, x, x.map { |v| f.call(v) }, **kwargs)
  end

  def lineplot!(plot : Plot, startx : Float64, endx : Float64, f : Float64 -> Float64, **kwargs) : Plot
    n = 3 * plot.canvas.ncols
    span = endx - startx
    x = (0..n).map { |i| startx + span * i.to_f / n }
    lineplot!(plot, x, x.map { |v| f.call(v) }, **kwargs)
  end

  # vline! and hline! helpers
  private def linspace(a : Float64, b : Float64, n : Int32) : Array(Float64)
    return [] of Float64 if n <= 0
    return [a] if n == 1
    (0...n).map { |i| a + (b - a) * i.to_f64 / (n - 1).to_f64 }
  end

  def vline!(plot : Plot, x : Float64, y : Array(Float64)? = nil, **kwargs) : Plot
    can = plot.canvas
    ymin, ymax = plot.raw_ylim || {can.origin_y, can.origin_y + can.height}
    ys = y || linspace(ymin, ymax, can.nrows)
    lineplot!(plot, Array.new(ys.size, x), ys, **kwargs)
  end

  def hline!(plot : Plot, y : Float64, x : Array(Float64)? = nil, **kwargs) : Plot
    can = plot.canvas
    xmin, xmax = plot.raw_xlim || {can.origin_x, can.origin_x + can.width}
    xs = x || linspace(xmin, xmax, can.ncols)
    lineplot!(plot, xs, Array.new(xs.size, y), **kwargs)
  end

  # Private helper to draw lines on a canvas from arrays
  private def lineplot_lines!(plot : Plot, x : Array(Float64), y : Array(Float64), color : UInt32, blend : Bool) : Nil
    (1...x.size).each do |i|
      x1, y1 = x[i - 1], y[i - 1]
      x2, y2 = x[i], y[i]
      next unless x1.finite? && y1.finite? && x2.finite? && y2.finite?
      plot.canvas.lines!(x1, y1, x2, y2, color, blend)
    end
  end
end
