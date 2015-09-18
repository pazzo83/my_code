using HDF5

type NNetwork
  num_layers::Int64
  sizes::Array
  biases::Array
  weights::Array

  function NNetwork(sizes::Array)
    num_layers = length(sizes)
    biases = [randn(y, 1) for y in sizes[2:end]]
    weights = [randn(y, x) for (x, y) in zip(sizes[1:end-1], sizes[2:end])]
    new(num_layers, sizes, biases, weights)
  end
end

function cost_derivative(output_activations, y)
  return (output_activations - y)
end

function feed_forward(network::NNetwork, a)
  for (b, w) in zip(network.biases, network.weights)
    a = sigmoid((w * a) + b)
  end

  return a
end

function SGD(network::NNetwork, training_data, epochs, mini_batch_size, eta, test_data = None)
  if isdefined(:test_data)
    n_test = length(test_data)
  end

  n = length(training_data)
  for j = 1:epochs
    shuffle(training_data)
    mini_batches = [training_data[k:k + mini_batch_size - 1] for k in 1:mini_batch_size:n]
    for mini_batch in mini_batches
      update_mini_batch!(network, mini_batch, eta)
    end

    if isdefined(:test_data)
      println("Epoch $j: $(evaluate(network, test_data)) / $n_test")
    else
      println("Epoch $j complete")
    end
  end
end

function backprop(network::NNetwork, x, y)
  nabla_b = [zeros(size(b)) for b in network.biases]
  nabla_w = [zeros(size(w)) for w in network.weights]

  # feed forward
  activation = x
  activations = Array[collect(x)]
  zs = Array[]
  for (b, w) in zip(network.biases, network.weights)
    z = w * activation + b
    push!(zs, z)

    activation = sigmoid(z)
    push!(activations, activation)
  end

  #backwards pass
  delta = cost_derivative(activations[end], y) .* sigmoid_prime(zs[end])
  nabla_b[end] = delta
  nabla_w[end] = delta * transpose(activations[end - 1])
  for layer = 1:network.num_layers - 2
    z = zs[end - layer]
    sp = sigmoid_prime(z)
    delta = (transpose(network.weights[end - layer + 1]) * delta) .* sp
    nabla_b[end - layer] = delta
    nabla_w[end - layer] = delta * transpose(activations[end - layer - 1])
  end

  return (nabla_b, nabla_w)
end

function update_mini_batch!(network::NNetwork, mini_batch, eta)
  nabla_b = [zeros(size(b)) for b in network.biases]
  nabla_w = [zeros(size(w)) for w in network.weights]

  for (x, y) in mini_batch
    delta_nabla_b, delta_nabla_w = backprop(network, x, y)
    nabla_b = [nb + dnb for (nb, dnb) in zip(nabla_b, delta_nabla_b)]
    nabla_w = [nw + dnw for (nw, dnw) in zip(nabla_w, delta_nabla_w)]
  end

  network.weights = [w - (eta / length(mini_batch)) .* nw for (w, nw) in zip(network.weights, nabla_w)]
  network.biases = [b - (eta / length(mini_batch)) .* nb for (b, nb) in zip(network.biases, nabla_b)]
end

function evaluate(network::NNetwork, test_data)
  test_results = [(indmax(feed_forward(network, x)), y) for (x, y) in test_data]
  testing = sum([convert(Int64, ((x - 1) == y)) for (x, y) in test_results])
  return testing
end

function sigmoid(z)
  return 1.0 ./ (1.0 + exp(-z))
end

function sigmoid_prime(z)
  return sigmoid(z) .* (1 - sigmoid(z))
end

function vectorized_result(j)
  e = zeros(10)
  e[j] = 1.0
  return e
end

h5_file_location = "/Users/christopheralexander/Julia/machine_learning/nnetwork_data.hdf5"

training_inputs, training_results, validation_inputs, validation_results, test_inputs, test_results = h5open(h5_file_location) do file
  a = read(file, "training_inputs")
  b = read(file, "training_results")
  c = read(file, "validation_inputs")
  d = read(file, "validation_results")
  e = read(file, "test_inputs")
  f = read(file, "test_results")
  a, b, c, d, e, f
end

batch_size = 784
training_inputs = [training_inputs[k:k + batch_size - 1] for k = 1:batch_size:length(training_inputs)]
training_results = [vectorized_result(y + 1) for y in training_results]

validation_inputs = [validation_inputs[k:k + batch_size - 1] for k = 1:batch_size:length(validation_inputs)]
test_inputs = [test_inputs[k:k + batch_size - 1] for k = 1:batch_size:length(test_inputs)]

training_data = collect(zip(training_inputs, training_results))
validation_data = collect(zip(validation_inputs, validation_results))
test_data = collect(zip(test_inputs, test_results))

# initialize
net = NNetwork([784, 30, 10])
SGD(net, training_data, 30, 10, 3.0, test_data)
