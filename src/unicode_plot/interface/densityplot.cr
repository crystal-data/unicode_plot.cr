module UnicodePlot
  # 2D point-density plot (matches Julia UnicodePlots densityplot).
  # Draws all (x, y) points onto a DensityCanvas; overlapping points
  # accumulate counts that are rendered as ' '/'░'/'▒'/'▓'/'█'.
  def densityplot(
    x : Array(Float64),
    y : Array(Float64),
    *,
    dscale : Symbol | Proc(Float64, Float64) = :identity,
    name : String = "",
    color : Symbol | UInt32 | {Int32, Int32, Int32} = :auto,
    title : String = "",
    xlabel : String = "",
    ylabel : String = "",
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
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    yflip : Bool = false,
    xflip : Bool = false,
  ) : Plot
    raise ArgumentError.new("x and y must have the same length") unless x.size == y.size
    raise ArgumentError.new("data must not be empty") if x.empty?

    mx, bx = extend_limits(x, xlim)
    my, by = extend_limits(y, ylim)

    h = (height || default_height).clamp(5, Int32::MAX)
    w = (width || default_width).clamp(5, Int32::MAX)

    can = DensityCanvas.new(h, w,
      origin_y: my, origin_x: mx,
      height: by - my, width: bx - mx,
      blend: blend,
      yflip: yflip, xflip: xflip,
      dscale: dscale)

    plot = Plot.new(can,
      border: border, title: title, xlabel: xlabel, ylabel: ylabel,
      margin: margin, padding: padding,
      labels: labels, compact_labels: compact_labels, compact: compact,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator)

    if labels
      bc = ansi_color(border_color)
      fmt = ->(v : Float64) { nice_repr(v, unicode_exponent, thousands_separator) }
      plot.label!(:bl, fmt.call(xflip ? bx : mx), bc)
      plot.label!(:br, fmt.call(xflip ? mx : bx), bc)
      plot.label!(:l, h, fmt.call(yflip ? by : my), bc)
      plot.label!(:l, 1, fmt.call(yflip ? my : by), bc)
    end

    scatterplot!(plot, x, y, name: name, color: color)
    plot
  end

  def densityplot(x : Array(T), y : Array(U), **kwargs) : Plot forall T, U
    densityplot(to_plot_f64(x), to_plot_f64(y), **kwargs)
  end

  def densityplot!(
    plot : Plot,
    x : Array(Float64),
    y : Array(Float64),
    *,
    name : String = "",
    color : Symbol | UInt32 | {Int32, Int32, Int32} = :auto,
  ) : Plot
    raise ArgumentError.new("x and y must have the same length") unless x.size == y.size
    scatterplot!(plot, x, y, name: name, color: color)
  end

  def densityplot!(plot : Plot, x : Array(T), y : Array(U), **kwargs) : Plot forall T, U
    densityplot!(plot, to_plot_f64(x), to_plot_f64(y), **kwargs)
  end
end
