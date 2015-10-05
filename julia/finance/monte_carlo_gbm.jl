include("/Users/christopheralexander/git_repos/Ito.jl/src/Ito.jl")
using Distributions

function genBrown_Ito(I::Int64)
  S0 = 600.0
  mu = 0.02
  sigma = 2.0
  T = 1.0
  M = 100
  dt = T / M

  bm = Ito.Process.GeometricBrownianMotion(S0, mu, sigma)
  t = 0.0
  W = Normal()

  paths = zeros(Float64, M, I)
  rands = zeros(Float64, M - 1, 1)

  for i = 1:I
    paths[1, i] = x = S0
    rand!(W, rands)
    for j = 2:M
      x = Ito.Process.evolve(bm, t, x, dt, rands[j - 1])
      paths[j, i] = x
    end
  end

  return paths
end

# warm up
genBrown_Ito(10)

# go
@elapsed testing = genBrown_Ito(100000)
testing
