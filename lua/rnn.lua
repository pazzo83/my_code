local class = require 'middleclass'
local dist = require 'sci.dist'
local alg = require 'sci.alg'
local prng = require 'sci.prng'

local LuaRNN = {}

local rng = prng.std()

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

local function vecmax(m)
  local v = m[1]
  for i = 2,#m do
    v = max(v, m[i])
  end

  return v
end

local function vecexp(m)
  local cp = m:copy()
  for i = 1,#cp do
    cp[i] = math.exp(cp[i])
  end
  return cp
end

LuaRNN.Mat = class('Mat')
function LuaRNN.Mat:initialize(n, d, w, dw)
  self.n = n
  self.d = d or 1
  self.w = w or alg.mat(n, d)
  self.dw = dw or alg.mat(n, d)
end

function LuaRNN:softmax()
  local out = LuaRNN.Mat(self.n, self.m)
  local maxval = vecmax(self.w)
  out.w = vecexp(self.w - maxval)
  out.w = out.w / alg.sum(out.w)

  return out
end

function LuaRNN.Mat:__tostring()
  local return_str = "RNN Matrix \n"
  return_str = return_str .. "Rows: " .. self.n .. " Cols: " .. self.d .. "\n"
  return_str = return_str .. "Weights:\n" .. tostring(self.w) .. "\n"
  return_str = return_str .. "Gradients:\n" .. tostring(self.dw)

  return return_str
end

LuaRNN.randMat = function(n, d, std)
  local std = std or 1.0
  local rando = randn(n, d)
  local x = rando[] * std
  return LuaRNN.Mat(n, d, x, alg.mat(n, d))
end

LuaRNN.onesMat = function(n, d)
  return LuaRNN.Mat(n, d, ones(n, d), alg.mat(n, d))
end

-- LSTM Stuff
LuaRNN.LSTMLayer = class("LSTMLayer")
function LuaRNN.LSTMLayer:initialize(prevsize, hiddensize, std)
  -- gate params --
  -- cell's input gate
  self.wix = LuaRNN.randMat(hiddensize, prevsize, std)
  self.wih = LuaRNN.randMat(hiddensize, hiddensize, std)
  self.bi = LuaRNN.Mat(hiddensize, 1, alg.mat(hiddensize, 1), alg.mat(hiddensize, 1))

  -- cell's forget parameters
  self.wfx = LuaRNN.randMat(hiddensize, prevsize, std)
  self.wfh = LuaRNN.randMat(hiddensize, hiddensize, std)
  self.bf = LuaRNN.Mat(hiddensize, 1, alg.mat(hiddensize, 1), alg.mat(hiddensize, 1))

  -- cell's out gates
  self.wox = LuaRNN.randMat(hiddensize, prevsize, std)
  self.woh = LuaRNN.randMat(hiddensize, hiddensize, std)
  self.bo = LuaRNN.Mat(hiddensize, 1, alg.mat(hiddensize, 1), alg.mat(hiddensize, 1))

  -- cell's write parameters
  self.wcx = LuaRNN.randMat(hiddensize, prevsize, std)
  self.wch = LuaRNN.randMat(hiddensize, hiddensize, std)
  self.bc = LuaRNN.Mat(hiddensize, 1, alg.mat(hiddensize, 1), alg.mat(hiddensize, 1))
end

LuaRNN.LSTM = class("LSTM")
function LuaRNN.LSTM:initialize(inputsize, hiddensizes, outputsize, std)
  local std = std or 0.08
  self.hdlayers = {}
  self.matrices = {}
  local prevsize = 0

  for i = 1,#hiddensizes do
    if i == 1 then
      prevsize = inputsize
    else
      prevsize = hiddensizes[i-1]
    end

    local layer = LuaRNN.LSTMLayer(prevsize, hiddensizes[i], std)
    table.insert(self.hdlayers, layer)

    -- input gate
    table.insert(self.matrices, layer.wix)
    table.insert(self.matrices, layer.wih)
    table.insert(self.matrices, layer.bi)

    -- forget gate
    table.insert(self.matrices, layer.wfx)
    table.insert(self.matrices, layer.wfh)
    table.insert(self.matrices, layer.bf)

    -- output gate
    table.insert(self.matrices, layer.wox)
    table.insert(self.matrices, layer.woh)
    table.insert(self.matrices, layer.bo)

    -- cell params
    table.insert(self.matrices, layer.wcx)
    table.insert(self.matrices, layer.wch)
    table.insert(self.matrices, layer.bc)
  end
  self.whd = LuaRNN.randMat(outputsize, hiddensizes[#hiddensizes], std)
  self.bd = LuaRNN.Mat(outputsize, 1, alg.mat(outputsize, 1), alg.mat(outputsize, 1))
  table.insert(self.matrices, self.whd)
  table.insert(self.matrices, self.bd)
end


-- #############################################################################
hiddensizes = {10, 10}
outputsize = 2

myLSTM = LuaRNN.LSTM(10, hiddensizes, outputsize)
print(myLSTM)
print(myLSTM.whd)

return LuaRNN
