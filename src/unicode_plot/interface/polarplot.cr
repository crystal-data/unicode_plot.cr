module UnicodePlot
  private def polar_rlim_auto?(rlim : {Float64, Float64}) : Bool
    rlim[0] == 0.0 && rlim[1] == 0.0
  end

  private def polar_label_radius(value : Float64) : String
    rounded = value.round
    if value.finite? && value == rounded
      nice_repr(value)
    else
      "%.1f" % value
    end
  end

  private def polar_range(start_v : Float64, end_v : Float64, length : Int32) : Array(Float64)
    return [] of Float64 if length <= 0
    return [start_v] if length == 1
    span = end_v - start_v
    denom = (length - 1).to_f64
    Array.new(length) { |i| start_v + span * i.to_f64 / denom }
  end

  def polarplot(
    theta : Array(Float64),
    r : Array(Float64),
    *,
    lines : Bool = true,
    rlim : {Float64, Float64} = {0.0, 0.0},
    canvas : Symbol = :braille,
    name : String = "",
    color : PlotColor = :auto,
    marker : Symbol | Char | String = :pixel,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
    title : String = "",
    xlabel : String = "",
    ylabel : String = "",
    xscale : Symbol | Proc(Float64, Float64) = :identity,
    yscale : Symbol | Proc(Float64, Float64) = :identity,
    height : Int32? = nil,
    width : Int32? = nil,
    border : Symbol = :none,
    compact_labels : Bool = false,
    compact : Bool = false,
    blend : Bool = false,
    xlim : {Float64, Float64} = {0.0, 0.0},
    ylim : {Float64, Float64} = {0.0, 0.0},
    margin : Int32 = 3,
    padding : Int32 = 1,
    labels : Bool = true,
    grid : Bool = false,
    yticks : Bool = false,
    xticks : Bool = false,
    min_height : Int32 = 2,
    min_width : Int32 = 5,
    yflip : Bool = false,
    xflip : Bool = false,
    unicode_exponent : Bool = true,
    thousands_separator : Char = ' ',
    degrees : Bool = true,
    num_rad_lab : Int32 = 3,
    ang_rad_lab : Float64 = Math::PI / 4.0,
  ) : Plot
    raise ArgumentError.new("theta and r must have the same length") unless theta.size == r.size

    max_r = if polar_rlim_auto?(rlim)
              r.empty? ? 0.0 : r.max
            else
              rlim[1]
            end

    lims = {-max_r, +max_r}
    plot = build_plot(
      [-max_r, +max_r],
      [-max_r, +max_r],
      canvas_type: canvas,
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
      xlim: xlim == {0.0, 0.0} ? lims : xlim,
      ylim: ylim == {0.0, 0.0} ? lims : ylim,
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
    )

    polarplot!(
      plot,
      theta,
      r,
      lines: lines,
      rlim: rlim,
      degrees: degrees,
      num_rad_lab: num_rad_lab,
      ang_rad_lab: ang_rad_lab,
      name: name,
      color: color,
      marker: marker,
      head_tail: head_tail,
      head_tail_frac: head_tail_frac,
    )
  end

  def polarplot(theta : Array(Float64), r : Float64 -> Float64, **kwargs) : Plot
    polarplot(theta, theta.map { |value| r.call(value) }, **kwargs)
  end

  def polarplot(theta : Array(T), r : Array(U), **kwargs) : Plot forall T, U
    {% if T <= Number && U <= Number %}
      polarplot(to_plot_f64(theta), to_plot_f64(r), **kwargs)
    {% else %}
      raise ArgumentError.new("polarplot(theta, r) requires numeric arrays")
    {% end %}
  end

  def polarplot(theta : Array(T), r : Float64 -> Float64, **kwargs) : Plot forall T
    {% if T <= Number %}
      polarplot(to_plot_f64(theta), r, **kwargs)
    {% else %}
      raise ArgumentError.new("polarplot(theta, r_fn) requires numeric theta values")
    {% end %}
  end

  def polarplot!(
    plot : Plot,
    theta : Array(Float64),
    r : Array(Float64),
    *,
    lines : Bool = true,
    rlim : {Float64, Float64} = {0.0, 0.0},
    degrees : Bool = true,
    num_rad_lab : Int32 = 3,
    ang_rad_lab : Float64 = Math::PI / 4.0,
    name : String = "",
    color : PlotColor = :auto,
    marker : Symbol | Char | String = :pixel,
    head_tail : Symbol? = nil,
    head_tail_frac : Float64 = 0.05,
  ) : Plot
    raise ArgumentError.new("theta and r must have the same length") unless theta.size == r.size

    mr, big_r = if polar_rlim_auto?(rlim)
                  r.empty? ? {0.0, 0.0} : {r.min, r.max}
                else
                  rlim
                end

    theta_grid = Array.new(360) { |i| 2.0 * Math::PI * i.to_f64 / 359.0 }
    grid_color = ansi_color(border_color)

    lineplot!(plot,
      theta_grid.map { |angle| big_r * Math.cos(angle) },
      theta_grid.map { |angle| big_r * Math.sin(angle) },
      color: grid_color)

    0.upto(8) do |i|
      angle = i.to_f64 * Math::PI / 4.0
      cos_a = Math.cos(angle)
      sin_a = Math.sin(angle)
      lineplot!(plot, [mr * cos_a, big_r * cos_a], [mr * sin_a, big_r * sin_a], color: grid_color)
    end

    x = Array.new(theta.size) { |i| r[i] * Math.cos(theta[i]) }
    y = Array.new(theta.size) { |i| r[i] * Math.sin(theta[i]) }

    if lines
      lineplot!(plot, x, y, name: name, color: color, head_tail: head_tail, head_tail_frac: head_tail_frac)
    else
      scatterplot!(plot, x, y, name: name, color: color, marker: marker)
    end

    row = (plot.graphics.nrows.to_f64 / 2.0).ceil.to_i32
    plot.label!(:r, row, degrees ? "0°" : "0", grid_color)
    plot.label!(:t, degrees ? "90°" : "π / 2", grid_color)
    plot.label!(:l, row, degrees ? "180°" : "π", grid_color)
    # Julia currently uses "3π / 4" here, but 270° corresponds to "3π / 2".
    # Keep the mathematically correct label intentionally.
    plot.label!(:b, degrees ? "270°" : "3π / 2", grid_color)

    polar_range(mr, big_r, num_rad_lab).each do |radius|
      plot.annotate!(
        radius * Math.cos(ang_rad_lab),
        radius * Math.sin(ang_rad_lab),
        polar_label_radius(radius),
        grid_color,
        plot.canvas.blend?,
      )
    end

    plot
  end

  def polarplot!(plot : Plot, theta : Array(Float64), r : Float64 -> Float64, **kwargs) : Plot
    polarplot!(plot, theta, theta.map { |value| r.call(value) }, **kwargs)
  end

  def polarplot!(plot : Plot, theta : Array(T), r : Array(U), **kwargs) : Plot forall T, U
    {% if T <= Number && U <= Number %}
      polarplot!(plot, to_plot_f64(theta), to_plot_f64(r), **kwargs)
    {% else %}
      raise ArgumentError.new("polarplot!(theta, r) requires numeric arrays")
    {% end %}
  end

  def polarplot!(plot : Plot, theta : Array(T), r : Float64 -> Float64, **kwargs) : Plot forall T
    {% if T <= Number %}
      polarplot!(plot, to_plot_f64(theta), r, **kwargs)
    {% else %}
      raise ArgumentError.new("polarplot!(theta, r_fn) requires numeric theta values")
    {% end %}
  end
end
