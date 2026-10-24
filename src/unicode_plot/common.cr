module UnicodePlot
  struct Quantity
    getter value : Float64
    getter unit : String

    def initialize(value : Number, @unit : String)
      @value = value.to_f64
    end
  end

  BLANK         = 0x0020_u32
  BLANK_BRAILLE = 0x2800_u32
  FULL_BRAILLE  = 0x28ff_u32
  FULL_BLOCK    = '█'
  HALF_BLOCK    = '▄'

  alias ColorType = UInt32
  alias PlotColor = Symbol | UInt32 | {Int32, Int32, Int32}
  alias PlotColorArg = PlotColor | Array(Symbol) | Array(UInt32) | Array({Int32, Int32, Int32})
  INVALID_COLOR = UInt32::MAX
  THRESHOLD     = 256_u32 ** 3 # 16_777_216 — 8bit/24bit threshold

  SUPERSCRIPT = {
    '.' => '⸱', '-' => '⁻', '+' => '⁺',
    '0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴',
    '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹',
    'e' => 'ᵉ',
  }

  record Border, tl : Char, tr : Char, bl : Char, br : Char,
    t : Char, l : Char, b : Char, r : Char

  BORDER_SOLID   = Border.new('┌', '┐', '└', '┘', '─', '│', '─', '│')
  BORDER_CORNERS = Border.new('┌', '┐', '└', '┘', ' ', ' ', ' ', ' ')
  BORDER_BARPLOT = Border.new('┌', '┐', '└', '┘', ' ', '┤', ' ', ' ')
  BORDER_BOLD    = Border.new('┏', '┓', '┗', '┛', '━', '┃', '━', '┃')
  BORDER_DOUBLE  = Border.new('╔', '╗', '╚', '╝', '═', '║', '═', '║')
  BORDER_NONE    = Border.new(' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ')
  BORDER_BNONE   = Border.new('⠀', '⠀', '⠀', '⠀', '⠀', '⠀', '⠀', '⠀')
  BORDER_DASHED  = Border.new('┌', '┐', '└', '┘', '╌', '┊', '╌', '┊')
  BORDER_DOTTED  = Border.new('⡤', '⢤', '⠓', '⠚', '⠤', '⡇', '⠒', '⢸')
  BORDER_ASCII   = Border.new('+', '+', '+', '+', '-', '|', '-', '|')

  BORDERMAP = {
    :solid   => BORDER_SOLID,
    :corners => BORDER_CORNERS,
    :barplot => BORDER_BARPLOT,
    :bold    => BORDER_BOLD,
    :double  => BORDER_DOUBLE,
    :none    => BORDER_NONE,
    :bnone   => BORDER_BNONE,
    :dashed  => BORDER_DASHED,
    :dotted  => BORDER_DOTTED,
    :ascii   => BORDER_ASCII,
  }

  MARKERS = {
    :circle => '⚬', :rect => '▫', :diamond => '◇', :hexagon => '⬡',
    :cross => '✚', :xcross => '✖', :utriangle => '△', :dtriangle => '▽',
    :rtriangle => '▷', :ltriangle => '◁', :pentagon => '⬠',
    :star4 => '✦', :star5 => '★', :star6 => '✶', :star8 => '✴',
    :vline => '|', :hline => '―', :plus => '+', :x => '⨯',
  }

  COLOR_CYCLE_FAINT  = [:green, :blue, :red, :magenta, :yellow, :cyan]
  COLOR_CYCLE_BRIGHT = [:light_green, :light_blue, :light_red, :light_magenta, :light_yellow, :light_cyan]

  # Named ANSI 4-bit colors → 256-color palette index (stored as THRESHOLD + idx)
  NAMED_COLORS = {
    :black         => 0_u32,
    :red           => 1_u32,
    :green         => 2_u32,
    :yellow        => 3_u32,
    :blue          => 4_u32,
    :magenta       => 5_u32,
    :cyan          => 6_u32,
    :white         => 7_u32,
    :dark_gray     => 8_u32,
    :light_red     => 9_u32,
    :light_green   => 10_u32,
    :light_yellow  => 11_u32,
    :light_blue    => 12_u32,
    :light_magenta => 13_u32,
    :light_cyan    => 14_u32,
    :light_white   => 15_u32,
  }

  FSCALES = {
    :identity => ->(x : Float64) { x },
    :ln       => ->(x : Float64) { Math.log(x) },
    :sqrt     => ->(x : Float64) { Math.sqrt(x) },
    :cbrt     => ->(x : Float64) { Math.cbrt(x) },
    :log2     => ->(x : Float64) { Math.log2(x) },
    :log10    => ->(x : Float64) { Math.log10(x) },
  }

  ISCALES = {
    :identity => ->(x : Float64) { x },
    :ln       => ->(x : Float64) { Math::E ** x },
    :sqrt     => ->(x : Float64) { x ** 2 },
    :cbrt     => ->(x : Float64) { x ** 3 },
    :log2     => ->(x : Float64) { 2.0 ** x },
    :log10    => ->(x : Float64) { 10.0 ** x },
  }

  BASES = {
    :identity => nil,
    :ln       => "ℯ",
    :sqrt     => nil,
    :cbrt     => nil,
    :log2     => "2",
    :log10    => "10",
  }

  # Mutable global state stored in a dedicated class to avoid class-variable scope issues.
  class Config
    class_property colormode : Symbol = :colors256
    class_property color_cycle : Array(Symbol) = COLOR_CYCLE_FAINT.dup
    class_property default_height : Int32 = 15
    class_property default_width : Int32 = 40
    class_property border_color : Symbol = :dark_gray
    class_property aspect_ratio : Float64 = 4.0 / 3.0
  end

  def colormode : Symbol
    Config.colormode
  end

  def colormode=(m : Symbol)
    Config.colormode = m
  end

  def color_cycle : Array(Symbol)
    Config.color_cycle
  end

  def default_height : Int32
    Config.default_height
  end

  def default_width : Int32
    Config.default_width
  end

  def default_size!(*, height : Int32? = nil, width : Int32? = nil)
    ar = Config.aspect_ratio
    if h = height
      Config.default_height = h
      Config.default_width = (h * 2 * ar).round.to_i32
    elsif w = width
      Config.default_width = w
      Config.default_height = (w / (2 * ar)).round.to_i32
    else
      Config.default_height = 15
      Config.default_width = (15 * 2 * ar).round.to_i32
    end
    {Config.default_height, Config.default_width}
  end

  def border_color : Symbol
    Config.border_color
  end

  def aspect_ratio : Float64
    Config.aspect_ratio
  end

  def scale_callback(scale : Symbol) : Proc(Float64, Float64)
    FSCALES[scale]? || raise ArgumentError.new("unknown scale: #{scale}")
  end

  def scale_callback(scale : Proc(Float64, Float64)) : Proc(Float64, Float64)
    scale
  end

  def superscript(s : String) : String
    s.chars.map { |chr| SUPERSCRIPT[chr]? || chr }.join
  end

  def char_marker(marker : Symbol) : Char
    MARKERS[marker]? || MARKERS[:circle]
  end

  def char_marker(marker : Char) : Char
    marker
  end

  def char_marker(marker : String) : Char
    marker.size == 1 || raise ArgumentError.new("`marker` must have length 1")
    marker[0]
  end

  def quantity(value : Number, unit : String) : Quantity
    Quantity.new(value, unit)
  end

  def quantity(values : Array(T), unit : String) : Array(Quantity) forall T
    {% unless T <= Number %}
      {% raise "quantity(values, unit) requires numeric array elements" %}
    {% end %}
    values.map { |v| Quantity.new(v.to_f64, unit) }
  end

  def unit_label(label : String, unit : String?) : String
    stripped = label.rstrip
    return stripped unless unit
    unit_suffix = "(#{unit})"
    return stripped if stripped.ends_with?(unit_suffix)
    stripped.empty? ? unit : "#{stripped} (#{unit})"
  end

  def number_unit(values : Array(Quantity)) : {Array(Float64), String?}
    return {[] of Float64, nil} if values.empty?
    unit = values.first.unit
    nums = Array(Float64).new(values.size)
    values.each do |quantity|
      unless quantity.unit == unit
        raise ArgumentError.new("mixed units are not supported in one axis: #{unit} and #{quantity.unit}")
      end
      nums << quantity.value
    end
    {nums, unit}
  end

  def number_unit(values : Array(T)) : {Array(Float64), String?} forall T
    {% unless T <= Number %}
      {% raise "number_unit requires numeric array elements" %}
    {% end %}
    {to_plot_f64(values), nil}
  end

  def time_axis_format!(format : String?) : String
    format || raise ArgumentError.new("format is required for Time x values (experimental; uses Crystal Time#to_s format strings)")
  end

  def time_axis_values(values : Array(Time)) : Array(Float64)
    values.map(&.to_unix_f)
  end

  def time_axis_limits(values : Array(Time), xlim : {Time, Time}?) : {Time, Time}
    if limits = xlim
      limits
    elsif values.empty?
      epoch = Time.unix(0)
      {epoch, epoch}
    else
      {values.min, values.max}
    end
  end

  def time_axis_limits_to_f64(limits : {Time, Time}) : {Float64, Float64}
    {limits[0].to_unix_f, limits[1].to_unix_f}
  end

  def label_time_xaxis!(plot : Plot, limits : {Time, Time}, format : String, xflip : Bool) : Nil
    bc = ansi_color(border_color)
    left = limits[0].to_s(format)
    right = limits[1].to_s(format)
    plot.label!(:bl, xflip ? right : left, bc)
    plot.label!(:br, xflip ? left : right, bc)
  end

  private def to_plot_f64(values : Array(T)) : Array(Float64) forall T
    {% unless T <= Number %}
      {% raise "to_plot_f64 requires numeric array elements" %}
    {% end %}
    values.map(&.to_f64)
  end

  def transform_name(tr : Symbol, basename : String = "") : String
    name = tr.to_s
    name == "identity" ? basename : "#{basename} [#{name}]"
  end

  def transform_name(tr : Proc, basename : String = "") : String
    "#{basename} [custom]"
  end

  def no_ansi_escape(str : String) : String
    str.gsub(/\e\[[0-9;]*[a-zA-Z]/, "")
  end

  # Terminal column width for ordinary text. Emoji sequence width remains terminal-dependent.
  def display_width(str : String) : Int32
    no_ansi_escape(str).each_char.sum do |char|
      code = char.ord
      if code == 0 || code < 32 || (0x7f..0x9f).includes?(code) ||
         (0x0300..0x036f).includes?(code) || (0x1ab0..0x1aff).includes?(code) ||
         (0x1dc0..0x1dff).includes?(code) || (0x20d0..0x20ff).includes?(code) ||
         (0xfe20..0xfe2f).includes?(code)
        0
      elsif (0x1100..0x115f).includes?(code) || (0x2329..0x232a).includes?(code) ||
            (0x2e80..0xa4cf).includes?(code) || (0xac00..0xd7a3).includes?(code) ||
            (0xf900..0xfaff).includes?(code) || (0xfe10..0xfe19).includes?(code) ||
            (0xfe30..0xfe6f).includes?(code) || (0xff01..0xff60).includes?(code) ||
            (0xffe0..0xffe6).includes?(code)
        2
      else
        1
      end
    end
  end

  def roundable(x : Float64) : Bool
    x.finite? && x == x.round && x >= Int32::MIN && x <= Int32::MAX
  end

  def compact_repr(x : Number) : String
    x.to_s
  end

  def superscript_str(s : String) : String
    s.chars.map { |chr| SUPERSCRIPT[chr]? || chr }.join
  end

  def nice_repr(x : Int, unicode_exponent : Bool = true, thousands_separator : Char = ' ') : String
    return x.to_s if thousands_separator == '\0'
    xs = x.abs.to_s.chars
    n = xs.size
    v = [] of Char
    xs.reverse.each_with_index do |chr, i|
      v << chr
      v << thousands_separator if i < n - 1 && (i + 1) % 3 == 0
    end
    v.reverse!
    (x >= 0 ? "" : "-") + v.join
  end

  def nice_repr(x : Float64, unicode_exponent : Bool = true, thousands_separator : Char = ' ') : String
    return "0" if x == 0.0
    if roundable(x)
      xi = x.round.to_i64
      return nice_repr(xi, unicode_exponent, thousands_separator)
    end
    str = "%.6g" % x
    if str.includes?('e')
      parts = str.split('e')
      left = parts[0]
      right = parts[1]
      right = right.starts_with?("+") ? right[1..] : right
      right = superscript(right) if unicode_exponent
      "#{left}e#{right}"
    else
      str
    end
  end

  def nice_repr(x : Number, unicode_exponent : Bool = true, thousands_separator : Char = ' ') : String
    nice_repr(x.to_f, unicode_exponent, thousands_separator)
  end

  def ceil_neg_log10(x : Float64) : Int32
    val = -Math.log10(x)
    return Int32::MIN unless val.finite?
    if roundable(val)
      val.ceil.to_i32
    else
      val.floor.to_i32
    end
  end

  private def floor_digits(x : Float64, digits : Int32) : Float64
    factor = 10.0 ** digits
    val = (x * factor).round(10)
    # For positive digits use /factor to avoid FP multiplication error (e.g. val * 0.001).
    # For non-positive digits, -digits >= 0 so 10^(-digits) is an exact integer.
    digits > 0 ? val.floor / factor : val.floor * (10.0 ** (-digits))
  end

  private def ceil_digits(x : Float64, digits : Int32) : Float64
    factor = 10.0 ** digits
    val = (x * factor).round(10)
    digits > 0 ? val.ceil / factor : val.ceil * (10.0 ** (-digits))
  end

  def round_up_subtick(x : Float64, m : Float64) : Float64
    return x if x == 0.0
    digits = ceil_neg_log10(m) + 1
    if x > 0
      ceil_digits(x, digits)
    else
      -floor_digits(-x, digits)
    end
  end

  def round_down_subtick(x : Float64, m : Float64) : Float64
    return x if x == 0.0
    digits = ceil_neg_log10(m) + 1
    if x > 0
      floor_digits(x, digits)
    else
      -ceil_digits(-x, digits)
    end
  end

  def float_round_log10(x : Float64, m : Float64? = nil) : Float64
    mag = m || x.abs
    return x if x == 0.0 || mag <= 0.0 || !mag.finite?
    digits = ceil_neg_log10(mag) + 1
    x.round(digits)
  end

  def plotting_range_narrow(xmin : Float64, xmax : Float64) : {Float64, Float64}
    delta = xmax - xmin
    if delta == 0.0 || !delta.finite?
      return {-Float64::INFINITY, Float64::INFINITY}
    end
    lower = round_down_subtick(xmin, delta)
    upper = round_up_subtick(xmax, delta)
    lower.finite? && upper.finite? && lower < upper ? {lower, upper} : {xmin, xmax}
  end

  private def expand_equal_limits(value : Float64) : {Float64, Float64}
    delta = Math.max(value.abs * 0.1, 1.0)
    lower = value - delta
    upper = value + delta
    lower = value.prev_float unless lower.finite? && lower < value
    upper = value.next_float unless upper.finite? && upper > value
    lower = value if !lower.finite? && upper.finite?
    upper = value if !upper.finite? && lower.finite?
    {lower, upper}
  end

  def extend_limits(
    vec : Enumerable(Float64),
    lims : {Float64, Float64},
    scale : Symbol | Proc(Float64, Float64) = :identity,
  ) : {Float64, Float64}
    mi, ma = lims[0], lims[1]
    explicit = !(mi == 0.0 && ma == 0.0)
    fn = scale_callback(scale)
    values = if explicit
               lower = fn.call(mi)
               upper = fn.call(ma)
               unless lower.finite? && upper.finite? && lower <= upper
                 raise ArgumentError.new("axis limits must be finite and increasing after scaling")
               end
               [lower, upper]
             else
               vec.compact_map { |v| fn.call(v) if v.finite? }.select(&.finite?).to_a
             end
    return {-1.0, 1.0} if values.empty?
    mi, ma = values.min, values.max
    if mi == ma
      mi, ma = expand_equal_limits(mi)
    end
    if scale == :identity
      explicit ? {mi, ma} : plotting_range_narrow(mi, ma)
    else
      {mi, ma}
    end
  end

  def sorted_keys_values(dict : Hash) : {Array(String), Array(Float64)}
    pairs = dict.map { |k, v| {k.to_s, v.to_f} }.sort_by! { |pair| pair[0] }
    {pairs.map { |pair| pair[0] }, pairs.map { |pair| pair[1] }}
  end

  def function_name(name : String, default : String) : String
    default.empty? ? "#{name}(x)" : default
  end

  def out_stream_size(io : IO? = nil) : {Int32, Int32}
    if io
      TerminalSize.displaysize(io)
    else
      TerminalSize.displaysize
    end
  end

  def out_stream_height(io : IO? = nil) : Int32
    out_stream_size(io)[0]
  end

  def out_stream_width(io : IO? = nil) : Int32
    out_stream_size(io)[1]
  end
end
