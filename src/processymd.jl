const YEAR = UInt8(0x01)
const MONTH = UInt8(0x02)
const DAY = UInt8(0x04)
const ALL = YEAR | MONTH | DAY

ismatch(a::T, b::T) where T <: Integer = a & b != zero(T)
ismatch(a::Array{T}, b::Array{T}) where T <: Integer = all(t -> ismatch(t...), zip(a, b))

function processymd(values::Array{T}, types::Array{UInt8}) where T <: Integer
    year = nothing
    month = nothing
    day = nothing

    len = length(values)
    len > 3 && throw(DomainError("Too many values provided for a Date"))
    len != length(types) && throw(DimensionMismatch("values and types are not the same length"))

    types = copy(types)
    for i in eachindex(values)
        1 <= values[i] <= 12 || (types[i] &= ~MONTH)
        1 <= values[i] <= 31 || (types[i] &= ~DAY)
    end

    if len == 1
        if ismatch(types, [DAY])
            day, = values
        elseif ismatch(types, [MONTH])
            month, = values
        elseif ismatch(types, [YEAR])
            year, = values
        end
    elseif len == 2
        if ismatch(types, [MONTH, DAY])
            month, day = values
        elseif ismatch(types, [DAY, MONTH])
            day, month = values
        elseif ismatch(types, [YEAR, MONTH])
            year, month = values
        elseif ismatch(types, [MONTH, YEAR])
            month, year = values
        elseif ismatch(types, [YEAR, DAY])
            year, day = values
        elseif ismatch(types, [DAY, YEAR])
            day, year = values
        end
    elseif len == 3
        if ismatch(types, [MONTH, DAY, YEAR])
            month, day, year = values
        elseif ismatch(types, [DAY, MONTH, YEAR])
            day, month, year = values
        elseif ismatch(types, [YEAR, MONTH, DAY])
            year, month, day = values
        elseif ismatch(types, [YEAR, DAY, MONTH])
            year, day, month = values
        elseif ismatch(types, [MONTH, YEAR, DAY])
            month, year, day = values
        elseif ismatch(types, [DAY, YEAR, MONTH])
            day, year, month = values
        end
    end

    if any([year, month, day] .!= nothing)
        return year, month, day
    else
        return nothing
    end
end
