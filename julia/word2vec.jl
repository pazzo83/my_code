using DataStructures
using StatsFuns

mutable struct Vocab
  vcount::Int
  vindex::Int
  sampleint::Int
end

Vocab(vcount::Int, vindex::Int) = Vocab(vcount, vindex, 0)

mutable struct KeyedVectors
  syn0::Matrix{Float64}
  index2word::Vector{String}
  vocab::Dict{String, Vocab}
end

KeyedVectors() = KeyedVectors(Matrix{Float64}(0,0), String[], Dict{String, Vocab}())

mutable struct Word2Vec
  sentences::Vector{Vector{String}}
  sg::Int
  vectorsize::Int
  layer1size::Int
  alpha::Float64
  min_alpha_yet_reached::Float64
  window::Int
  max_vocab_size::Int
  seed::Int
  mincount::Int
  sample::Float64
  workers::Int
  minalpha::Float64
  hs::Int
  negative::Int
  cbowmean::Int
  iterations::Int
  nullword::Int
  traincount::Int
  total_train_time::Int
  sortedvocab::Int
  batchwords::Int
  model_trimmed_post_training::Bool
  corpuscount::Int
  rawvocab::DataStructures.DefaultDict{String, Int, Int}
  wv::KeyedVectors
  cumtable::Vector{Int}
  syn1neg::Matrix{Float64}
  syn0_lockf::Vector{Float64}
  neglabels::Vector{Int}
  random::MersenneTwister
end

function Word2Vec(sentences::Vector{Vector{String}}, sz::Int = 100, alpha::Float64 = 0.025, window::Int = 1, mincount::Int = 1, maxvocabsize::Int = -1,
                  sample::Float64 = 1e-3, seed::Int = 1, workers::Int = 3, minalpha::Float64 = 0.0001, sg::Int = 0, hs::Int = 0, negative::Int = 5,
                  cbowmean::Int = 1, iterations::Int = 5, nullword::Int = 0, sortedvocab::Int = 1, batchwords::Int = 5)

  rawvocab = DefaultDict{String, Int}(0)
  cumtable = Vector{Int}()
  syn1neg = Matrix{Float64}(0, 0)
  syn0_lockf = Vector{Float64}()
  wv = KeyedVectors()
  vectorsize = sz
  layer1size = sz
  traincount = 0
  total_train_time = 0
  model_trimmed_post_training = false
  corpuscount = 0
  neglabels = Vector{Int}()
  random = MersenneTwister(seed)

  return Word2Vec(sentences, sg, vectorsize, layer1size, alpha, alpha, window, maxvocabsize, seed, mincount, sample, workers,
                  minalpha, hs, negative, cbowmean, iterations, nullword, traincount, total_train_time, sortedvocab, batchwords, model_trimmed_post_training,
                  corpuscount, rawvocab, wv, cumtable, syn1neg, syn0_lockf, neglabels, random)
end

keep_vocab_item(w2v::Word2Vec, count::Int) = count >= w2v.mincount

function preprocess!(w2v::Word2Vec)
  buildvocab!(w2v)
  return w2v
end

function make_cum_table!(w2v::Word2Vec)
  power = 0.75
  domain = 2 ^ 31 - 1

  vocabsize = length(w2v.wv.index2word)
  w2v.cumtable = zeros(Int, vocabsize)

  # compute sum of all power
  train_words_pow = 0.0
  for wordindex in eachindex(w2v.wv.index2word)
    train_words_pow += w2v.wv.vocab[w2v.wv.index2word[wordindex]].vcount ^ power
  end
  cumulative = 0.0
  for wordindex in eachindex(w2v.wv.index2word)
    cumulative += w2v.wv.vocab[w2v.wv.index2word[wordindex]].vcount ^ power
    w2v.cumtable[wordindex] = round(Int, cumulative / train_words_pow * domain)
  end

  if length(w2v.cumtable) > 0
    w2v.cumtable[end] == domain || error("error creating cum table")
  end

  return w2v
end

function seededvector(w2v::Word2Vec, seedstring::String)
  mt = MersenneTwister(hash(string) & 0xffffffff)
  return (rand(mt, w2v.vectorsize) - 0.5) / w2v.vectorsize
end

function resetweights!(w2v::Word2Vec)
  w2v.wv.syn0 = Matrix{Float64}(w2v.vectorsize, length(w2v.wv.vocab))

  for i = 1:length(w2v.wv.vocab)
    w2v.wv.syn0[:, i] = seededvector(w2v, w2v.wv.index2word[i] * string(w2v.seed))
  end

  # todo hs
  if w2v.negative > 0
    w2v.syn1neg = zeros(w2v.layer1size, length(w2v.wv.vocab))
  end

  # wv.syn0norm

  w2v.syn0_lockf = ones(length(w2v.wv.vocab))

  return w2v
