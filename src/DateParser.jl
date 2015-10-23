module DateParser

using Base.Dates
using TimeZones

import Base.Dates: VALUETODAYOFWEEK, VALUETODAYOFWEEKABBR, VALUETOMONTH, VALUETOMONTHABBR
import TimeZones: localtime

# Re-export from Base with ZonedDateTime, DateTime, and Date
export parse, tryparse

include("tokens.jl")

# Automatic parsing of DateTime strings. Based upon Python's dateutil parser
# https://labix.org/python-dateutil#head-a23e8ae0a661d77b89dfb3476f85b26f0b30349c

# Some pointers:
# http://www.cl.cam.ac.uk/~mgk25/iso-time.html
# http://www.w3.org/TR/NOTE-datetime
# http://new-pds-rings-2.seti.org/tools/time_formats.html
# http://search.cpan.org/~muir/Time-modules-2003.0211/lib/Time/ParseDate.pm

const english_hms = Dict(
    "h" => :hour, "hour" => :hour, "hours" => :hour,
    "m" => :minute, "minute" => :minute, "minutes" => :minute,
    "s" => :second, "second" => :second, "seconds" => :second,
)
const HMS = Dict{UTF8String,Dict{UTF8String,Symbol}}("english"=>english_hms)
const english_ampm = Dict(
    "am" => :am, "a" => :am,
    "pm" => :pm, "p" => :pm,
)
const AMPM = Dict{UTF8String,Dict{UTF8String,Symbol}}("english"=>english_ampm)

# Name to value translations
for name in ("DAYOFWEEK", "DAYOFWEEKABBR", "MONTH", "MONTHABBR")
    valueto = Symbol("VALUETO" * name)
    tovalue = Symbol(name * "TOVALUE")
    @eval begin
        const $tovalue = [locale => Dict{UTF8String,Int}(
            zip(map(lowercase, values(d)), keys(d))) for (locale, d) in $valueto]
    end
end

const JUMP = [
    " ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m", "t", "of", "st",
    "nd", "rd", "th", "the",
]
const PERTAIN = ["of",]
const UTC_ZONES = ["UTC", "GMT", "Z"]

const YEAR = UInt8(0x01)
const MONTH = UInt8(0x02)
const DAY = UInt8(0x04)
const ALL = YEAR | MONTH | DAY


function Base.tryparse{T<:TimeType}(::Type{T}, s::AbstractString; args...)
    try
        return Nullable{T}(parse(T, s; args...))
    catch
        return Nullable{T}()
    end
end

function Base.parse(::Type{ZonedDateTime}, zdt::AbstractString;
    default::ZonedDateTime=ZonedDateTime(DateTime(year(today())), FixedTimeZone("UTC", 0)),
    args...
)
    res = _parsedate(zdt; args...)

    return ZonedDateTime(
        DateTime(
            get(res.year, Year(default)),
            get(res.month, Month(default)),
            get(res.day, Day(default)),
            get(res.hour, Hour(default)),
            get(res.minute, Minute(default)),
            get(res.second, Second(default)),
            get(res.millisecond, Millisecond(default))
        ),
        get(res.timezone, default.timezone)
    )
end

function Base.parse(::Type{DateTime}, dt::AbstractString;
    default::DateTime=DateTime(year(today())), args...
)
    res = _parsedate(dt; args...)

    return DateTime(
        get(res.year, Year(default)),
        get(res.month, Month(default)),
        get(res.day, Day(default)),
        get(res.hour, Hour(default)),
        get(res.minute, Minute(default)),
        get(res.second, Second(default)),
        get(res.millisecond, Millisecond(default))
    )
end

function Base.parse(::Type{Date}, d::AbstractString;
    default::Date=Date(year(today())), args...
)
    res = _parsedate(d; args...)

    return Date(
        get(res.year, Year(default)),
        get(res.month, Month(default)),
        get(res.day, Day(default))
    )
end

type Components
    year::Nullable{Year}
    month::Nullable{Month}
    day::Nullable{Day}
    hour::Nullable{Hour}
    minute::Nullable{Minute}
    second::Nullable{Second}
    millisecond::Nullable{Millisecond}
    timezone::Nullable{TimeZone}
    dayofweek::Nullable{Int}

    Components() = new(
        nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
    )
end
Base.convert{T}(::Type{Nullable{T}}, x::Any) = Nullable{T}(T(x))

