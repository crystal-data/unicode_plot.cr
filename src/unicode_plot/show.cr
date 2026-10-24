module UnicodePlot
  WIDTH_CB = 4 # colorbar width: 2 borders + 2 gradient columns

  def show_plot(io : IO, p : Plot) : Nil
    use_color = io.is_a?(IO::FileDescriptor) && io.as(IO::FileDescriptor).tty?
    show_plot(io, p, use_color: use_color)
  end

  def show_plot(io : IO, p : Plot, *, use_color : Bool) : Nil
    render_plot(io, p, use_color)
  end

  # Print the zmax/zmin value label adjacent to the colorbar border.
  # Mirrors Julia's print_colorbar_lim.
  private def print_colorbar_lim(
    io : IO, lab : String, cbar_max_len : Int32, padding : Int32, bc : UInt32,
    trail : String, use_color : Bool,
  ) : Nil
    len = display_width(lab)
    lpad = if len >= WIDTH_CB
             # Wide label: shift left so it centres over the colorbar
             Math.max(0, padding - (len - WIDTH_CB) // 2)
           else
             # Narrow label: align with interior of colorbar (+1) unless starts with sign
             first_char = lab[0]? || '_'
             offset = (first_char == '-' || first_char == '+') ? 0 : 1
             Math.max(0, padding + offset)
           end
    rpad = Math.max(0, cbar_max_len - (lpad - padding) - len)
    io << " " * lpad
    print_color(io, bc, lab, use_color)
    io << " " * rpad
    io << trail
  end

  # Print one row of the colorbar: border row (top/bottom) or gradient row (middle).
  # Mirrors Julia's print_colorbar_row.
  # ameba:disable Metrics/CyclomaticComplexity
  private def print_colorbar_row(
    io : IO, p : Plot, row : Int32, nr : Int32,
    cbar_max_len : Int32, bc : UInt32, use_color : Bool,
  ) : Nil
    cmap = p.colormap
    bmap = BORDERMAP[cmap.border]? || BORDER_SOLID
    lab = ""

    if row == 1 || row == nr
      # Top or bottom border of colorbar
      if row == 1
        cell = bmap.tl.to_s + bmap.t.to_s + bmap.t.to_s + bmap.tr.to_s
      else
        cell = bmap.bl.to_s + bmap.b.to_s + bmap.b.to_s + bmap.br.to_s
      end
      print_color(io, bc, cell, use_color)
    else
      # Gradient row
      print_color(io, bc, bmap.l.to_s, use_color)
      if (cmap.lim[0] - cmap.lim[1]).abs < Float64::EPSILON * 100
        # zmin ≈ zmax: single colour
        color = cmap.callback.call(cmap.lim[0], cmap.lim[0], cmap.lim[1])
        if use_color && color != INVALID_COLOR
          io << ansi_fg_escape(color)
          io << ansi_bg_escape(color)
          io << HALF_BLOCK
          io << HALF_BLOCK
          io << ANSI_RESET
        else
          io << HALF_BLOCK.to_s * 2
        end
      else
        # Blend from zmax (top) to zmin (bottom)
        n = 2.0 * (nr - 2)
        r = (row - 2).to_f
        fg_val = n - 2.0 * r - 1.0
        bg_val = n - 2.0 * r
        fg_col = cmap.callback.call(fg_val, 1.0, n)
        bg_col = cmap.callback.call(bg_val, 1.0, n)
        if use_color
          io << ansi_fg_escape(fg_col) if fg_col != INVALID_COLOR
          io << ansi_bg_escape(bg_col) if bg_col != INVALID_COLOR
          io << HALF_BLOCK
          io << HALF_BLOCK
          io << ANSI_RESET
        else
          io << HALF_BLOCK.to_s * 2
        end
      end
      print_color(io, bc, bmap.r.to_s, use_color)
      # Zlabel on middle row
      lab = p.zlabel if row == nr // 2 + 1 && !p.zlabel.empty?
    end

    lpad = p.zlabel.empty? ? 0 : p.padding
    rpad = Math.max(0, cbar_max_len - lpad - WIDTH_CB - display_width(lab))
    io << " " * lpad
    io << lab
    io << " " * rpad
  end

  # ameba:enable Metrics/CyclomaticComplexity

  # ameba:disable Metrics/CyclomaticComplexity
  private def render_plot(io : IO, p : Plot, use_color : Bool) : Nil
    g = p.graphics
    blank_in = g.blank

    xlab = p.xlabel
    ylab = p.ylabel
    zlab = p.zlabel

    nr = g.nrows
    nc = g.ncols

    p_width = nc + 2
    compact_row = (nr / 2.0).round.to_i32
    old_bottom = p.decorations[:b]?
    old_bottom_color = p.colors_deco[:b]?
    old_left = p.labels_left[compact_row]?
    old_left_color = p.colors_left[compact_row]?

    if p.compact_labels?
      p.label!(:b, xlab) unless xlab.empty?
      p.label!(:l, compact_row, ylab) unless ylab.empty?
    end

    border_sym = (p.border == :none && g.is_a?(BrailleCanvas)) ? :bnone : p.border
    bmap = BORDERMAP[border_sym]? || BORDER_SOLID
    bc = ansi_color(border_color)

    max_len_l = if p.labels? && !p.labels_left.empty?
                  p.labels_left.values.max_of { |label| display_width(label) }
                else
                  0
                end
    max_len_r = if p.labels? && !p.labels_right.empty?
                  p.labels_right.values.max_of { |label| display_width(label) }
                else
                  0
                end
    max_len_a = p.labels? ? [xlab, ylab, zlab].max_of { |label| display_width(label) } : 0

    if !p.compact_labels? && p.labels? && !ylab.empty?
      max_len_l += display_width(ylab) + 1
    end

    has_labels = (max_len_l > 0 || max_len_r > 0 || max_len_a > 0 || !p.decorations.empty?) && p.labels?

    plot_offset = max_len_l + p.margin + p.padding
    border_left_pad = ' '.to_s * plot_offset
    plot_padding = ' '.to_s * p.padding

    # Colorbar setup
    show_cbar = p.colormap.bar?
    cbar_max_len = 0
    min_z_str = ""
    max_z_str = ""
    if show_cbar
      min_z = p.colormap.lim[0]
      max_z = p.colormap.lim[1]
      min_z_str = nice_repr(roundable(min_z) ? min_z : float_round_log10(min_z), p.unicode_exponent?, p.thousands_separator)
      max_z_str = nice_repr(roundable(max_z) ? max_z : float_round_log10(max_z), p.unicode_exponent?, p.thousands_separator)
      zlab_len = display_width(zlab)
      cbar_max_len = [
        display_width(min_z_str),
        display_width(max_z_str),
        WIDTH_CB + (zlab_len > 0 ? p.padding + zlab_len : 0),
      ].max
    end

    # Print title
    unless p.title.empty?
      offset = ((p_width / 2.0) - (display_width(p.title) / 2.0)).round(mode: :ties_away).to_i32
      pre = blank_in.to_s * Math.max(0, offset)
      post = blank_in.to_s * Math.max(0, p_width - offset - display_width(p.title))
      io << border_left_pad
      io << pre
      if use_color
        io << "\e[1;37m"
        io << p.title
        io << ANSI_RESET
      else
        io << p.title
      end
      io << post
      io << '\n'
    end

    # Print top labels (:t, :tl, :tr)
    top_label_rows = 0
    if has_labels
      top_label_rows = print_labels(io, p, :t, nc - 2, border_left_pad + blank_in.to_s, blank_in.to_s + " " * max_len_r, blank_in, use_color)
      io << '\n' if top_label_rows > 0
    end

    # Print top border
    if g.visible?
      io << border_left_pad
      print_color(io, bc, bmap.tl.to_s + bmap.t.to_s * nc + bmap.tr.to_s, use_color)
      if show_cbar
        io << " " * max_len_r
        print_colorbar_lim(io, max_z_str, cbar_max_len, p.padding, bc, "\n", use_color)
      else
        io << plot_padding
        io << " " * max_len_r
        io << '\n'
      end
    end

    y_lab_row = (nr / 2.0).ceil.to_i32

    postprocess = g.preprocess(io)

    (1..nr).each do |row|
      io << " " * p.margin

      if has_labels
        left_str = p.labels_left[row]? || ""
        left_col = p.colors_left[row]? || bc
        right_str = p.labels_right[row]? || ""
        right_col = p.colors_right[row]? || bc
        left_len = display_width(left_str)
        right_len = display_width(right_str)

        if !p.compact_labels? && row == y_lab_row && !ylab.empty?
          print_color(io, INVALID_COLOR, ylab, use_color)
          io << " " * (max_len_l - display_width(ylab) - left_len)
        else
          io << " " * (max_len_l - left_len)
        end
        print_color(io, left_col, left_str, use_color)
      end

      if g.visible?
        io << plot_padding
        print_color(io, bc, bmap.l.to_s, use_color)
        g.print_row(io, row, use_color)
        print_color(io, bc, bmap.r.to_s, use_color)
        io << plot_padding
      end

      if has_labels
        right_str = p.labels_right[row]? || ""
        right_col = p.colors_right[row]? || bc
        right_len = display_width(right_str)
        print_color(io, right_col, right_str, use_color)
        io << " " * (max_len_r - right_len)
      end

      print_colorbar_row(io, p, row, nr, cbar_max_len, bc, use_color) if show_cbar

      io << '\n' if row < nr
    end

    postprocess.call(g)

    io << '\n' if g.visible? || show_cbar || has_labels

    # Print bottom border
    if g.visible?
      io << border_left_pad
      print_color(io, bc, bmap.bl.to_s + bmap.b.to_s * nc + bmap.br.to_s, use_color)
      if show_cbar
        io << " " * max_len_r
        print_colorbar_lim(io, min_z_str, cbar_max_len, p.padding, bc, "", use_color)
      else
        io << plot_padding
        io << " " * max_len_r
      end
    end

    # Print bottom labels (:b, :bl, :br)
    if has_labels
      had_border = g.visible?
      print_labels(io, p, :b, nc - 2, (had_border ? "\n" : "") + border_left_pad + blank_in.to_s, blank_in.to_s + " " * max_len_r, blank_in, use_color)
      if !p.compact_labels? && !xlab.empty?
        io << '\n'
        offset = ((p_width / 2.0) - (display_width(xlab) / 2.0)).round(mode: :ties_away).to_i32
        pre = blank_in.to_s * Math.max(0, offset)
        post = blank_in.to_s * Math.max(0, p_width - pre.size - display_width(xlab))
        io << border_left_pad
        io << pre
        io << xlab
        io << post
      end
    end

    io << '\n'
  ensure
    if p.compact_labels?
      row = compact_row || 1
      if old_bottom
        p.decorations[:b] = old_bottom
      else
        p.decorations.delete(:b)
      end
      if old_bottom_color
        p.colors_deco[:b] = old_bottom_color
      else
        p.colors_deco.delete(:b)
      end
      if old_left
        p.labels_left[row] = old_left
      else
        p.labels_left.delete(row)
      end
      if old_left_color
        p.colors_left[row] = old_left_color
      else
        p.colors_left.delete(row)
      end
    end
  end

  # ameba:disable Metrics/CyclomaticComplexity
  private def print_labels(
    io : IO, p : Plot, loc : Symbol, border_len : Int32,
    left_pad : String, right_pad : String, blank : Char, use_color : Bool,
  ) : Int32
    return 0 unless p.labels?
    bc = ansi_color(border_color)
    lloc, rloc = case loc
                 when :t then {:tl, :tr}
                 when :b then {:bl, :br}
                 else         {loc, loc}
                 end
    mloc = loc
    left_str = p.decorations[lloc]? || ""
    mid_str = p.decorations[mloc]? || ""
    right_str = p.decorations[rloc]? || ""
    return 0 if left_str.empty? && mid_str.empty? && right_str.empty?

    left_col = p.colors_deco[lloc]? || bc
    mid_col = p.colors_deco[mloc]? || bc
    right_col = p.colors_deco[rloc]? || bc

    left_len = display_width(left_str)
    mid_len = display_width(mid_str)
    right_len = display_width(right_str)

    io << left_pad
    print_color(io, left_col, left_str, use_color)
    cnt = ((border_len / 2.0) - (mid_len / 2.0) - left_len).round(mode: :ties_away).to_i32
    io << blank.to_s * Math.max(0, cnt)
    print_color(io, mid_col, mid_str, use_color)
    cnt2 = border_len - right_len - left_len - mid_len + 2 - cnt
    io << blank.to_s * Math.max(0, cnt2)
    print_color(io, right_col, right_str, use_color)
    io << right_pad
    1
  end
end
