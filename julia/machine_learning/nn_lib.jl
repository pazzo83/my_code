const INPUT_DIM = 2

abstract Network
abstract Layer
abstract Loss
abstract ActivationType

type LinearActivation <: ActivationType end
type ReluActivation <: ActivationType end
type SoftmaxActivation <: ActivationType end

_identity(x::Array) = x

function _softmax(x::Array)
  z = exp(x .- maximum(x, ndims(x)))
  return z ./ sum(z, ndims(z))
end

build_activation(::LinearActivation) = _identity
build_activation(::SoftmaxActivation) = _softmax

type InputLayer{A <: ActivationType, F <: Function} <: Layer
  size::Int
  inputs::Dict{String, Int}
  name::String
  activation::A
  activate::F
  params::Vector
end

function InputLayer(sz::Int, input::Int, name::String, activation::ActivationType = LinearActivation())
  inputs = Dict("out" => input)
  activate = build_activation(activation)

  InputLayer{typeof(activation), typeof(activate)}(sz, inputs, name, activation, activate, [])
end

type FeedForwardLayer{A <: ActivationType, F <: Function} <: Layer
  size::Int
  inputs::Dict{String, Int}
  name::String
  activation::A
  activate::F
  params::Vector{Tuple{String, Array}}
end

function FeedForwardLayer(sz::Int, input::Dict{String, Int}, name::String, activation::ActivationType = SoftmaxActivation())
  fn = build_activation(activation)
  FeedForwardLayer{typeof(activation), typeof(fn)}(sz, input, name, activation, fn, Tuple{String, Array}[])
end

setup!(layer::InputLayer) = layer

function setup!(layer::FeedForwardLayer)
  for (name, sz) in layer.inputs
    label = length(layer.inputs) == 1 ? "w" : "w_$(name)"
    addweights!(layer, label, sz)
    addbias!(layer, label, sz)
  end

  return layer
end

function addweights!(layer::Layer, label::String, nin::Int, nout::Int = layer.size, mn::Int = 0)
  glorot = 1.0 / sqrt(nin + nout)

  push!(layer.params, (label, mn + glorot * randn(nin, nout)))

  return layer
end

function addbias!(layer::Layer, label::String, sz::Int, mn::Int = 0, std::Int = 1)
  push!(layer.params, (label, randn(sz)))

  return layer
end


type Classifier <: Network
  layers::Vector{Layer}
  losses::Vector{Loss}
  graphs::Dict
  functions::Dict

  function Classifier(layers_list::Vector{Int})
    layers = Layer[]
    net = new(layers, Loss[], Dict(), Dict())
    for i in eachindex(layers_list)
      isoutput = i == length(layers_list) ? true : false
      addlayer!(net, layers_list[i], isoutput)
    end

    return net
  end
end

function addlayer!(net::Network, layer::Int, isoutput::Bool = false)
  if isempty(net.layers)
    # form = "input"
    layer = InputLayer(layer, 0, "in")
  else
    inputs = Dict(outputname(net.layers[end]) => net.layers[end].size)
    if isoutput
      layer = FeedForwardLayer(layer, inputs, "out")
    else
      layer = FeedForwardLayer(layer, inputs, "hid" * string(length(net.layers)), ReluActivation())
    end
  end

  setup!(layer)

  push!(net.layers, layer)

  return net
end

outputname(l::Layer, nm::String = "out") = "$(l.name):$nm"

function main()
  net = Classifier([100, 10])
  return net
end