function _parsedate(str::AbstractString; fuzzy::Bool=false,
    tzmap::Dict{AbstractString, TimeZone}=Dict{AbstractString, TimeZone}(), # Specify what a timezone is
    dayfirst::Bool=false, # MM-DD-YY vs DD-MM-YY
    yearfirst::Bool=false, # MM-DD-YY vs YY-MM-DD
    locale::AbstractString="english", # Locale in Dates.VALUETOMONTH and VALUETODAYOFWEEK
)
    res = Components()

    # Date (year, month, day) information
    date_values = sizehint!(Int[], 3)
    date_types = sizehint!(UInt8[], 3)

    hint = :none

    const hms_regex = Regex("\\G(?:\\.\\d+)?\\s*(?<key>" * regex_str(keys(HMS[locale])) * ")(?=[\\W\\d]|\$)", "i")
    const ampm_regex = Regex("\\G\\s*(?<key>" * regex_str(keys(AMPM[locale])) * ")(?=[\\W\\d]|\$)", "i")
    const pertain_regex = Regex("\\G\\s*(?<word>" * regex_str(PERTAIN) * ")\\s*(?<year>\\d+)", "i")
    const skip_regex = Regex("\\G\\s*(" * regex_str(JUMP) * ")(?=[\\W\\d]|\$)", "i")

    index = last_index = start(str)
    while index <= endof(str)
        if (m = match(r"\G(\d+)", str, index)) != nothing
            # The digit is expected to be stored appropriately
            digit = m[1]
            index = nextind(str, index + endof(m.match) - 1)

            if length(digit) == 6
                # YYMMDD or HHMMSS[.ss]
                values = map(d -> parse(Int, d), [digit[1:2], digit[3:4], digit[5:6]])
                m = match(r"\G\.(\d+)", str, index)

                if m != nothing || !isempty(date_values)
                    # 19990101T235959[.59]
                    res.hour, res.minute, res.second = values

                    if m != nothing
                        res.millisecond = parse_as_decimal(m[1], 1000)
                        index = nextind(str, index + endof(m.match) - 1)
                    end
                else
                    push!(date_values, values...)
                    push!(date_types, fill(ALL, length(values))...)
                end

            elseif length(digit) in (8, 12, 14)
                # YYYYMMDD[hhmm[ss]]
                values = map(d -> parse(Int, d), [digit[1:4], digit[5:6], digit[7:8]])
                push!(date_values, values...)
                push!(date_types, fill(ALL, length(values))...)

                if length(digit) > 8
                    res.hour = digit[9:10]
                    res.minute = digit[11:12]
                    if length(digit) > 12
                        res.second = digit[13:14]
                    end
                end

            elseif length(digit) == 9
                # HHMMSS[mil]
                res.hour = digit[1:2]
                res.minute = digit[3:4]
                res.second = digit[5:6]
                res.millisecond = digit[7:9]

            elseif (m = match(hms_regex, str, index)) != nothing || hint != :none
                # HH[.MM][ ]h or MM[.SS][ ]m or SS[.ss][ ]s

                value = parse(Int, digit)

                # Grab decimal. Note that we still want to get the decimal if we entered
                # when hint != :none
                decimal_match = match(r"\G\.(\d+)", str, index)
                decimal = decimal_match != nothing ? decimal_match[1] : ""

                if m != nothing
                    label = HMS[locale][lowercase(m["key"])]
                    index = nextind(str, index + endof(m.match) - 1)
                else
                    label = hint
                end

                if label == :hour
                    res.hour = value
                    if decimal != ""
                        res.minute = get(res.minute, 0) + Minute(parse_as_decimal(decimal, 60))
                    end
                    hint = :minute
                elseif label == :minute
                    res.minute = value
                    if decimal != ""
                        res.second = get(res.second, 0) + Second(parse_as_decimal(decimal, 60))
                    end
                    hint = :second
                elseif label == :second
                    res.second = value
                    if decimal != ""
                        res.millisecond = get(res.millisecond, 0) + Millisecond(parse_as_decimal(decimal, 1000))
                    end
                    hint == :none
                end

            elseif (m = match(r"\G:(\d+)(?:\:(\d+))?(?:\.(\d+))?", str, index)) != nothing
                # HH:MM[:SS[.ss]]
                res.hour = digit

                minute, second, decimal = m.captures
                index = nextind(str, index + endof(m.match) - 1)

                res.minute = minute

                if second != nothing
                    res.second = second
                    if decimal != nothing
                        res.millisecond = parse_as_decimal(decimal, 1000)
                    end
                elseif decimal != nothing
                    res.second = parse_as_decimal(decimal, 60)
                end

            elseif (m = match(r"\G([-/.])(?|(\d+)(?(1)\1(\d+|\S+))?|((?:(?!\1)\S)+)(?(1)\1(\d+))?)", str, index)) != nothing
                # 1998-02-18, 1999/Feb/18, 1999.18.02
                push!(date_values, parse(Int, digit))
                push!(date_types, ALL)
                index = nextind(str, index + endof(m.match) - 1)

                for token in m.captures[2:end]
                    token != nothing || continue
                    if isdigit(token)
                        push!(date_values, parse(Int, token))
                        push!(date_types, ALL)
                    elseif (ext = extract_month(token, locale=locale)) != nothing
                        month, _ = ext
                        push!(date_values, month)
                        push!(date_types, MONTH)
                    end
                end

            elseif (m = match(ampm_regex, str, index)) != nothing
                # 12am
                hour = parse(Int, digit)
                res.hour = converthour(hour, AMPM[locale][lowercase(m["key"])])
                index = nextind(str, index + endof(m.match) - 1)

            else
                value = parse(Int, digit)

                if length(date_values) < 3
                    push!(date_values, value)
                    push!(date_types, ALL)
                elseif length(digit) <= 2
                    if isnull(res.hour)
                        res.hour = value
                    elseif isnull(res.minute)
                        res.minute = value
                    elseif isnull(res.second)
                        res.second = value
                    elseif isnull(res.millisecond)
                        res.millisecond = value
                    elseif !fuzzy
                        error("Failed to parse date")
                    end
                elseif length(digit) == 3 && isnull(res.millisecond)
                    res.millisecond = value
                elseif length(digit) == 4 && isnull(res.hour) && isnull(res.minute)
                    res.hour = digit[1:2]
                    res.minute = digit[3:4]
                elseif !fuzzy
                    error("Failed to parse date")
                end
            end

        elseif (ext = extract_dayofweek(str, index, locale=locale)) != nothing
            res.dayofweek, index = ext

        elseif (ext = extract_month(str, index, locale=locale)) != nothing
            # Month name
            month, index = ext

            push!(date_values, month)
            push!(date_types, MONTH)

            if (m = match(r"\G([-/.])(\d+)(?(1)\1(\d+))", str, index)) != nothing
                # Jan-01[-99]
                for token in m.captures[2:end]
                    push!(date_values, parse(Int, token))
                    push!(date_types, ALL)
                end

                index = nextind(str, index + endof(m.match) - 1)
            elseif (m = match(pertain_regex, str, index)) != nothing
                # "Jan of 01": 01 is clearly the year
                push!(date_values, parse(Int, m["year"]))
                push!(date_types, YEAR)
                index = nextind(str, index + endof(m.match) - 1)
            end

        elseif (m = match(ampm_regex, str, index)) != nothing
            # am/pm
            isnull(res.hour) && error("Expected to find hour prior to the meridiem")
            meridiem = AMPM[locale][lowercase(m["key"])]
            res.hour = converthour(get(res.hour).value, meridiem)
            index = nextind(str, index + endof(m.match) - 1)

        elseif isnull(res.timezone) && (ext = extract_tz(str, index, tzmap=tzmap)) != nothing
            res.timezone, index = ext

        else
            m = match(skip_regex, str, index)

            if m != nothing
                index = nextind(str, index + endof(m.match) - 1)
            elseif !fuzzy
                error("Failed to parse date")
            else
                index = nextind(str, index)
            end
        end

        if last_index == index
            error("Something has gone wrong: $res, $date_values")
        end
        last_index = index
    end

    ymd = nothing
    if yearfirst && ymd == nothing
        mask = [YEAR; fill(ALL, length(date_types) - 1)]
        ymd = processymd(date_values, date_types & mask)
    end
    if dayfirst && ymd == nothing
        mask = [DAY; fill(ALL, length(date_types) - 1)]
        ymd = processymd(date_values, date_types & mask)
    end
    if ymd == nothing
        ymd = processymd(date_values, date_types)
    end

    if ymd != nothing
        year, month, day = ymd
        year != nothing && (year = convertyear(year))
        res.year, res.month, res.day = year, month, day
    end

    return res
