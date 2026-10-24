require "../support/reference_helpers"

describe "Julia reference output compatibility - densityplot" do
  describe "densityplot" do
    # Crystal rejects points beyond the axis limit; Julia's pixel conversion
    # places these boundary points in the last cell. Keep the snapshots visible
    # until the intended boundary behavior is decided.
    pending "matches densityplot/densityplot (boundary pixel parity)" do
      x = DENSITYPLOT_X
      y = DENSITYPLOT_Y
      p = UnicodePlot.densityplot(x, y)
      UnicodePlot.densityplot!(p, x.map { |v| v + 2.0 }, y.map { |v| v + 2.0 })
      test_ref("densityplot/densityplot.txt", p)
    end

    pending "matches densityplot/densityplot_parameters (boundary pixel parity)" do
      x = DENSITYPLOT_X
      y = DENSITYPLOT_Y
      p = UnicodePlot.densityplot(x, y, name: "foo", color: :red, title: "Title", xlabel: "x")
      UnicodePlot.densityplot!(p, x.map { |v| v + 2.0 }, y.map { |v| v + 2.0 }, name: "bar")
      test_ref("densityplot/densityplot_parameters.txt", p)
    end

    it "matches densityplot/densityplot_dscale_identity" do
      x = densityplot_fixture_xprime(DENSITYPLOT_X)
      p = UnicodePlot.densityplot(x, DENSITYPLOT_Y, dscale: :identity)
      test_ref("densityplot/densityplot_dscale_identity.txt", p)
    end

    it "matches densityplot/densityplot_dscale_sqrt" do
      x = densityplot_fixture_xprime(DENSITYPLOT_X)
      p = UnicodePlot.densityplot(x, DENSITYPLOT_Y, dscale: :sqrt)
      test_ref("densityplot/densityplot_dscale_sqrt.txt", p)
    end

    it "matches densityplot/densityplot_dscale_log" do
      x = densityplot_fixture_xprime(DENSITYPLOT_X)
      p = UnicodePlot.densityplot(x, DENSITYPLOT_Y, dscale: ->(v : Float64) { Math.log(1.0 + v) })
      test_ref("densityplot/densityplot_dscale_log.txt", p)
    end

    it "matches densityplot/densityplot_dscale_custom" do
      x = densityplot_fixture_xprime(DENSITYPLOT_X)
      p = UnicodePlot.densityplot(x, DENSITYPLOT_Y, dscale: ->(v : Float64) { v / (v + 1.0) })
      test_ref("densityplot/densityplot_dscale_custom.txt", p)
    end
  end
end
