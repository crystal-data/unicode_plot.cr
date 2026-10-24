module UnicodePlot
  # Sturges' rule — kept for backward compatibility / user access.
  def sturges(n : Int32) : Int32
    (Math.log2(n) + 1).ceil.to_i32
  end

  # Round step up to next "nice" value ({1,2,5} × 10^k), matching Julia's StatsBase histrange.
  # Thresholds 1.1, 2.2, 5.5 are taken directly from StatsBase._histrange_step.
  private def nice_hist_step(step : Float64) : Float64
    return step if step <= 0.0
    mag = 10.0 ** Math.log10(step).floor
    k = step / mag
    n = if k <= 1.1
          1.0
        elsif k <= 2.2
          2.0
        elsif k <= 5.5
          5.0
        else
          10.0
        end
    n * mag
  end

  def histogram(
    data : Array(Float64),
    *,
    nbins : Int32? = nil,
    closed : Symbol = :left,
    vertical : Bool = false,
    stats : Bool = true,
    color : Symbol | UInt32 | {Int32, Int32, Int32} = :green,
    title : String = "",
    xlabel : String = "",
    ylabel : String = "", # currently unused; kept for API compatibility
    border : Symbol = :barplot,
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    xscale : Symbol | Proc(Float64, Float64) = :identity,
    symbols : Array(Char) = ['▏', '▎', '▍', '▌', '▋', '▊', '▉', '█'],
    width : Int32? = nil,
  ) : Plot
    raise ArgumentError.new("closed must be :left or :right") unless closed == :left || closed == :right
    if vertical
      unless xscale.is_a?(Symbol) && xscale == :identity
        raise ArgumentError.new("xscale is not supported for vertical histogram")
      end
    end

    if data.empty?
      return barplot([] of String, [] of Float64,
        color: color, title: title, xlabel: xlabel, border: border,
        margin: margin, padding: padding, labels: labels,
        unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
        symbols: symbols, width: width)
    end

    raw_data = data.select(&.finite?)
    if raw_data.empty?
      return barplot([] of String, [] of Float64,
        color: color, title: title, xlabel: xlabel, border: border,
        margin: margin, padding: padding, labels: labels,
        unicode_exponent: unicode_exponent, thousands_separator: thousands_separator,
        symbols: symbols, width: width)
    end

    n_bins = histogram_bin_count(raw_data, nbins)
    dmin, dmax = histogram_data_bounds(raw_data)

    if vertical
      histogram_vertical_plot(raw_data, n_bins, dmin, dmax,
        stats: stats, xlabel: xlabel, closed: closed,
        color: color, title: title,
        margin: margin, padding: padding, labels: labels,
        unicode_exponent: unicode_exponent,
        thousands_separator: thousands_separator,
        width: width)
    else
      histogram_horizontal_plot(raw_data, n_bins, dmin, dmax,
        closed: closed,
        xscale: xscale,
        color: color, title: title, xlabel: xlabel,
        border: border, margin: margin, padding: padding,
        labels: labels, unicode_exponent: unicode_exponent,
        thousands_separator: thousands_separator, symbols: symbols, width: width)
    end
  end

  private def histogram_bin_count(data : Array(Float64), nbins : Int32?) : Int32
    n_bins = nbins || sturges(data.size)
    Math.max(n_bins, 2)
  end

  private def histogram_data_bounds(data : Array(Float64)) : {Float64, Float64}
    dmin, dmax = data.min, data.max
    dmin == dmax ? expand_equal_limits(dmin) : {dmin, dmax}
  end

  # Search the actual Float64 edges so division rounding cannot move an exact edge.
  private def histogram_bin_index(edges : Array(Float64), value : Float64, closed : Symbol) : Int32
    lower = 0
    upper = edges.size
    while lower < upper
      middle = lower + (upper - lower) // 2
      if edges[middle] < value || (closed == :left && edges[middle] == value)
        lower = middle + 1
      else
        upper = middle
      end
    end
    (lower - 1).clamp(0, edges.size - 2)
  end

  private def histogram_bins(data : Array(Float64), n_bins : Int32,
                             dmin : Float64, dmax : Float64,
                             closed : Symbol) : {Array(Float64), Array(Float64)}
    step = nice_hist_step((dmax - dmin) / n_bins)
    edge_min = (dmin / step).floor * step
    edge_min -= step if closed == :right && edge_min >= data.min
    n_actual = Math.max(((dmax - edge_min) / step).ceil.to_i32, 2)
    edges = (0..n_actual).map { |i| edge_min + i * step }
    while closed == :left ? edges.last <= data.max : edges.last < data.max
      n_actual += 1
      edges << edge_min + n_actual * step
    end
    counts = Array(Float64).new(n_actual, 0.0)
    data.each { |value| counts[histogram_bin_index(edges, value, closed)] += 1.0 }
    {edges, counts}
  end

  private def histogram_vertical_plot(
    data : Array(Float64),
    n_bins : Int32,
    dmin : Float64,
    dmax : Float64,
    *,
    stats : Bool,
    xlabel : String,
    closed : Symbol,
    color : Symbol | UInt32 | {Int32, Int32, Int32},
    title : String,
    margin : Int32,
    padding : Int32,
    labels : Bool,
    unicode_exponent : Bool,
    thousands_separator : Char,
    width : Int32?,
  ) : Plot
    edges, vert_counts = histogram_bins(data, n_bins, dmin, dmax, closed)

    info = if stats && xlabel.empty?
             mu = data.sum / data.size
             sigma = Math.sqrt(data.sum { |v| (v - mu) ** 2 } / data.size)
             "μ ± σ: #{mu.round(2)} ± #{sigma.round(2)}"
           else
             xlabel
           end

    histogram_vertical(vert_counts, edges,
      color: color, title: title, xlabel: info,
      margin: margin, padding: padding, labels: labels,
      unicode_exponent: unicode_exponent, thousands_separator: thousands_separator, width: width)
  end

  private def histogram_horizontal_plot(
    data : Array(Float64),
    n_bins : Int32,
    dmin : Float64,
    dmax : Float64,
    *,
    closed : Symbol,
    xscale : Symbol | Proc(Float64, Float64),
    color : Symbol | UInt32 | {Int32, Int32, Int32},
    title : String,
    xlabel : String,
    border : Symbol,
    margin : Int32,
    padding : Int32,
    labels : Bool,
    unicode_exponent : Bool,
    thousands_separator : Char,
    symbols : Array(Char),
    width : Int32?,
  ) : Plot
    edges, counts = histogram_bins(data, n_bins, dmin, dmax, closed)

    histogram_horizontal(counts, edges,
      closed: closed,
      xscale: xscale,
      color: color, title: title, xlabel: xlabel,
      border: border, margin: margin, padding: padding,
      labels: labels, unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator, symbols: symbols, width: width)
  end

  private def histogram_vertical(
    counts : Array(Float64), edges : Array(Float64),
    *, color : Symbol | UInt32 | {Int32, Int32, Int32}, title : String, xlabel : String,
    margin : Int32, padding : Int32, labels : Bool,
    unicode_exponent : Bool, thousands_separator : Char, width : Int32?,
  ) : Plot
    edge_min = edges.first
    edge_max = edges.last
    n_bins = counts.size
    max_val = counts.max.to_f
    max_val = 1.0 if max_val <= 0.0
    actual_width = width || n_bins
    # Use xticks/yticks:false to set axis labels manually with exact values,
    # bypassing plotting_range_narrow rounding that distorts histogram edges and scale.
    plot = build_plot(
      [edge_min, edge_max], [0.0, max_val],
      canvas_type: :braille,
      title: title, xlabel: xlabel,
      border: :corners,
      width: actual_width,
      margin: margin, padding: padding, labels: labels,
      ylim: {0.0, max_val},
      grid: false,
      xticks: false,
      yticks: false,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
    )
    bc = ansi_color(border_color)
    fmt = ->(v : Float64) { nice_repr(v, unicode_exponent, thousands_separator) }
    plot.label!(:bl, fmt.call(edge_min), bc)
    plot.label!(:br, fmt.call(edge_max), bc)
    can = plot.canvas
    plot.label!(:l, 1, fmt.call(max_val), bc)
    plot.label!(:l, can.nrows, fmt.call(0.0), bc)
    bar_color = plot_color(color)
    vbar = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
    (1..can.ncols).each do |col|
      draw_vhist_col!(can, col, counts, edges, max_val, bar_color, vbar)
    end
    plot
  end

  private def draw_vhist_col!(can, col, counts, edges, max_val, bar_color, vbar)
    # Map column to bin using the intended edge coordinate system (not canvas coords,
    # which may be rounded by plotting_range_narrow).
    x_mid = edges.first + (col - 0.5) * (edges.last - edges.first) / can.ncols.to_f
    bin_idx = histogram_bin_index(edges, x_mid, :left)
    h = counts[bin_idx].to_f
    return unless h > 0
    h_chars = h / max_val * can.nrows.to_f
    full = h_chars.floor.to_i32
    frac = h_chars - full
    (1..can.nrows).each do |row|
      row_from_bottom = can.nrows - row + 1
      ch = if row_from_bottom <= full
             '█'
           elsif row_from_bottom == full + 1 && frac > 0
             frac_idx = (frac * 8).round.to_i32
             next if frac_idx <= 0
             vbar[frac_idx]
           else
             next
           end
      can.char_point!(col, row, ch, bar_color, false)
    end
  end

  # Round edge value to appropriate precision based on bin width (like Julia's float_round_log10).
  private def hist_edge_round(x : Float64, bin_width : Float64) : Float64
    return x if bin_width <= 0.0
    digits = (-Math.log10(bin_width).floor + 1).to_i32
    digits = Math.max(digits, 0)
    x.round(digits)
  end

  # Format a bin edge value: always show at least 1 decimal place, like Julia's compact_repr.
  private def hist_edge_str(x : Float64) : String
    return "0.0" if x == 0.0
    s = x.to_s
    s.includes?('.') ? s : "#{s}.0"
  end

  private def histogram_horizontal(
    counts : Array(Float64), exact_edges : Array(Float64),
    *, closed : Symbol, xscale : Symbol | Proc(Float64, Float64), color : Symbol | UInt32 | {Int32, Int32, Int32}, title : String, xlabel : String,
    border : Symbol, margin : Int32, padding : Int32, labels : Bool,
    unicode_exponent : Bool, thousands_separator : Char,
    symbols : Array(Char), width : Int32?,
  ) : Plot
    n_bins = counts.size
    bin_width = exact_edges[1] - exact_edges[0]
    l_chr = closed == :right ? '(' : '['
    r_chr = closed == :right ? ']' : ')'

    # Compute edge strings with decimal-point alignment (Julia-style padding)
    edges = exact_edges.map { |edge| hist_edge_round(edge, bin_width) }
    edge_strs = edges.map { |v| hist_edge_str(v) }
    pad_left = 0
    pad_right = 0
    edge_strs.each do |edge_str|
      dot_pos = edge_str.index('.') || edge_str.size
      pad_left = Math.max(pad_left, dot_pos)
      pad_right = Math.max(pad_right, edge_str.size - dot_pos)
    end

    labels_arr = (0...n_bins).map do |i|
      s1 = edge_strs[i]
      s2 = edge_strs[i + 1]
      dot1 = s1.index('.') || s1.size
      dot2 = s2.index('.') || s2.size
      pl1 = " " * (pad_left - dot1)
      pr1 = " " * (pad_right - (s1.size - dot1))
      pl2 = " " * (pad_left - dot2)
      pr2 = " " * (pad_right - (s2.size - dot2))
      "#{l_chr}#{pl1}#{s1}#{pr1}, #{pl2}#{s2}#{pr2}#{r_chr}"
    end
    plot = barplot(
      labels_arr, counts,
      color: color, title: title,
      xlabel: xlabel.empty? ? transform_name(xscale, "Frequency") : xlabel,
      xscale: xscale,
      border: border, margin: margin, padding: padding,
      labels: labels, unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator, symbols: symbols,
      width: width, integer_labels: true
    )
    plot
  end

  def histogram(data : Array(T), **kwargs) : Plot forall T
    histogram(to_plot_f64(data), **kwargs)
  end
end
