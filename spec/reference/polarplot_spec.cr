require "../support/reference_helpers"

describe "Julia reference output compatibility - polarplot" do
  describe "polarplot" do
    it "matches polarplot/simple" do
      theta = polarplot_fixture_linspace("simple", "theta")
      r = polarplot_fixture_linspace("simple", "r")
      p = UnicodePlot.polarplot(theta, r)
      test_ref("polarplot/simple.txt", p)
    end

    it "matches polarplot/simple_with_rlim" do
      theta = polarplot_fixture_linspace("simple_with_rlim", "theta")
      r = polarplot_fixture_linspace("simple_with_rlim", "r")
      rlim_json = POLARPLOT_FIXTURE_JSON["simple_with_rlim"]["rlim"].as_a
      rlim = {rlim_json[0].as_f, rlim_json[1].as_f}
      p = UnicodePlot.polarplot(theta, r, rlim: rlim)
      test_ref("polarplot/simple_with_rlim.txt", p)
    end

    it "matches polarplot/callable" do
      theta = polarplot_fixture_linspace("callable", "theta")
      p = UnicodePlot.polarplot(theta, ->(angle : Float64) { angle / (2.0 * Math::PI) })
      test_ref("polarplot/callable.txt", p)
    end

    # This line-based plot has the same final-pixel difference as lineplot.
    pending "matches polarplot/kwargs (line endpoint parity)" do
      scale = POLARPLOT_FIXTURE_JSON["kwargs"]["size_scale"].as_f
      h = (UnicodePlot.default_height * scale).round.to_i
      w = (UnicodePlot.default_width * scale).round.to_i
      theta = polarplot_fixture_linspace("kwargs", "theta")
      r = polarplot_fixture_linspace("kwargs", "r")
      p = UnicodePlot.polarplot(
        theta,
        r,
        lines: false,
        border: :solid,
        color: :red,
        height: h,
        width: w,
      )
      test_ref("polarplot/kwargs.txt", p)
    end
  end
end
