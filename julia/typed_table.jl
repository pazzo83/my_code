abstract type NamedTuple end

struct ParseNode{T} end

escape(e) = e

function trans(::Union{Type{ParseNode{:(=)}}, Type{ParseNode{:kw}}}, expr::Expr)
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

function gen_namedtuple_ctor_body(n::Int, args)
  types = [ :(typeof($x)) for x in args ]
  cnvt = [ :(convert(fieldtype(TT, $x), $(args[x]))) for x = 1:n ]
  if n == 0
    texpr = :T
  else
    texpr = :(NT{$(types...)})
  end
  tcond = :(isa(NT, UnionAll))
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

@generated function (::Type{NT}){NT <: NamedTuple}(args...)
  n = length(args)
  aexprs = [ :(args[$i]) for i = 1:n ]
  return gen_namedtuple_ctor_body(n, aexprs)
end

function create_namedtuple_type(fields::Vector{Symbol})
  mod = current_module()
  escaped_fieldnames = [replace(string(i), "_", "__") for i in fields]
  name = Symbol( string("_NT_", join(escaped_fieldnames, "_")) )
  if !isdefined(mod, name)
    len = length(fields)
    types = [Symbol("T$n") for n = 1:len]
    tfields = [ Expr(:(::), Symbol( fields[n] ), Symbol( "T$n" )) for n = 1:len]
    def = Expr(:type, true, Expr( :(<:), Expr(:curly, name, types...), GlobalRef(Main, :NamedTuple)), Expr(:block, tfields..., Expr(:tuple)))
    println(def)
    eval(mod, def)
  end
  return getfield(mod, name)
end

function make_tuple(exprs::Vector)
  len     = length(exprs)
  fields  = Array{Symbol}(len)
  values  = Array{Any}(len)
  typs    = Array{Any}(len)

  construct = false

  for i in eachindex(exprs)
    expr = exprs[i]
    sym, typ, val = trans(expr)

    construct = val != nothing
    fields[i] = sym != nothing ? sym : Symbol("_$(i)_")
    typs[i] = typ
    values[i] = ( typ != nothing ) ? Expr(:call, :convert, typ, val) : val
  end

  ty = create_namedtuple_type(fields)

  if ~construct
    if len == 0
      return ty
    end
    return Expr( :curly, ty, typs...)
  else
    return Expr(:call, ty, values...)
  end
end

macro NT(expr...)
  return make_tuple(collect(expr))
end