end

function extract_dayofweek(str::AbstractString, index::Integer=1; locale::AbstractString="english")
    dow_words = [
        collect(keys(DAYOFWEEKTOVALUE[locale]));
        collect(keys(DAYOFWEEKABBRTOVALUE[locale]))
    ]
    dow_regex = Regex("\\G\\s*(?<dow>" * regex_str(dow_words) * ")(?=[\\W\\d]|\$)", "i")

    m = match(dow_regex, str, index)
    if m != nothing
        name = lowercase(m["dow"])
        dow = get(DAYOFWEEKTOVALUE[locale], name, get(DAYOFWEEKABBRTOVALUE[locale], name, nothing))
        index = nextind(str, index + endof(m.match) - 1)
        return dow, index
    end

    return nothing
end

function extract_month(str::AbstractString, index::Integer=1; locale::AbstractString="english")
    words = [
        collect(keys(MONTHTOVALUE[locale]));
        collect(keys(MONTHABBRTOVALUE[locale]))
    ]
    regex = Regex("\\G\\s*(?<word>" * regex_str(words) * ")(?=[\\W\\d]|\$)", "i")

    m = match(regex, str, index)
    if m != nothing
        name = lowercase(m["word"])
        month = get(MONTHTOVALUE[locale], name, get(MONTHABBRTOVALUE[locale], name, nothing))
        index = nextind(str, index + endof(m.match) - 1)
        return month, index
    end

    return nothing
