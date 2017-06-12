abstract type NamedTable end

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

@generated function (::Type{NT}){NT <: NamedTable}(args...)
  n = length(args)
  aexprs = [ :(args[$i]) for i = 1:n ]
  return gen_namedtable_ctor_body(n, aexprs)
end

function create_namedtable_type(fields::Vector{Symbol})
  mod = current_module()
  escaped_fieldnames = [replace(string(i), "_", "__") for i in fields]
  name = Symbol( string("_NT_", join(escaped_fieldnames, "_")) )
  if !isdefined(mod, name)
    len = length(fields)
    types = [Symbol("T$n") for n = 1:len]
    tfields = [ Expr(:(::), Symbol( fields[n] ), Symbol( "T$n" )) for n = 1:len]
    def = Expr(:type, true, Expr( :(<:), Expr(:curly, name, types...), GlobalRef(Main, :NamedTable)), Expr(:block, tfields..., Expr(:tuple)))
    eval(mod, def)
  end
  return getfield(mod, name)
end

function make_table(exprs::Vector)
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

  ty = create_namedtable_type(fields)

  if ~construct
    if len == 0
      return ty
    end
    return Expr( :curly, ty, typs...)
  else
    return Expr(:call, ty, values...)
  end
end

macro NTable(expr...)
  return make_table(collect(expr))
end

ncols(ntbl::NamedTable) = length(fieldnames(ntbl))

columns(ntbl::NamedTable) = [ntbl[col] for col in fieldnames(ntbl)]

Base.length(ntbl::NamedTable) = length(ntbl[fieldnames(ntbl)[1]])
Base.getindex(ntbl::NamedTable, s::Symbol) = getfield(ntbl, s)

function Base.getindex(ntbl::NamedTable, i::Int)
  typ = typeof(ntbl)
  fields = Any[]
  for col in fieldnames(ntbl)
    push!(fields, [getfield(ntbl, col)[i]])
  end
  return typ(fields...)
end

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
