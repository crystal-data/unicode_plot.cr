module UnicodePlot
  HEATMAP_ASPECT_RATIO = 4.0 / 3.0

  # Mirror Julia's get_canvas_dimensions_for_matrix(HeatmapCanvas, 2*size_nrows, size_ncols, ...).
  # Returns {char_height, char_width} where char_height = y-pixel count.
  # nrows(HeatmapGraphics) = (char_height + 1) // 2  (display rows).
  # ameba:disable Metrics/CyclomaticComplexity
  private def heatmap_dimensions(
    size_nrows : Int32, size_ncols : Int32,
    max_height_in : Int32, max_width_in : Int32,
    height_in : Int32?, width_in : Int32?,
    margin : Int32, padding : Int32,
    fix_ar : Bool,
    out_stream : IO? = nil,
  ) : {Int32, Int32}
    return {0, 0} if size_nrows == 0 && size_ncols == 0
    size_nrows = size_nrows.clamp(1, Int32::MAX)
    size_ncols = size_ncols.clamp(1, Int32::MAX)

    # HeatmapCanvas: y_pixel_per_char=2, x_pixel_per_char=1
    # nrow passed = 2*size_nrows → canv_height = nrow/2 = size_nrows
    canv_height = size_nrows.to_f
    canv_width = size_ncols.to_f
    canv_ar = canv_height > 0.0 ? canv_width / canv_height : 1.0

    term_height, term_width = out_stream_size(out_stream)
    width_diff = margin + padding + size_ncols.to_s.size
    max_h = max_height_in > 0 ? max_height_in : term_height
    max_w = max_width_in > 0 ? max_width_in : (term_width - width_diff)

    min_canv_h = canv_height.ceil.to_i
    min_canv_w = canv_width.ceil.to_i

    h, w = if height_in.nil? && width_in.nil?
             if min_canv_h > min_canv_w
               # long matrix
               w2 = [canv_height * canv_ar, max_w.to_f].min
               h2 = [w2 / canv_ar, max_h.to_f].min
               w2 = [h2 * canv_ar, max_w.to_f].min
               {h2, w2}
             else
               # wide (or square) matrix
               h2 = [canv_width / canv_ar, max_h.to_f].min
               w2 = [h2 * canv_ar, max_w.to_f].min
               h2 = [w2 / canv_ar, max_h.to_f].min
               {h2, w2}
             end
           elsif height_in.nil?
             w2 = if width_val = width_in
                    width_val.to_f
                  else
                    max_w.to_f
                  end
             h2 = [w2 / canv_ar, max_h.to_f].min
             {h2, w2}
           elsif width_in.nil?
             h2 = if height_val = height_in
                    height_val.to_f
                  else
                    max_h.to_f
                  end
             w2 = [h2 * canv_ar, max_w.to_f].min
             {h2, w2}
           else
             h2 = height_in ? height_in.to_f : max_h.to_f
             w2 = width_in ? width_in.to_f : max_w.to_f
             {h2, w2}
           end

    # Optional terminal aspect ratio correction (4:3)
    h = (h / (fix_ar ? HEATMAP_ASPECT_RATIO : 1.0)).round.to_i32
    w = w.round.to_i32
    {h.clamp(1, Int32::MAX), w.clamp(1, Int32::MAX)}
  end

  # ameba:enable Metrics/CyclomaticComplexity

  # Nearest-neighbour resampling in the original data coordinate system.
  private def resample_heatmap(
    z : Array(Array(Float64)), x_coords : Array(Float64), y_coords : Array(Float64),
    xlim : {Float64, Float64}, ylim : {Float64, Float64},
    x_step : Float64, y_step : Float64,
    char_height : Int32, disp_w : Int32,
  ) : {Array(Array(Float64)), Array(Array(Bool))}
    present = Array.new(char_height) { Array.new(disp_w, false) }
    if x_coords.empty? || y_coords.empty?
      return {Array.new(char_height) { Array.new(disp_w, Float64::NAN) }, present}
    end

    data = Array.new(char_height) do |pixel_idx|
      y = char_height == 1 ? (ylim[0] + ylim[1]) / 2.0 : ylim[0] + pixel_idx.to_f * (ylim[1] - ylim[0]) / (char_height - 1)
      row_idx = heatmap_source_index(y, y_coords, y_step)
      Array.new(disp_w) do |col_idx|
        x = disp_w == 1 ? (xlim[0] + xlim[1]) / 2.0 : xlim[0] + col_idx.to_f * (xlim[1] - xlim[0]) / (disp_w - 1)
        source_col = heatmap_source_index(x, x_coords, x_step)
        if row_idx && source_col
          present[pixel_idx][col_idx] = true
          z[row_idx][source_col]
        else
          Float64::NAN
        end
      end
    end
    {data, present}
  end

  private def heatmap_source_index(value : Float64, coords : Array(Float64), step : Float64) : Int32?
    return unless step > 0.0 && value >= coords.first - step / 2.0 && value <= coords.last + step / 2.0
    index = ((value - coords.first) / step).round.to_i32
    index.clamp(0, coords.size - 1)
  end

  private def resample_heatmap_unscaled(z_sub : Array(Array(Float64)),
                                        char_height : Int32, disp_w : Int32) : {Array(Array(Float64)), Array(Array(Bool))}
    data_nrows = z_sub.size
    data_ncols = z_sub.empty? ? 0 : z_sub[0].size
    if data_nrows == 0 || data_ncols == 0
      return {
        Array.new(char_height) { Array.new(disp_w, Float64::NAN) },
        Array.new(char_height) { Array.new(disp_w, false) },
      }
    end

    data = Array.new(char_height) do |pixel_idx|
      row_idx = data_nrows == 1 || char_height == 1 ? 0 : (pixel_idx.to_f * (data_nrows - 1) / (char_height - 1)).round.to_i32.clamp(0, data_nrows - 1)
      Array.new(disp_w) do |col_idx|
        source_col = data_ncols == 1 || disp_w == 1 ? 0 : (col_idx.to_f * (data_ncols - 1) / (disp_w - 1)).round.to_i32.clamp(0, data_ncols - 1)
        z_sub[row_idx][source_col]
      end
    end
    {data, Array.new(char_height) { Array.new(disp_w, true) }}
  end

  def heatmap( # ameba:disable Metrics/CyclomaticComplexity
z : Array(Array(Float64)),
              *,
              title : String = "",
              xlabel : String = "",
              ylabel : String = "",
              zlabel : String = "",
              colormap : Symbol = :viridis,
              zlim : {Float64, Float64} = {0.0, 0.0},
              border : Symbol = :solid,
              margin : Int32 = 3,
              padding : Int32 = 1,
              labels : Bool = true,
              unicode_exponent : Bool = true,
              thousands_separator : Char = ' ',
              compact_labels : Bool = false,
              compact : Bool = false,
              xfact : Float64? = nil,
              yfact : Float64? = nil,
              xoffset : Float64 = 0.0,
              yoffset : Float64 = 0.0,
              xlim : {Float64, Float64} = {0.0, 0.0},
              ylim : {Float64, Float64} = {0.0, 0.0},
              array : Bool = false,
              colorbar : Bool? = nil,
              colorbar_border : Symbol = :solid,
              height : Int32? = nil,
              width : Int32? = nil,
              fix_ar : Bool = false,
              out_stream : IO? = nil,) : Plot
    matrix = MatrixView.new(z)

    data_nrows = matrix.nrows
    data_ncols = matrix.ncols

    # Build Y and X coordinate arrays (mirrors Julia's Y/X computation).
    y_arr = matrix_axis_coords(data_nrows, yfact, yoffset)
    x_arr = matrix_axis_coords(data_ncols, xfact, xoffset)

    # autolims: {0,0} means auto → use full data range.
    eff_ylim = if ylim == {0.0, 0.0}
                 y_arr.empty? ? {0.0, 0.0} : {y_arr.min, y_arr.max}
               else
                 {ylim[0].to_f, ylim[1].to_f}
               end
    eff_xlim = if xlim == {0.0, 0.0}
                 x_arr.empty? ? {0.0, 0.0} : {x_arr.min, x_arr.max}
               else
                 {xlim[0].to_f, xlim[1].to_f}
               end

    # Subset data rows/cols within effective limits.
    y_first = y_arr.index { |v| v >= eff_ylim[0] }
    y_last = y_arr.rindex { |v| v <= eff_ylim[1] }
    x_first = x_arr.index { |v| v >= eff_xlim[0] }
    x_last = x_arr.rindex { |v| v <= eff_xlim[1] }

    y_sub = if y_first && y_last && y_first <= y_last
              y_arr[y_first..y_last]
            else
              [] of Float64
            end
    x_sub = if x_first && x_last && x_first <= x_last
              x_arr[x_first..x_last]
            else
              [] of Float64
            end
    z_sub = if y_first && y_last && x_first && x_last && y_first <= y_last && x_first <= x_last
              z[y_first..y_last].map { |row| row[x_first..x_last] }
            else
              [] of Array(Float64)
            end

    # Canvas sizing: use the full limit range (not just subset), matching Julia.
    eff_yfact = yfact || 1.0
    eff_xfact = xfact || 1.0
    dy = eff_ylim[1] - eff_ylim[0]
    dx = eff_xlim[1] - eff_xlim[0]
    size_nrows = if dy == 0.0 || dy < 0.0
                   y_sub.size.clamp(1, Int32::MAX)
                 else
                   ((dy / eff_yfact).ceil.to_i32 + 1).clamp(1, Int32::MAX)
                 end
    size_ncols = if dx == 0.0 || dx < 0.0
                   x_sub.size.clamp(1, Int32::MAX)
                 else
                   ((dx / eff_xfact).ceil.to_i32 + 1).clamp(1, Int32::MAX)
                 end

    # max_height/max_width from user-specified height/width (mirrors Julia).
    data_ar = size_ncols.to_f / size_nrows.to_f
    max_height_in = if height
                      height
                    elsif width
                      (width.to_f / data_ar).ceil.to_i32
                    else
                      0
                    end
    max_width_in = if width
                     width
                   elsif height
                     (height.to_f * data_ar).ceil.to_i32
                   else
                     0
                   end

    char_height, char_width = heatmap_dimensions(
      size_nrows, size_ncols,
      max_height_in, max_width_in,
      height, width,
      margin, padding, fix_ar,
      out_stream,
    )

    # zmin/zmax from data or explicit zlim.
    submatrix = MatrixView.new(z_sub)
    has_extrema = false
    zmin, zmax = if zlim != {0.0, 0.0}
                   has_extrema = true
                   {zlim[0], zlim[1]}
                 else
                   if extrema = matrix_extrema_finite(submatrix)
                     has_extrema = true
                     extrema
                   else
                     {0.0, 1.0}
                   end
                 end
    # Colorbar auto-detection (height >= 7 matches Julia's `height < 7` threshold).
    show_cbar = if colorbar.nil?
                  has_extrema && char_height >= 7 && labels
                else
                  !!colorbar
                end

    fn = colormap_callback(colormap)

    # Preserve source coordinates when the visible range extends past the data.
    data, present = if eff_xfact > 0.0 && eff_yfact > 0.0
                      resample_heatmap(z, x_arr, y_arr, eff_xlim, eff_ylim,
                        eff_xfact, eff_yfact, char_height, char_width)
                    else
                      resample_heatmap_unscaled(z_sub, char_height, char_width)
                    end

    area = HeatmapGraphics.new(data, fn, zmin, zmax, !data.empty?, array, present: present)

    plot = Plot.new(area,
      border: border, title: title, xlabel: xlabel, ylabel: ylabel, zlabel: zlabel,
      margin: margin, padding: padding,
      labels: labels, compact_labels: compact_labels, compact: compact,
      unicode_exponent: unicode_exponent,
      thousands_separator: thousands_separator,
      colorbar: show_cbar,
      colorbar_border: colorbar_border,
      colorbar_lim: {zmin, zmax},
      colormap_callback: fn,
    )

    if labels
      bc = ansi_color(border_color)
      fmt = ->(v : Float64) { nice_repr(v, unicode_exponent, thousands_separator) }
      nr = area.nrows

      label_ylim = ylim == {0.0, 0.0} ? eff_ylim : extend_limits(y_arr, eff_ylim)
      label_xlim = xlim == {0.0, 0.0} ? eff_xlim : extend_limits(x_arr, eff_xlim)

      ys_lo = label_ylim[0]
      ys_hi = label_ylim[1]
      xs_lo = label_xlim[0]
      xs_hi = label_xlim[1]

      # x-axis labels (bottom-left and bottom-right).
      plot.label!(:bl, fmt.call(xs_lo), bc)
      plot.label!(:br, fmt.call(xs_hi), bc)

      # y-axis labels: array mode flips the y-axis (origin at top).
      if array
        plot.label!(:l, nr, fmt.call(ys_hi), bc)
        plot.label!(:l, 1, fmt.call(ys_lo), bc)
      else
        plot.label!(:l, nr, fmt.call(ys_lo), bc)
        plot.label!(:l, 1, fmt.call(ys_hi), bc)
      end
    end

    plot
  end

  def heatmap(z : Array(Array(T)), **kwargs) : Plot forall T
    heatmap(z.map { |row| to_plot_f64(row) }, **kwargs)
  end
end
