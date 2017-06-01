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
    v = math.max(v, m[i])
  end

  return v
end

local function vecexp(m)
  local cp = m:copy()
  for i = 1,#cp do
    cp[i] = math.exp(m[i])
  end
  return cp
end

local function vec_tanh(m)
  local cp = m:copy()
  for i = 1,#cp do
    cp[i] = math.tanh(m[i])
  end
  return cp
end

LuaRNN.Mat = class('Mat')
function LuaRNN.Mat:initialize(n, d, w, dw)
  self.n = n
  self.d = d or 1
  self.w = w or alg.mat(n, d)
  self.dw = dw or alg.mat(n, d)
  -- print("self.w is: ")
  -- print(self.w)
end

function LuaRNN.Mat:softmax()
  local out = LuaRNN.Mat(self.n, self.d)
  local maxval = vecmax(self.w)
  out.w = vecexp(self.w[] - maxval)
  local w_sum = alg.sum(out.w)
  out.w = out.w[] / w_sum

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

LuaRNN.Graph = class("Graph")
function LuaRNN.Graph:initialize(backpropNeeded)
  if backpropNeeded == nil then
    backpropNeeded = true
  end
  self.doBackprop = backpropNeeded
  self.backprop = {}
end

function LuaRNN.Graph:run_backprop()
  for i = #self.backprop,1,-1 do
    self.backprop[i]()
  end
end

function LuaRNN.Graph:rowpluck (m, ix)
  -- pluck a row of m and return it as a column vector
  local out = LuaRNN.Mat(m.d, 1)
  for i = 1,#m.d do
    out.w[{i, 1}] = m.w[{ix, i}]
  end
  if self.doBackprop then
    local k = function()
      for i = 1,#m.d do
        m.dw[{ix, i}] = m.dw[{ix, i}] + out.dw[{i, 1}]
      end
    end
    table.insert(self.backprop, k)
  end
  return out
end

function LuaRNN.Graph:concat(...)
  local n = 0
  local mats = {...}
  for i = 1,#mats do
    n = n + mats[i].n
  end
  out = LuaRNN.Mat(n, mats[1].d, alg.mat(n, mats[1].d), alg.mat(n, mats[1].d))
  n = 0
  for i = 1,#mats do
    m = mats[i]
    for j = 1,m.n do
      for k = 1,m.d do
        out.w[{j + n, k}] = m.w[{j, k}]
      end
    end
    n = n + m.n
  end

  if self.doBackprop then
    local fun = function()
      local n = 0
      for _, m in ipairs(mats) do
        for j = 1,m.n do
          for k = 1,m.d do
            m.dw[{j, k}] = out.dw[{j + n, k}]
          end
        end
        n = n + m.n
      end
    end
    table.insert(self.backprop, fun)
  end
  return out
end

function LuaRNN.Graph:tanh(m)
  local out = LuaRNN.Mat(m.n, m.d)
  out.w = vec_tanh(m.w)
  if self.doBackprop then
    local k = function()
      for i = 1,m.n do
        for j = 1,m.d do
          m.dw[{i, j}] = m.dw[{i, j}] + (1 - math.pow(out.w[{i, j}], 2)) * out.dw[{i, j}]
        end
      end
    end
    table.insert(self.backprop, k)
  end

  return out
end

function LuaRNN.Graph:sigmoid(m)
  local dw = alg.mat(m.n, m.d)
  for i = 1,m.n do
    for j = 1,m.d do
      dw[{i, j}] = 1.0 / (1.0 + math.exp(-m.w[{i, j}]))
    end
  end
  local out = LuaRNN.Mat(m.n, m.d, dw, alg.mat(m.n, m.d))

  if self.doBackprop then
    local k = function()
      for i = 1,m.n do
        for j = 1,m.d do
          m.dw[{i, j}] = m.dw[{i, j}] + out.w[{i, j}] * (1 - out.w[{i, j}]) * out.dw[{i, j}]
        end
      end
    end

    table.insert(self.backprop, k)
  end

  return out
end

function LuaRNN.Graph:relu(m)
  local out = LuaRNN.Mat(m.n, m.d)
  for i = 1,m.n do
    for j = 1,m.d do
      if m.w[{i, j}] < 0 then
        out.w[{i, j}] = 0
      else
        out.w[{i, j}] = m.w[{i, j}]
      end
    end
  end

  if self.doBackprop then
    local k = function()
      for i = 1,m.n do
        for j = 1,m.d do
          if m.w[{i, j}] >= 0 then
            m.dw[{i, j}] = m.dw[{i, j}] + out.dw[{i, j}]
          end
        end
      end
    end

    table.insert(self.backprop, k)
  end

  return out
