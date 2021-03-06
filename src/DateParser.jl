module DateParser

using Base.Dates
using TimeZones

# Note: As of Julia 0.6 the methods `Base.parse(::Type{<:TimeType}, ::AbstractString)`
# already exist and should no longer be exported. We probably want to rename these methods.

# import Base: parse, tryparse

# Re-export from Base with ZonedDateTime, DateTime, and Date
# export parse, tryparse

include(VERSION >= v"0.6.0-dev.2307" ? "constants.jl" : "constants-0.5.jl")
include("parser.jl")
include("extract.jl")
include("processymd.jl")
include("util.jl")

function tryparse{T<:TimeType}(::Type{T}, str::AbstractString; kwargs...)
    try
        return Nullable{T}(parse(T, str; kwargs...))
    catch
        return Nullable{T}()
    end
end

function parse(::Type{Date}, str::AbstractString;
    default::Date=Date(current_year()), kwargs...
)
    dp = DateParts(str; kwargs...)
    return Date(dp, default)
end

function parse(::Type{DateTime}, str::AbstractString;
    default::DateTime=DateTime(current_year()), overflow::Bool=false, kwargs...
)
    dp = DateParts(str; kwargs...)
    return DateTime(dp, default, overflow=overflow)
end

function parse(::Type{ZonedDateTime}, str::AbstractString;
    default::ZonedDateTime=ZonedDateTime(DateTime(current_year()), UTC),
    overflow::Bool=false, kwargs...
)
    dp = DateParts(str; kwargs...)
    return ZonedDateTime(dp, default, overflow=overflow)
end

end # module
