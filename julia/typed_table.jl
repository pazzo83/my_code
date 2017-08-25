using DataStructures

abstract type NamedTable{T} end
abstract type NamedRow end

struct ParseNode{T} end

escape( e::Expr ) = esc( e )
escape(e) = e

function trans(::Union{Type{ParseNode{:(=)}}, Type{ParseNode{:kw}}}, expr::Expr)
  if ~(isa(expr.args[2], Expr)) || ~(isa(expr.args[2].args, Vector))
    throw(ArgumentError("must initialize with a vector"))
  end
  sym, typ = trans(expr.args[1])
  return (sym, typ, escape(expr.args[2]))
end

function trans(::Type{ParseNode{:(::)}}, expr::Expr)
  if length(expr.args) > 1
    return (expr.args[1], Expr(:curly, Vector, expr.args[2]), nothing)
  else
    return (nothing, expr.args[1], nothing)
  end
end

function trans(::Type{ParseNode{:vect}}, expr::Expr)
  return (expr.args, nothing, nothing)
end

function trans(expr::Expr)
  trans(ParseNode{expr.head}, expr)
end

function trans(sym::Symbol)
  return (sym, nothing, nothing)
end

function gen_namedtable_ctor_body(n::Int, args)
  types = [ :(typeof($x)) for x in args ]
  cnvt = [ :(convert(fieldtype(TT, $x), $(args[x]))) for x = 1:n ]
  if n == 0
    texpr = :T
  else
    texpr = :(NT{$(types...)})
  end
  tcond = :(isa(NT, UnionAll))
  quote
    if $n > 1
      len = length(args[1])
      for x in args[2:end]
        if length(x) != len
          throw(ArgumentError("Row mismatch"))
        end
      end
    end
    if $tcond
      TT = $texpr
    else
      TT = NT
    end
    if nfields(TT) !== $n
      throw(ArgumentError("wrong number of args"))
    end

    $(Expr(:new, :TT, cnvt...))
  end
end

function gen_namedrow_ctor_body(n::Int, args)
  types = [ :(typeof($x)) for x in args ]
  cnvt = [ :(convert(fieldtype(TT, $x), $(args[x]))) for x = 1:n ]
  if n == 0
    texpr = :T
  else
    texpr = :(NR{$(types...)})
  end
  tcond = :(isa(NR, UnionAll))
  quote
    if $tcond
      TT = $texpr
    else
      TT = NT
    end
    if nfields(TT) !== $n
      throw(ArgumentError("wrong number of args"))
    end

    $(Expr(:new, :TT, cnvt...))
  end
end

@generated function (::Type{NT})(args...) where NT <: NamedTable{T} where T
  n = length(args)
  aexprs = [ :(args[$i]) for i = 1:n ]
  return gen_namedtable_ctor_body(n, aexprs)
end

@generated function (::Type{NR})(args...) where NR <: NamedRow
  n = length(args)
  aexprs = [ :(args[$i]) for i = 1:n ]

  return gen_namedrow_ctor_body(n, aexprs)
end

function create_namedrow_type(types::Vector{Symbol}, tfields::Vector{Expr}, rowname::Symbol)
  mod = current_module()
  rowexpr = Expr(:curly, rowname, types...)
  def = Expr(:type, false, Expr( :(<:), rowexpr, GlobalRef(Main, :NamedRow)), Expr(:block, tfields..., Expr(:tuple)))
  eval(mod, def)

  return getfield(mod, rowname)
end

function create_namedtable_type(fields::Vector{Symbol})
  mod = current_module()
  escaped_fieldnames = [replace(string(i), "_", "__") for i in fields]
  name = Symbol( string("_NTable_", join(escaped_fieldnames, "_")) )
  rowname = Symbol( string("_NRow_", join(escaped_fieldnames, "_")) )
  if !isdefined(mod, name)
    len = length(fields)
    types = [Symbol("T$n") for n = 1:len]
    tfields = [ Expr(:(::), Symbol( fields[n] ), Symbol( "T$n" )) for n = 1:len]
    rownametype = create_namedrow_type(types, tfields, rowname)
    def = Expr(:type, true, Expr( :(<:), Expr(:curly, name, types...), Expr(:curly, GlobalRef(Main, :NamedTable), rowname)), Expr(:block, tfields..., Expr(:tuple)))
    eval(mod, def)
  end
  return getfield(mod, name)
end

function process_table_args(::Type{ParseNode{:vect}}, exprs::Vector{Expr})
  sym, typ, val = trans(exprs[1])
  if length(sym) != length(exprs[2:end])
    error("Wrong number of columns")
  end
  fields = map(Symbol, sym)
  values = [escape(x) for x in exprs[2:end]]

  return fields, values, Array{Any}(length(exprs)), true
end

function process_table_args(::Union{Type{ParseNode{:(=)}}, Type{ParseNode{:kw}}, Type{ParseNode{:(::)}}}, exprs::Vector{Expr})
  len     = length(exprs)
  fields  = Array{Symbol}(len)
  values  = Array{Any}(len)
  typs    = Array{Any}(len)

  construct = false
  
  for i in eachindex(exprs)
    expr = exprs[i]
    sym, typ, val = trans(expr)
    if construct == true && val == nothing || ( i > 1 && construct == false && val != nothing)
      error("Table must be initialized with vectors")
    end
    construct = val != nothing
    fields[i] = sym != nothing ? sym : Symbol("_$(i)_")
    typs[i] = typ
    values[i] = ( typ != nothing ) ? Expr(:call, :convert, typ, val) : val
  end
  return fields, values, typs, construct
end