end

function buildvocab!(w2v::Word2Vec)
  scanvocab!(w2v, 10000)
  scalevocab!(w2v)
  finalize_vocab!(w2v)
  return w2v
end

function scanvocab!(w2v::Word2Vec, progressper::Int)
  totalwords = 0
  minreduce = 1

  for sentence_no in eachindex(w2v.sentences)
    for word in w2v.sentences[sentence_no]
      w2v.rawvocab[word] += 1
    end

    # TODO max vocab
  end
  totalwords += sum(values(w2v.rawvocab))
  w2v.corpuscount += 1
  return w2v
end

function scalevocab!(w2v::Word2Vec)
  # TODO work with update
  retain_total = 0
  retain_words = String[]
  droptotal = dropunique = 0

  for (word, v) in w2v.rawvocab
    if keep_vocab_item(w2v, v)
      push!(retain_words, word)
      retain_total += v
      w2v.wv.vocab[word] = Vocab(v, length(w2v.wv.index2word))
      push!(w2v.wv.index2word, word)
    else
      dropunique += 1
      droptotal += v
    end
  end

  original_unique_total = length(retain_words) + dropunique
  retain_unique_pct = length(retain_words) * 100 / max(original_unique_total, 1)

  original_total = retain_total + droptotal
  retain_pct = retain_total * 100 / max(original_total, 1)

  # precalculate each vocab item's threshold for sampling
  threshold_count = retain_total

  downsample_total = downsample_unique = 0
  for i in eachindex(retain_words)
    w = retain_words[i]
    v = w2v.rawvocab[w]
    word_probability = (sqrt(v / threshold_count) + 1) * (threshold_count / v)
    if word_probability < 1.0
      downsample_unique += 1
      downsample_total += word_probability * v
    else
      word_probability = 1.0
      downsample_total += v
    end
    w2v.wv.vocab[w].sampleint = round(Int, word_probability * 2 ^ 32)
  end

  # delete the raw vocab
  w2v.rawvocab = DefaultDict{String, Int}(0)

  return Dict{String, Int}("dropunique" => dropunique, "retain_total" => retain_total, "downsample_unique" => downsample_unique, "downsample_total" => downsample_total)
end

function sortvocab!(w2v::Word2Vec)
  if length(w2v.wv.syn0) > 0
    error("Cannot sort vocab after model weights already initialized")
  end

  sort!(w2v.wv.index2word, by = word -> w2v.wv.vocab[word].vcount, rev=true)

  for i in eachindex(w2v.wv.index2word)
    word = w2v.wv.index2word[i]
    w2v.wv.vocab[word].vindex = i
  end

  return w2v
end

function finalize_vocab!(w2v::Word2Vec)
  if length(w2v.wv.index2word) == 0
    scalevocab!(w2v)
  end

  if w2v.sortedvocab == 1
    sortvocab!(w2v)
  end

  # add hs
  if w2v.negative > 0
    make_cum_table!(w2v)
  end

  resetweights!(w2v)

  return w2v
end

function train_batch_cbow!(w2v::Word2Vec, sentences::Vector{Vector{String}}, alpha::Float64, work::Vector{Float64}, neu1::Vector{Float64})
  result = 0
  for sentence in sentences
    wordvocabs = [w2v.wv.vocab[w] for w in sentence if haskey(w2v.wv.vocab, w) && w2v.wv.vocab[w].sampleint > rand(w2v.random) * 2 ^ 32]
    for pos in eachindex(wordvocabs)
      word = wordvocabs[pos]
      reducedwindow = rand(w2v.random, 0:w2v.window-1)
      _start = max(1, pos - w2v.window + reducedwindow)
      iter = _start:(pos-1 + w2v.window - reducedwindow)
      windowpos = zip(wordvocabs[iter], iter)
      word2indices = [word2.vindex for (word2, pos2) in windowpos if pos2 != pos]
      l1 = sum(w2v.wv.syn0[:, word2indices], 2)
      if ~isempty(word2indices) && w2v.cbowmean > 0
        l1 /= length(word2indices)
      end

      train_cbow_pair!(w2v, word, word2indices, l1, alpha)
    end
    result += length(wordvocabs)
  end

  return result
end

