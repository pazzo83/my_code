# testing BlackScholes Process
include("/Users/christopheralexander/git_repos/Ito.jl/src/Ito.jl")
using Ito
using Calendar
using Distributions

function gen_box_muller_rand()
  r = rand(2)
  theta = 2*pi*r[1]
  r2 = -2*log(r[2])

  x = sqrt(r2)*cos(theta)
  y = sqrt(r2)*sin(theta)

  return [x, y]
end

function bs_process()
  ref_date = ymd(2015, 9, 27)
  rf_rate = 0.0321
  div_rate = 0.0128
  spot = 52.0
  vol = 0.2144
  cal = Ito.Time.USNYSECalendar()
  dc = Ito.Time.Actual365()

  # Seed random numbers
  MersenneTwister(12324)

  # build term structures
  rfts = Ito.TermStructure.FlatYieldTermStructure(dc, rf_rate, :Continuous, :NoFrequency, ref_date)
  dts = Ito.TermStructure.FlatYieldTermStructure(dc, div_rate, :Continuous, :NoFrequency, ref_date)
  bvts = Ito.TermStructure.BlackVolTermStructure(dc, ref_date, vol)

  bs_process = Ito.Process.GenericBlackScholesProcess(spot, dts, rfts, bvts)

  t = 0.0
  x = bs_process.start
  dt = 0.1

  first_drift = Ito.Process.drift(bs_process, t + dt, x)
  first_diff = Ito.Process.diffusion(bs_process, t + dt, x)
  println("Risk neutral drift: $first_drift")
  println("Diffusion: $first_diff")

  rand_nums = zeros(Float64, 2)

  for i = 1:10
    t = t + dt
    if i % 2 != 0
      rand_nums = gen_box_muller_rand()
      rand_n = rand_nums[1]
    else
      rand_n = rand_nums[2]
    end

    x = Ito.Process.evolve(bs_process, t, x, dt, rand_n)
    println("Time: $t:  $x")
  end

  return x
end

testing = bs_process()
println("results")
print(testing)