end

function extract_tz(str::AbstractString, index::Integer=1; tzmap::Dict{AbstractString,TimeZone}=Dict{AbstractString,TimeZone}())
    name = fixed_name = ""
    offset = 0

    # Numbered timezone: -0300, -[0]3:00, -[0]3
    m = match(r"\G\s*((?:(?<=\s)[A-Z]+)?([+-])(?|(\d{2})(\d{2})|(\d{1,2})(?:\:(\d{2}))?))\b", str, index)
    if m != nothing
        fixed_name = m.captures[1]
        sign = m.captures[2] == "+" ? 1 : -1
        hour, minute = map(d -> d != nothing ? parse(Int, d) : 0, m.captures[3:end])
        hour < 24 && minute < 60 || error("Timezone offset out of range: $(m.match)")

        offset = sign * (hour * 3600 + minute * 60)
        index = nextind(str, index + endof(m.match) - 1)

        # Named offset: (Europe/Warsaw)
        if index <= endof(str)

            m = match(r"\G\s*\((?<name>[\p{L}/_+-]*)\)", str, index)
            if m != nothing
                name = m["name"]
                index = nextind(str, index + endof(m.match) - 1)
            end
        end
    else
        # Named timezones like: Europe/Warsaw or Etc/GMT+3
        m = match(r"\G\s*(?<name>[\p{L}\d/_+-]*)", str, index)
        if m != nothing
            name = m["name"]
            index = nextind(str, index + endof(m.match) - 1)
        end
    end

    if haskey(tzmap, name)
        tz = tzmap[name]
        return tz, index
    elseif name in TimeZones.timezone_names()
        tz = TimeZone(name)
        return tz, index
    elseif name in UTC_ZONES
        tz = FixedTimeZone("UTC", 0)
        return tz, index
    elseif fixed_name != ""
        tz = FixedTimeZone(name != "" ? name : fixed_name, offset)
        return tz, index
    end

    return nothing
end

function regex_str(iter)
    # Note: Collecting iterator as sort(::KeyIterator) doesn't exist
    # sort(collect(iter), by=length, rev=true)
    join(["\\Q$el\\E" for el in iter], "|")
end

function processymd{T<:Integer}(values::Array{T}, types::Array{UInt8})
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

    ismatch = (a, b) -> all(el -> el != 0, a & b)
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

"Helper function. Parses a `String` containing a `Int` into the fraction part of a
`Float64`. e.g \"5\" becomes `0.5` and \"450\" becomes `0.450`"
function parse_as_decimal(s::AbstractString)
    parse(Int, s) / 10^length(s)
    # parse(Float64, string(".", s))
end

function parse_as_decimal(s::AbstractString, multiplier::Integer)
    round(Int, parse_as_decimal(s) * multiplier)
end

"Converts a 2 digit year to a 4 digit one within 50 years of convert_year. At the momment
 convert_year defaults to 2000, if people are still using 2 digit years after year 2049
 (hopefully not) then we can change the default to today()"
function convertyear(year::Int, convert_year=2000)
    if year <= 99
        century = convert_year - (convert_year % 100)
        year += century
        if abs(year - convert_year) >= 50
            if year < convert_year
                year += 100
            else
                year -= 100
            end
        end
    end
    return year
end

function converthour(hour::Integer, ampm::Symbol)
    if hour < 12 && ampm == :pm
        hour = hour + 12
    elseif hour == 12 && ampm == :am
        hour = 0
    end
    return hour
end



end # module
