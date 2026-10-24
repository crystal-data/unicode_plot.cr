module UnicodePlot
  private def spy_canvas_pixel_per_char(canvas : Symbol) : {Int32, Int32}
    case canvas
    when :braille
      {4, 2}
    when :block
      {2, 2}
    when :ascii
      {3, 3}
    when :dot
      {2, 1}
    when :density
      {2, 1}
    else
      raise ArgumentError.new("unknown canvas: #{canvas}")
    end
  end

  # Mirrors Julia's get_canvas_dimensions_for_matrix for spy.
  # ameba:disable Metrics/CyclomaticComplexity
  private def spy_dimensions(
    canvas : Symbol,
    nrows : Int32,
    ncols : Int32,
    maxheight : Int32,
    maxwidth : Int32,
    height : Int32?,
    width : Int32?,
    margin : Int32,
    padding : Int32,
    fix_ar : Bool,
    out_stream : IO? = nil,
  ) : {Int32, Int32}
    return {0, 0} if nrows == 0 && ncols == 0

    yppc, xppc = spy_canvas_pixel_per_char(canvas)
    canv_height = nrows.to_f64 / yppc
    canv_width = ncols.to_f64 / xppc
    canv_ar = canv_width / canv_height

    min_canv_h = canv_height.ceil.to_i32
    min_canv_w = canv_width.ceil.to_i32

    term_height, term_width = out_stream_size(out_stream)
    height_diff = 9
    width_diff = margin + padding + ncols.to_s.size + 6
    max_h = maxheight > 0 ? maxheight : (term_height - height_diff)
    max_w = maxwidth > 0 ? maxwidth : (term_width - width_diff)

    h = height
    w = width

    if h.nil? && w.nil?
      if min_canv_h > min_canv_w
        # Long matrix
        w2 = [min_canv_h.to_f64 * canv_ar, max_w.to_f64].min
        h2 = [w2 / canv_ar, max_h.to_f64].min
        w2 = [h2 * canv_ar, max_w.to_f64].min
        h = h2.round.to_i32
        w = w2.round.to_i32
      else
        # Wide matrix
        h2 = [min_canv_w.to_f64 / canv_ar, max_h.to_f64].min
        w2 = [h2 * canv_ar, max_w.to_f64].min
        h2 = [w2 / canv_ar, max_h.to_f64].min
        h = h2.round.to_i32
        w = w2.round.to_i32
      end
    elsif w.nil?
      hv = h || max_h
      wv = [hv.to_f64 * canv_ar, max_w.to_f64].min
      h = hv
      w = wv.round.to_i32
    elsif h.nil?
      wv = w || max_w
      hv = [wv.to_f64 / canv_ar, max_h.to_f64].min
      h = hv.round.to_i32
      w = wv
    end

    ar = fix_ar ? aspect_ratio : 1.0
    final_h = ((h || max_h).to_f64 / ar).round.to_i32
    final_w = (w || max_w).to_f64.round.to_i32

    {final_h.clamp(1, Int32::MAX), final_w.clamp(1, Int32::MAX)}
  end

  # ameba:enable Metrics/CyclomaticComplexity

  def spy(
    a : Array(Array(Float64)),
    *,
    show_zeros : Bool = false,
    color : PlotColor = :auto,
    canvas : Symbol = :braille,
    title : String = "",
    xlabel : String = "",
    ylabel : String = "",
    maxwidth : Int32 = 0,
    maxheight : Int32 = 0,
    out_stream : IO? = nil,
    height : Int32? = nil,
    width : Int32? = nil,
    margin : Int32 = 3,
    padding : Int32 = 1,
    border : Symbol = :solid,
    compact_labels : Bool = false,
    compact : Bool = false,
    labels : Bool = true,
    fix_ar : Bool = false,
    xflip : Bool = false,
    yflip : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
  ) : Plot
    matrix = MatrixView.new(a)

    nrows = matrix.nrows
    ncols = matrix.ncols
    # A nonempty matrix with zero columns has no drawable width or aspect ratio.
    # Keep the supported 0x0 case, but report this shape before sizing it.
    raise ArgumentError.new("spy cannot draw rows with zero columns") if nrows > 0 && ncols == 0

    row_coords = matrix_row_coords(matrix)
    col_coords = matrix_col_coords(matrix)

    rows = [] of Float64
    cols = [] of Float64
    vals = [] of Float64

    matrix.each_cell do |row, col, value|
      v = value.to_f64
      is_zero = v == 0.0
      next if show_zeros ? !is_zero : is_zero

      rows << row_coords[row]
      cols << col_coords[col]
      vals << v
    end

    h, w = spy_dimensions(
      canvas,
      nrows,
      ncols,
      maxheight,
      maxwidth,
      height,
      width,
      margin,
      padding,
      fix_ar,
      out_stream,
    )

    plot = build_plot(
      [1.0, ncols.to_f64],
      [1.0, nrows.to_f64],
      canvas_type: canvas,
      title: title,
      xlabel: xlabel,
      ylabel: ylabel,
      height: h,
      width: w,
      border: border,
      compact_labels: compact_labels,
      compact: compact,
      margin: margin,
      padding: padding,
      labels: labels,
      grid: false,
      # Julia's spy passes canvas_kw: (height: 1 + nrow, width: 1 + ncol).
      # build_plot has no canvas_kw, so use widened limits to match the same mapping scale.
      # For 0x0 matrices, Julia uses xlim=[1,0]/ylim=[1,0] (inverted); Crystal maps this to {0.0,1.0}.
      xlim: ncols == 0 ? {0.0, 1.0} : {1.0, ncols.to_f64 + 2.0},
      ylim: nrows == 0 ? {0.0, 1.0} : {1.0, nrows.to_f64 + 2.0},
      xflip: xflip,
      yflip: yflip,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
      min_height: 1,
      min_width: 1,
    )

    if color != :auto
      point_color = plot_color(color)
      plot.points!(cols, rows, point_color, plot.canvas.blend?)
      plot.label!(:r, 1, show_zeros ? "⩵ 0" : "≠ 0", point_color)
    elsif show_zeros
      zero_color = plot_color(:green)
      plot.points!(cols, rows, zero_color, plot.canvas.blend?)
      plot.label!(:r, 1, "⩵ 0", zero_color)
    else
      point_colors = vals.map { |v| v > 0.0 ? plot_color(:red) : plot_color(:blue) }
      plot.points!(cols, rows, point_colors, plot.canvas.blend?)
      plot.label!(:r, 1, "> 0", plot_color(:red))
      plot.label!(:r, 2, "< 0", plot_color(:blue))
    end

    if plot.xlabel.empty?
      plot.xlabel = "#{plot.nice_repr(vals.size)} #{show_zeros ? "⩵ 0" : "≠ 0"}"
    end

    # Keep displayed axis endpoints identical to Julia's spy.
    bc = ansi_color(border_color)
    x_left, x_right = matrix_horizontal_axis_labels(
      ncols,
      flip: xflip,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
      zero_fallback_range: true,
    )
    y_top, y_bottom = matrix_vertical_axis_labels(
      nrows,
      flip: yflip,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
      zero_fallback_range: true,
    )
    plot.label!(:bl, x_left, bc)
    plot.label!(:br, x_right, bc)
    plot.label!(:l, plot.canvas.nrows, y_top, bc)
    plot.label!(:l, 1, y_bottom, bc)

    plot
  end

  def spy(a : Array(Array(T)), **kwargs) : Plot forall T
    {% if T <= Number %}
      spy(a.map { |row| to_plot_f64(row) }, **kwargs)
    {% else %}
      raise ArgumentError.new("spy(a) requires numeric matrix elements")
    {% end %}
  end
end