function make_table(exprs::Vector{Expr})
  fields, values, typs, construct = process_table_args(ParseNode{exprs[1].head}, exprs)
  ty = create_namedtable_type(fields)

  if ~construct
    if length(exprs) == 0
      return ty
    end
    return Expr( :curly, ty, typs...)
  else
    return Expr(:call, ty, values...)
  end
end

function make_table(colnames::Symbol, cols)
  
  ty = create_namedtable_type(eval(colnames))

  return Expr(:call, ty, eval(cols)...)
end

macro NTable(expr::Expr...)
  return make_table(collect(expr))
end

macro NTable(sym::Symbol, expr)
  return make_table(sym, expr)
end

@generated function ith_all(i, n::NamedTable)
    Expr(:block,
         :(@Base._inline_meta),
         Expr(:tuple, [ Expr(:ref, Expr(:., :n, Expr(:quote, fieldname(n,f))), :i) for f = 1:nfields(n) ]...))
end

ncols(ntbl::NamedTable) = length(fieldnames(ntbl))

columns(ntbl::NamedTable) = [ntbl[col] for col in fieldnames(ntbl)]

Base.length(ntbl::NamedTable) = length(ntbl[fieldnames(ntbl)[1]])
Base.getindex(ntbl::NamedTable, s::Symbol) = getfield(ntbl, s)
Base.values(nrow::NamedRow) = [ getfield(nrow, i) for i in 1:nfields(nrow) ]

# function Base.getindex(ntbl::NamedTable, i::Int)
#   typ = typeof(ntbl)
#   fields = Any[]
#   for col in fieldnames(ntbl)
#     push!(fields, [getfield(ntbl, col)[i]])
#   end
#   return typ(fields...)
# end
Base.getindex(ntbl::NamedTable{T}, i::Int) where T = T(ith_all(i, ntbl)...)
Base.getindex(ntbl::NT, v::Vector{Int}) where {NT <: NamedTable} = NT(map(x -> x[v], columns(ntbl))...)

# from IndexedTables.jl
filt_by_col!(f, col, indxs) = filter!(i->f(col[i]), indxs)
function Base.select(ntbl::NT, conditions::Pair...) where {NT <: NamedTable}
  indxs = [1:length(ntbl);]
  for (c, f) in conditions
    filt_by_col!(f, ntbl[c], indxs)
  end
  return NT(map(x -> x[indxs], columns(ntbl))...)
end

function Base.show(io::IO, ntbl::NamedTable)
  n = length(ntbl)
  rows = n > 20 ? [1:10; (n-9):n] : [1:n;]
  nc = ncols(ntbl)
  reprs = [ sprint(io -> showcompact(io, ntbl[col][i])) for i in rows, col in fieldnames(ntbl)]
  names = map(string, fieldnames(ntbl))
  widths = [ max(strwidth(names[c]), maximum(map(strwidth, reprs[:, c]))) for c in 1:nc ]
  for c in 1:nc
    print(io, rpad(names[c], widths[c] + (c == nc ? 1 : 2), " "))
  end
  println(io)
  print(io, "─"^(sum(widths)+2*nc-1))
  for r in 1:size(reprs, 1)
    println(io)
    for c in 1:nc
      print(io, c == nc ? reprs[r, c] : rpad(reprs[r, c], widths[c] + 2, " "))
    end
  end
end

function Base.show(io::IO, nrow::NamedRow)
    print(io, "(")
    first = true
    for (k, v) in zip(fieldnames(nrow), values(nrow))
        !first && print(io, ", ")
        print(io, k, " = "); show(io, v)
        first = false
    end
    print(io, ")")
end

function build_row_map(col::Vector{T}) where T
    # colmap = Dict{T, Int}()
    colmap = DefaultDict{T, Vector{Int}}(() -> Int[])
    
    for i in eachindex(col)
        push!(colmap[col[i]], i)
    end
    return colmap
end

function testjoin(ntbl1::NamedTable, ntbl2::NamedTable, on::Symbol)
    map1 = build_row_map(ntbl1[on])
    map2 = build_row_map(ntbl2[on])
    
    set1 = Set(keys(map1))
    set2 = Set(keys(map2))

    intersectmap = intersect(set1, set2)
    tbl1indices = Vector{Int}()
    tbl2indices = Vector{Int}()
    for val in intersectmap
        tbl1vals = map1[val]
        tbl2vals = map2[val]
        lenghttouse = min(length(tbl1vals), length(tbl2vals))
        append!(tbl1indices, tbl1vals[1:lenghttouse])
        append!(tbl2indices, tbl2vals[1:lenghttouse])
    end
    sortindices = sortperm(tbl1indices)
    tbl1indices = tbl1indices[sortindices]
    tbl2indices = tbl2indices[sortindices]

    # now we have to create the joined tbl type
    tblfields = fieldnames(ntbl1)
    tbl2fields = fieldnames(ntbl2)
    for v in tbl2fields
        if v != on
            if v in tblfields
                symbv = Symbol("$(v)1")
            else
                symbv = v
            end
            push!(tblfields, symbv)
        end
    end
    NT = create_namedtable_type(tblfields)
    tbl2colsindicies = [i for i in eachindex(tbl2fields) if tbl2fields[i] != on]
    #fulltblcols = vcat(map(x -> x[tbl1indices], columns(ntbl1)), map(y -> y[tbl2indices], columns(ntbl2)[tbl2colsindicies]))

    return NT(map(x -> x[tbl1indices], columns(ntbl1))..., map(y -> y[tbl2indices], columns(ntbl2)[tbl2colsindicies])...)
end

test_some_stuff(::NamedTable{T}) where T = T
# test_do_rows(tbl::NamedTable{T}) where T = []