end

function LuaRNN.Graph:mul(m1, m2)
  -- print("------------------------")
  -- print(m1.w)
  -- print(m2.w)
  local out
  if type(m2) == "number" then
    out = LuaRNN.Mat(m1.n, m1.d, m.w[] * m2, alg.mat(m1.n, m1.d))
  else
    out = LuaRNN.Mat(m1.n, m2.d, m1.w[] ** m2.w[], alg.mat(m1.n, m2.d))
  end

  if self.doBackprop then
    local k
    if type(m2) == "number" then
      k = function()
        m.dw = m.dw[] + out.dw[] * m2
      end
    else
      k = function()
        local b
        for i = 1,m1.n do
          for j = 1,m2.d do
            b = out.dw[{i, j}]
            for x = 1,m1.d do
              m1.dw[{i, x}] = m1.dw[{i, x}] + m2.w[{x, j}] * b
              m2.dw[{x, j}] = m2.dw[{x, j}] + m1.w[{i, x}] * b
            end
          end
        end
      end
    end

    table.insert(self.backprop, k)
  end
  -- print("mul---------")
  -- print(m1.w)
  -- print("----")
  -- print(m2.w)
  -- print("---out---")
  -- print(out.w)
  -- print("----end----")
  return out
end

function LuaRNN.Graph:add(...)
  local mats = {...}

  local out
  if type(mats[2]) ~= "number" then
    -- print("--------------")
    out = LuaRNN.Mat(mats[1].n, mats[1].d, alg.mat(mats[1].n, mats[1].d), alg.mat(mats[1].n, mats[1].d))
    local m
    -- print(mats[1].w)
    -- print("break")
    for i = 1,#mats do
      m = mats[i]
      -- print(m.w)
      for x = 1,m.n do
        for y = 1,m.d do
          out.w[{x, y}] = out.w[{x, y}] + m.w[{x, y}]
        end
      end
    end
  else
    out = LuaRNN.Mat(mats[1].n, mats[1].d, mats[1].w + mats[2])
  end

  if self.doBackprop then
    local k
    if type(mats[2]) == "number" then
      k = function()
        m[1].dw = m[1].dw[] + out.dw[]
      end
    else
      k = function()
        local m
        for i = 1,#mats do
          m = mats[i]
          for x = 1,m.n do
            for y = 1,m.d do
              m.dw[{x, y}] = m.dw[{x, y}] + out.dw[{x, y}]
            end
          end
        end
      end
    end

    table.insert(self.backprop, k)
  end

  return out
end

function LuaRNN.Graph:eltmul(m1, m2)
  local out = LuaRNN.Mat(m1.n, m2.d, m1.w[] * m2.w[], alg.mat(m1.n, m2.d))
  if self.doBackprop then
    local k = function()
      for i = 1,m1.n do
        for j = 1,m1.d do
          m1.dw[{i, j}] = m1.dw[{i, j}] + m2.w[{i, j}] * out.dw[{i, j}]
          m2.dw[{i, j}] = m2.dw[{i, j}] + m1.w[{i, j}] * out.dw[{i, j}]
        end
      end
    end

    table.insert(self.backprop, k)
  end

  return out
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
  self.hiddensizes = hiddensizes
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