function train_cbow_pair!(w2v::Word2Vec, word::Vocab, word2indices::Vector{Int}, l1::Array{Float64}, alpha::Float64)
  learnhidden = true
  learnvectors = true
  neu1e = zeros(l1)

  # only negative
  wordindices = [word.vindex]
  while length(wordindices) < w2v.negative + 1
    w = searchsortedfirst(w2v.cumtable, rand(w2v.random, 0:w2v.cumtable[end]))
    if w != word.vindex
      push!(wordindices, w)
    end
  end
  l2b = w2v.syn1neg[:, wordindices]
  fb = logistic(sum(l1' .* l2b')) # propogate hidden to output
  gb = (w2v.neglabels - fb) * alpha
  if learnhidden
    l2b2 = w2v.syn1neg[:, wordindices]
    BLAS.gemm!('N', 'T', 1.0, l1, gb, 1.0, l2b2)
    w2v.syn1neg[:, wordindices] = l2b2
  end
  neu1e += sum(gb' .* l2b)

  if learnvectors
    if w2v.cbowmean == 0 && ~isempty(word2indices)
      neu1e /= length(word2indices)
    end
    for i in word2indices
      w2v.wv.syn0[:, i] += neu1e * w2v.syn0_lockf[i]
    end
  end
  return neu1e
end

_raw_word_count(job) = sum(length(sentence) for sentence in job)

function _do_train_job(w2v::Word2Vec, sentences::Vector{Vector{String}}, alpha::Float64, inits::NTuple{2, Vector{Float64}})
  work, neu1 = inits
  tally = 0
  # no sg yet
  tally += train_batch_cbow!(w2v, sentences, alpha, work, neu1)

  return tally, _raw_word_count(sentences)
end

function train!(w2v::Word2Vec, totalexamples::Int, epochs::Int)
  queuefactor = 2
  wordcount = 0
  if w2v.negative > 0
    w2v.neglabels = zeros(Int, w2v.negative + 1)
    w2v.neglabels[1] = 1
  end

  startalpha = w2v.alpha
  endalpha = w2v.minalpha

  jobtally = 0
  if epochs > 1
    sentences = repeat(w2v.sentences, outer=[epochs])
    totalexamples = totalexamples * epochs
  else
    sentences = w2v.sentences
  end

  jobs = Channel{Tuple{Vector{Vector{String}}, Float64}}(queuefactor * w2v.workers)
  progressqueue = Channel{NTuple{3, Int}}(queuefactor * w2v.workers)

  function workerloop()
    work = zeros(w2v.layer1size)
    neu1 = zeros(w2v.layer1size)

    jobsprocessed = 0
    tally = 0
    rawtally = 0
    for (_sentences, alpha) in jobs
      # do some stuff
      tally, rawtally = _do_train_job(w2v, sentences, alpha, (work, neu1))
      put!(progressqueue, (length(_sentences), tally, rawtally))
      jobsprocessed += 1
    end
  end

  function jobproducer()
    job_batch, batchsize = Vector{Vector{String}}(), 0
    pushedwords, pushedexamples = 0, 0
    nextalpha = startalpha
    w2v.min_alpha_yet_reached = nextalpha
    jobno = 0
    for sent_idx in eachindex(sentences)
      sentence = sentences[sent_idx]
      sentence_length = _raw_word_count([sentence])

      # will sentence fit
      if batchsize + sentence_length <= w2v.batchwords
        # yes
        push!(job_batch, sentence)
        batchsize += sentence_length
      else
        # no - submit job
        jobno += 1
        put!(jobs, (job_batch, nextalpha))

        # update learning rate for next job
        if endalpha < nextalpha
          # total examples for now
          pushedexamples += length(job_batch)
          progress = 1.0 * pushedwords / totalexamples

          nextalpha = startalpha - (startalpha - endalpha) * progress
          nextalpha = max(endalpha, nextalpha)
        end
        job_batch, batchsize = [sentence], sentence_length
      end
    end

    # add the last job too
    if ~isempty(job_batch)
      jobno += 1
      put!(jobs, (job_batch, nextalpha))
    end
  end

  examplecount, trained_word_count, raw_word_count = 0, 0, wordcount
  @schedule jobproducer()
  for i = 1:w2v.workers
    @schedule workerloop()
  end

  while true
  # for (examples, trained_words, raw_words) in progressqueue
    examples, trained_words, raw_words = take!(progressqueue)
    jobtally += 1

    # update progress stats
    examplecount += examples
    trained_word_count += trained_words
    raw_word_count += raw_words

    # log progress
    # println("$examplecount $trained_word_count $raw_word_count")
    if ~isready(progressqueue)
      break
    end
  end

  # checks
  w2v.traincount += 1
  return trained_word_count
end
