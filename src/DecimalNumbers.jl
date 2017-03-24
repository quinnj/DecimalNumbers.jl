module DecimalNumbers

export Decimal

importall Base.Operators

immutable Decimal{T <: Integer}
    value::T
    exp::T
end

Decimal{T, T2}(value::T, exp::T2) = Decimal(promote(value, exp)...)

# normalize
function normalize{T <: Integer}(x::T)
    value = x
    exp = Z = zero(T)
    for d in digits(x)
        if d == Z
            value = div(value, T(10))
            exp += T(1)
        else
            break
        end
    end
    return value, exp
end

function Decimal{T}(d::Decimal{T})
    v, e = normalize(d.value)
    return Decimal(v, e + d.exp)
end

Base.convert{T, T2}(::Type{Decimal{T}}, d::Decimal{T2}) = Decimal(T(d.value), T(d.exp))

# from int
Base.convert{T}(::Type{Decimal{T}}, x) = convert(Decimal, x)
function Base.convert{T <: Integer}(::Type{Decimal}, x::T)
    x == T(0) && return Decimal(T(0), T(0))
    return Decimal(normalize(x)...)
end

# to int
function Base.convert{T <: Integer}(::Type{T}, d::Decimal)
    d.exp < 0 && throw(InexactError())
    return T(d.value * T(10)^d.exp)
end

Base.zero{T}(::Union{Decimal{T}, Type{Decimal{T}}}) = Decimal(zero(T))
Base.one{T}(::Union{Decimal{T}, Type{Decimal{T}}}) = Decimal(one(T))

float2int(::Type{BigFloat}) = BigInt
float2int(::Type{Float64}) = Int64
float2int(::Type{Float32}) = Int32
float2int(::Type{Float16}) = Int16

# from float
function Base.convert{T <: AbstractFloat}(::Type{Decimal}, x::T)
    # easy if float is int
    trunc(x) == x && return Decimal(float2int(T)(x))
    # otherwise, go string route for now
    return parse(Decimal{float2int(T)}, string(x))
end

# to float
Base.convert{T <: AbstractFloat}(::Type{T}, d::Decimal) = T(d.value * exp10(d.exp))

function ==(a::Decimal, b::Decimal)
    aa, bb = _scale(a, b)
    return aa.value == bb.value && aa.exp == bb.exp
end

=={T}(a::Decimal, b::T) = ==(promote(a, b)...)
=={T}(a::T, b::Decimal) = ==(promote(a, b)...)

function <(a::Decimal, b::Decimal)
    aa, bb = _scale(a, b)
    return aa.value < bb.value
end

<{T}(a::Decimal, b::T) = <(promote(a, b)...)
<{T}(a::T, b::Decimal) = <(promote(a, b)...)

const ZERO = UInt8('0')
const DOT = UInt8('.')
const MINUS = UInt8('-')
const PLUS = UInt8('+')

"""
Parse a Decimal from a string. Supports decimals of the following form:

  * "101"
  * "101."
  * "101.0"
  * "1.01"
  * ".101"
  * "0.101"
  * "0.0101"
"""
function Base.parse{T}(::Type{Decimal{T}}, str::String)
    str = strip(str)
    bytes = Vector{UInt8}(str)
    value = exp = zero(T)
    frac = neg = false
    for i = 1:length(bytes)
        b = bytes[i]
        if b == MINUS
            neg = true
        elseif b == PLUS
            continue
        elseif b == DOT
            frac = true
            continue
        else
            value *= T(10)
            value += T(b - ZERO)
            frac && (exp -= T(1))
        end
    end
    for i = length(bytes):-1:1
        b = bytes[i]
        if b == ZERO
            if exp < 0
                value = div(value, T(10))
            end
            exp += 1
        else
            break
        end
    end
    return Decimal(ifelse(neg, T(-1), T(1)) * value, exp)
end

function Base.show(io::IO, d::Decimal)
    print(io, "dec\"")
    if d.value == 0
        print(io, "0.0")
    else
        sn = sign(d.value) < 0 ? "-" : ""
        str = string(abs(d.value))
        if d.exp == 0
            print(io, sn, str, ".0")
        else
            if d.exp > 0
                print(io, sn, rpad(str, length(str) + d.exp, '0'), ".0")
            else
                d = length(str) + d.exp
                if d == 0
                    print(io, sn, "0.", str)
                elseif d > 0
                    print(io, sn, str[1:d], ".", str[d+1:end])
                else
                    print(io, sn, "0.", "0"^abs(d), str)
                end
            end
        end
    end
    print(io, '"')
    return
end

# math
-(d::Decimal) = Decimal(-d.value, d.exp)
Base.abs(d::Decimal) = Decimal(abs(d.value), d.exp)

# 10, 100
# (1, 1), (1, 2)
# (1, 1), (10, 1)

# 1.1, 0.001
# (11, -1), (1, -3)
# (1100, -3), (1, -3)

# 10, 0.1
# (1, 1), (1, -1)
# (100, -1), (1, -1)

# scales two decimals to the same exp
_scale{T, T2}(a::Decimal{T}, b::Decimal{T2}) = _scale(promote(a, b)...)
function _scale{T}(a::Decimal{T}, b::Decimal{T})
    a.exp == b.exp && return a, b
    if a.exp < b.exp
        return a, Decimal(b.value * T(10)^(abs(b.exp - a.exp)), a.exp)
    else
        return Decimal(a.value * T(10)^(abs(a.exp - b.exp)), b.exp), b
    end
end

function +(a::Decimal, b::Decimal)
    a2, b2 = _scale(a, b)
    return Decimal(Decimal(a2.value + b2.value, a2.exp))
end

function -(a::Decimal, b::Decimal)
    a2, b2 = _scale(a, b)
    return Decimal(Decimal(a2.value - b2.value, a2.exp))
end

function *(a::Decimal, b::Decimal)
    exp = a.exp + b.exp
    val = a.value * b.value
    return Decimal(Decimal(val, exp))
end

maxprec{T <: Integer}(::Type{T}) = T(length(string(typemax(T))))

function /{T}(a::Decimal{T}, b::Decimal{T})
    b.value == 0 && throw(DivideError())
    # scale num up to max precision
    scale = maxprec(T) - T(length(string(a.value)))
    aa = a.value * (widen(T)(10) ^ scale)
    # simulate division
    q, r = divrem(aa, b.value)
    # return scaled results
    return Decimal(Decimal(T(q + ifelse(div(r * 10, b.value) > 5, 1, 0)), a.exp - b.exp - scale))
end

Base.promote_rule{T, T2}(::Type{Decimal{T}}, ::Type{Decimal{T2}}) = Decimal{promote_type(T, T2)}
Base.promote_rule{T, TI <: Integer}(::Type{Decimal{T}}, ::Type{TI}) = Decimal{promote_type(T, TI)}
Base.promote_rule{T, TF <: AbstractFloat}(::Type{Decimal{T}}, ::Type{TF}) = Decimal{float2int(promote_type(T, TF))}

# TODO:
 # to ints, floats
 # rounding, trunc, floor, ceil
 # maybe:
   # equality: isapprox?
   # ranges
   # fld, mod, rem, divrem, divmod, mod1,
   # fma, muladd
   # shifts?
   # trig functions
   # log, log2, log10
   # exp, ldexp, modf
   # sqrt
   # special functions

end # module
