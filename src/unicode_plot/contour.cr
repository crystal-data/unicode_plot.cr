module UnicodePlot
  module Contour
    # Axis convention for this Crystal implementation:
    # row -> first matrix axis / y direction, col -> second matrix axis / x direction.
    alias Point2 = {Float64, Float64}
    alias Crossing = {UInt8, UInt8}
    alias CellIndex = {Int32, Int32}
    alias CellCrossings = Hash(CellIndex, UInt8)

    N = 0x01_u8
    S = 0x02_u8
    E = 0x04_u8
    W = 0x08_u8

    NS = N | S
    NE = N | E
    NW = N | W
    SE = S | E
    SW = S | W
    EW = E | W

    NWSE = NW | 0x10_u8
    NESW = NE | 0x10_u8

    EDGE_LUT = [SW, SE, EW, NE, 0x00_u8, NS, NW, NW, NS, 0x00_u8, NE, EW, SE, SW]

    struct Curve2
      getter vertices : Array(Point2)

      def initialize(@vertices : Array(Point2))
      end
    end

    struct ContourLevel
      getter level : Float64
      getter lines : Array(Curve2)

      def initialize(@level : Float64, @lines : Array(Curve2))
      end
    end

    struct ContourCollection
      getter levels : Array(ContourLevel)

      def initialize(@levels : Array(ContourLevel))
      end
    end

    def self.contour_levels(zmin : Float64, zmax : Float64, n : Int32) : Array(Float64)
      raise ArgumentError.new("number of contour levels must be positive") if n <= 0
      return [] of Float64 unless zmin.finite? && zmax.finite?
      return [] of Float64 if zmin == zmax

      dz = (zmax - zmin) / (n + 1).to_f64
      Array.new(n) { |i| zmin + dz * (i + 1).to_f64 }
    end

    def self.contour_levels(matrix : MatrixView(T), n : Int32) : Array(Float64) forall T
      extrema = UnicodePlot.matrix_extrema_finite(matrix)
      return [] of Float64 if extrema.nil?

      zmin, zmax = extrema
      contour_levels(zmin, zmax, n)
    end

    def self.contours(
      x : Array(Float64),
      y : Array(Float64),
      z : MatrixView(T),
      levels : Int32,
    ) : ContourCollection forall T
      contours(x, y, z, contour_levels(z, levels))
    end

    def self.contours(
      x : Array(Float64),
      y : Array(Float64),
      z : MatrixView(T),
      levels : Array(Float64),
    ) : ContourCollection forall T
      UnicodePlot.validate_matrix_axes!(z, x, y, "z")

      ContourCollection.new(
        levels.map { |level| contour(x, y, z, level) }
      )
    end

    def self.contour(
      x : Array(Float64),
      y : Array(Float64),
      z : MatrixView(T),
      level : Float64,
    ) : ContourLevel forall T
      UnicodePlot.validate_matrix_axes!(z, x, y, "z")
      return ContourLevel.new(level, [] of Curve2) if z.nrows < 2 || z.ncols < 2

      cells = level_cells(z, level)
      lines = trace_contour(x, y, z, level, cells)
      ContourLevel.new(level, lines)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def self.level_cells(z : MatrixView(T), level : Float64) : CellCrossings forall T
      cells = CellCrossings.new
      return cells if z.nrows < 2 || z.ncols < 2

      (0...(z.nrows - 1)).each do |row|
        (0...(z.ncols - 1)).each do |col|
          z00 = z[row, col].to_f64
          z01 = z[row, col + 1].to_f64
          z10 = z[row + 1, col].to_f64
          z11 = z[row + 1, col + 1].to_f64

          next unless z00.finite? && z01.finite? && z10.finite? && z11.finite?

          case_id = 0
          case_id |= 1 if z00 > level
          case_id |= 2 if z01 > level
          case_id |= 4 if z11 > level
          case_id |= 8 if z10 > level

          next if case_id == 0 || case_id == 15

          crossing = if case_id == 5
                       center = 0.25 * (z00 + z01 + z10 + z11)
                       center >= level ? NWSE : NESW
                     elsif case_id == 10
                       center = 0.25 * (z00 + z01 + z10 + z11)
                       center >= level ? NESW : NWSE
                     else
                       EDGE_LUT[case_id - 1]
                     end

          cells[{row, col}] = crossing unless crossing == 0_u8
        end
      end

      cells
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def self.interpolate(
      x : Array(Float64),
      y : Array(Float64),
      z : MatrixView(T),
      level : Float64,
      row : Int32,
      col : Int32,
      edge : UInt8,
    ) : Point2 forall T
      case edge
      when W
        y0 = y[row]
        y1 = y[row + 1]
        z0 = z[row, col].to_f64
        z1 = z[row + 1, col].to_f64
        {normalize_coord(x[col]), normalize_coord(lerp(y0, y1, z0, z1, level))}
      when E
        y0 = y[row]
        y1 = y[row + 1]
        z0 = z[row, col + 1].to_f64
        z1 = z[row + 1, col + 1].to_f64
        {normalize_coord(x[col + 1]), normalize_coord(lerp(y0, y1, z0, z1, level))}
      when N
        x0 = x[col]
        x1 = x[col + 1]
        z0 = z[row + 1, col].to_f64
        z1 = z[row + 1, col + 1].to_f64
        {normalize_coord(lerp(x0, x1, z0, z1, level)), normalize_coord(y[row + 1])}
      when S
        x0 = x[col]
        x1 = x[col + 1]
        z0 = z[row, col].to_f64
        z1 = z[row, col + 1].to_f64
        {normalize_coord(lerp(x0, x1, z0, z1, level)), normalize_coord(y[row])}
      else
        raise ArgumentError.new("unknown edge: #{edge}")
      end
    end

    private def self.lerp(a : Float64, b : Float64, va : Float64, vb : Float64, level : Float64) : Float64
      return a if va == vb
      t = (level - va) / (vb - va)
      a + t * (b - a)
    end

    private def self.normalize_coord(value : Float64) : Float64
      value == 0.0 ? 0.0 : value
    end

    private def self.finite_cell?(z : MatrixView(T), row : Int32, col : Int32) : Bool forall T
      z[row, col].to_f64.finite? && z[row, col + 1].to_f64.finite? &&
        z[row + 1, col].to_f64.finite? && z[row + 1, col + 1].to_f64.finite?
    end

    private def self.trace_contour(
      x : Array(Float64),
      y : Array(Float64),
      z : MatrixView(T),
      level : Float64,
      cells : CellCrossings,
    ) : Array(Curve2) forall T
      curves = [] of Curve2
      return curves if cells.empty?

      row_range = 0...(z.nrows - 1)
      col_range = 0...(z.ncols - 1)

      until cells.empty?
        contour = [] of Point2

        start_cell, start_type = cells.first
        start_row, start_col = start_cell
        starting_crossing = first_crossing(start_type)
        starting_edge = first_edge_bit(starting_crossing)

        contour << interpolate(x, y, z, level, start_row, start_col, starting_edge)

        end_cell = chase!(cells, contour, x, y, z, level, start_cell, starting_edge, row_range, col_range)

        if start_cell == end_cell
          curves << Curve2.new(contour)
          next
        end

        reverse_start, reverse_edge = advance_edge(start_cell, starting_edge)
        if in_bounds_cell?(reverse_start, row_range, col_range) && finite_cell?(z, reverse_start[0], reverse_start[1])
          contour.reverse!
          chase!(cells, contour, x, y, z, level, reverse_start, reverse_edge, row_range, col_range)
        end

        curves << Curve2.new(contour)
      end

      curves
    end

    private def self.chase!(
      cells : CellCrossings,
      contour : Array(Point2),
      x : Array(Float64),
      y : Array(Float64),
      z : MatrixView(T),
      level : Float64,
      start_cell : CellIndex,
      entry_edge : UInt8,
      row_range : Range(Int32, Int32),
      col_range : Range(Int32, Int32),
    ) : CellIndex forall T
      current = start_cell
      loopback_edge = entry_edge

      loop do
        exit_edge = get_next_edge!(cells, current, entry_edge)
        row, col = current
        contour << interpolate(x, y, z, level, row, col, exit_edge)

        current, entry_edge = advance_edge(current, exit_edge)

        break unless in_bounds_cell?(current, row_range, col_range)
        break if current == start_cell && entry_edge == loopback_edge
        break unless finite_cell?(z, current[0], current[1])
      end

      current
    end

    private def self.get_next_edge!(cells : CellCrossings, cell : CellIndex, entry_edge : UInt8) : UInt8
      current = cells.delete(cell)
      raise ArgumentError.new("missing contour cell during trace") if current.nil?

      crossing = current
      if crossing == NWSE
        if entry_edge == N || entry_edge == W
          cells[cell] = SE
          crossing = NW
        else
          cells[cell] = NW
          crossing = SE
        end
      elsif crossing == NESW
        if entry_edge == N || entry_edge == E
          cells[cell] = SW
          crossing = NE
        else
          cells[cell] = NE
          crossing = SW
        end
      end

      (crossing ^ entry_edge).to_u8
    end

    private def self.first_crossing(crossing : UInt8) : UInt8
      return NW if crossing == NWSE
      return NE if crossing == NESW
      crossing
    end

    private def self.first_edge_bit(crossing : UInt8) : UInt8
      return N if (crossing & N) != 0_u8
      return S if (crossing & S) != 0_u8
      return E if (crossing & E) != 0_u8
      return W if (crossing & W) != 0_u8
      raise ArgumentError.new("invalid crossing: #{crossing}")
    end

    private def self.advance_edge(cell : CellIndex, edge : UInt8) : {CellIndex, UInt8}
      row, col = cell
      case edge
      when N
        { {row + 1, col}, S }
      when S
        { {row - 1, col}, N }
      when E
        { {row, col + 1}, W }
      when W
        { {row, col - 1}, E }
      else
        raise ArgumentError.new("unknown edge: #{edge}")
      end
    end

    private def self.in_bounds_cell?(
      cell : CellIndex,
      row_range : Range(Int32, Int32),
      col_range : Range(Int32, Int32),
    ) : Bool
      row, col = cell
      row.in?(row_range) && col.in?(col_range)
    end
  end
end