function LuaRNN.LSTM:forwardprop(g, x, prev)
  local prevhd, prevcell, _ = unpack(prev)
  local hiddenprevs = {}
  local cellprevs = {}

  if #prevhd == 0 then
    for _, hdsize in pairs(self.hiddensizes) do
      table.insert(hiddenprevs, LuaRNN.Mat(hdsize, 1))
      table.insert(cellprevs, LuaRNN.Mat(hdsize, 1))
    end
  else
    hiddenprevs = prevhd
    cellprevs = prevcell
  end

  local hidden = {}
  local cell = {}
  local input = x
  local hdprev, cellprev, wix, wih, bi, wfx, wfh, bf, wox, woh, bo, wcx, wch, bc
  local h0, h1, inputgate, h2, h3, forgetgate, h4, h5, outputgate, h6, h7, cellwrite
  local retaincell, writecell, cell_d, hidden_d

  for d = 1,#self.hiddensizes do
    if d > 1 then
      input = hidden[d-1]
    end

    hdprev = hiddenprevs[d]
    cellprev = cellprevs[d]

    -- cell's input gate params
    wix = self.hdlayers[d].wix
    wih = self.hdlayers[d].wih
    bi = self.hdlayers[d].bi

    -- cell's forget gate params
    wfx = self.hdlayers[d].wfx
    wfh = self.hdlayers[d].wfh
    bf = self.hdlayers[d].bf

    -- cell's out gate params
    wox = self.hdlayers[d].wox
    woh = self.hdlayers[d].woh
    bo = self.hdlayers[d].bo

    -- cell's write params
    wcx = self.hdlayers[d].wcx
    wch = self.hdlayers[d].wch
    bc = self.hdlayers[d].bc

    -- input gate
    h0 = g:mul(wix, input)
    h1 = g:mul(wih, hdprev)
    inputgate = g:sigmoid(g:add(h0, h1, bi))

    -- forget gate
    h2 = g:mul(wfx, input)
    h3 = g:mul(wfh, hdprev)
    forgetgate = g:sigmoid(g:add(h2, h3, bf))

    -- output gate
    h4 = g:mul(wox, input)
    h5 = g:mul(woh, hdprev)
    outputgate = g:sigmoid(g:add(h4, h5, bo))

    -- write operations on cells
    h6 = g:mul(wcx, input)
    h7 = g:mul(wch, hdprev)
    cellwrite = g:tanh(g:add(h6, h7, bi))

    -- compute new cell activation
    retaincell = g:eltmul(forgetgate, cellprev) -- what do we keep from the cell
    writecell = g:eltmul(inputgate, cellwrite) -- what do we write to cell
    cell_d = g:add(retaincell, writecell) -- new cell contents

    -- compute hidden state as gated, saturated cell activations
    hidden_d = g:eltmul(outputgate, g:tanh(cell_d))

    table.insert(hidden, hidden_d)
    table.insert(cell, cell_d)
  end

  -- one decoder to outputs at end
  local output = g:add(g:mul(self.whd, hidden[#hidden]), self.bd)

  -- return cell memory, hidden representation and output
  return {hidden, cell, output}
end

LuaRNN.Solver = class("Solver")
function LuaRNN.Solver:initialize()
  self.decayrate = 0.999
  self.smootheps = 1e-8
  self.stepcache = {}
end

function LuaRNN.Solver:step(model, stepsize, regc, clipval)
  -- param update
  local numclipped = 0
  local numtot = 0

  -- model matrices
  local modelMatrices = model.matrices

  -- init step cache if needed
  if #self.stepcache == 0 then
    for _, m in pairs(modelMatrices) do
      table.insert(self.stepcache, LuaRNN.Mat(m.n, m.d))
    end
  end

  local m, s, mdwi
  for k = 1,#modelMatrices do
    m = modelMatrices[k]
    s = self.stepcache[k]

    for i = 1,m.n do
      for j = 1,m.d do
        -- rmsprop adaptive learning rate
        mdwi = m.dw[{i, j}]
        s.w[{i, j}] = s.w[{i, j}] * self.decayrate + (1.0 - self.decayrate) * math.pow(mdwi, 2)

        -- gradient clip
        if mdwi > clipval then
          mdwi = clipval
          numclipped = numclipped + 1
        end

        if mdwi < -clipval then
          mdwi = -clipval
          numclipped = numclipped + 1
        end

        numtot = numtot + 1

        -- update (and regularize)
        m.w[{i, j}] = m.w[{i, j}] - stepsize * mdwi / math.sqrt(s.w[{i, j}] + self.smootheps) - regc * m.w[{i, j}]
        m.dw[{i, j}] = 0.0 -- reset gradients for next iteration
      end
    end
  end

  local solverstats = numclipped * 1.0 / numtot
  return solverstats
end

-- #############################################################################
hiddensizes = {10, 10}
outputsize = 2

myLSTM = LuaRNN.LSTM(10, hiddensizes, outputsize)
print(myLSTM)
print(myLSTM.whd)
x1 = LuaRNN.randMat(10, 1)
x2 = LuaRNN.randMat(10, 1)
x3 = LuaRNN.randMat(10, 1)

G = LuaRNN.Graph()

prevhd = {}
prevcell = {}
out = LuaRNN.Mat(outputsize, 1)
prev = {prevhd, prevcell, out}

out1 = myLSTM:forwardprop(G, x1, prev)
out2 = myLSTM:forwardprop(G, x2, out1)
out3 = myLSTM:forwardprop(G, x3, out2)

print("layer before")
print(myLSTM.hdlayers[1].wcx)

outMat = prev[#prev]

probs = outMat:softmax()
ix_target = 1

outMat.dw = probs.w

outMat.dw[ix_target] = outMat.dw[ix_target] - 1.0

G:run_backprop()
print("finished backprop")
print(myLSTM.hdlayers[1].wcx)

s = LuaRNN.Solver()

s:step(myLSTM, 0.01, 0.00001, 5.0)

print("finished step")
print(myLSTM.hdlayers[1].wcx)


return LuaRNN
