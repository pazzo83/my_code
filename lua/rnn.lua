local class = require 'middleclass'
local dist = require 'sci.dist'
local alg = require 'sci.alg'

local LuaRNN = {}

local function randn(r, c)
    local x = alg.mat(r, c)
    for i=1,#x do
        x[i] = dist.normal(0, 1):sample(rng)
    end
    return x
end

local function ones(r, c)
  local x = alg.mat(r, c)
  for i = 1,#x do
    x[i] = 1.0
  end
  return x
end

LuaRNN.Mat = class('Mat')
function LuaRNN.Mat:initialize(n, d, w, dw)
  self.n = n
  self.d = d or 1
  self.w = w or alg.mat(n, d)
  self.dw = dw or alg.mat(n, d)
end

LuaRNN.randMat = function(n, d, std)
  local std = std or 1.0
  local x = randn(n, d)
  return x[] * std
end
