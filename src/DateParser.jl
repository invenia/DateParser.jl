module DateParser

using Base.Dates
using TimeZones

import Base.Dates: VALUETODAYOFWEEK, VALUETODAYOFWEEKABBR, VALUETOMONTH, VALUETOMONTHABBR
import TimeZones: localtime

# Re-export from Base with ZonedDateTime, DateTime, and Date
export parse, tryparse

# Automatic parsing of DateTime strings. Based upon Python's dateutil parser
# https://labix.org/python-dateutil#head-a23e8ae0a661d77b89dfb3476f85b26f0b30349c

# Some pointers:
# http://www.cl.cam.ac.uk/~mgk25/iso-time.html
# http://www.w3.org/TR/NOTE-datetime
# http://new-pds-rings-2.seti.org/tools/time_formats.html
# http://search.cpan.org/~muir/Time-modules-2003.0211/lib/Time/ParseDate.pm

immutable DayOfWeek <: DatePeriod
    value::Int64
    DayOfWeek(v::Number) = new(v)
end

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
const UTCZONE = ["utc", "gmt", "z",]

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

type Parts
    year::Nullable{Year}
    month::Nullable{Month}
    day::Nullable{Day}
    hour::Nullable{Hour}
    minute::Nullable{Minute}
    second::Nullable{Second}
    millisecond::Nullable{Millisecond}
    timezone::Nullable{TimeZone}
    dayofweek::Nullable{DayOfWeek}
    tzoffset::Nullable{Int}
    tzname::Nullable{AbstractString}
    Parts() = new(nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
        nothing, nothing, nothing)
end
Base.convert{T}(::Type{Nullable{T}}, x::Any) = Nullable{T}(T(x))

function _parsedate(s::AbstractString; fuzzy::Bool=false,
    timezone_infos::Dict{AbstractString, TimeZone}=Dict{AbstractString, TimeZone}(), # Specify what a timezone is
    dayfirst::Bool=false, # MM-DD-YY vs DD-MM-YY
    yearfirst::Bool=false, # MM-DD-YY vs YY-MM-DD
    locale::AbstractString="english", # Locale in Dates.VALUETOMONTH and VALUETODAYOFWEEK
)
    res = Parts()

    ymd = sizehint!(Int[], 3)  # year/month/day list
    monthindex = -1  # Index of a month string in ymd

    tokens = tokenize(s)
    len = length(tokens)

    i = 1
    while i <= len
        token = tokens[i]
        tokenlength = length(token)
        if isdigit(token)
            # Token is a number
            i += 1 # We want to look at what comes after the number
            if tokenlength == 6
                # YYMMDD or HHMMSS[.ss]
                if length(ymd) != 0 ||
                        (i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1]))
                    # 19990101T235959[.59]
                    res.hour = token[1:2]
                    res.minute = token[3:4]
                    res.second = token[5:6]
                    if i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1])
                        temp = round(Int, 1000 * parsefractional(tokens[i+1]))
                        res.millisecond = temp
                        i += 2
                    end
                else
                    push!(ymd, parse(Int, token[1:2]))
                    push!(ymd, parse(Int, token[3:4]))
                    push!(ymd, parse(Int, token[5:end]))
                end
            elseif tokenlength in (8, 12, 14)
                # YYYYMMDD[hhmm[ss]]
                push!(ymd, parse(Int, token[1:4]))
                push!(ymd, parse(Int, token[5:6]))
                push!(ymd, parse(Int, token[7:8]))
                if tokenlength > 8
                    res.hour = token[9:10]
                    res.minute = token[11:12]
                    if tokenlength > 12
                        res.second = token[13:14]
                    end
                end
            elseif tokenlength == 9
                # HHMMSS[mil]
                res.hour = token[1:2]
                res.minute = token[3:4]
                res.second = token[5:6]
                res.millisecond = token[7:9]
            elseif (i <= len && haskey(HMS[locale], lowercase(tokens[i]))) ||
                    (i+2 <= len && tokens[i] == "." && isdigit(tokens[i+1]) &&
                    haskey(HMS[locale], lowercase(tokens[i+2])))
                # HH[ ]h or MM[ ]m or SS[.ss][ ]s

                value = parse(Int, token)
                decimal = 0.0
                if tokens[i] == "."
                    decimal = parsefractional(tokens[i+1])
                    i += 2
                end
                idx = HMS[locale][lowercase(tokens[i])]
                while true
                    if idx == :hour
                        res.hour = value
                        if decimal != 0
                            res.minute = get(res.minute, 0) + Minute(round(Int, 60 * decimal))
                        end
                    elseif idx == :minute
                        res.minute = value
                        if decimal != 0
                            res.second = get(res.second, 0) + Second(round(Int, 60 * decimal))
                        end
                    elseif idx == :second
                        res.second = value
                        if decimal != 0
                            res.millisecond = get(res.millisecond, 0) + Millisecond(round(Int, 1000 * decimal))
                        end
                    end
                    i += 1
                    if i > len || idx == :second
                        break
                    end
                    # 12h00
                    token = tokens[i]
                    if !isdigit(token)
                        break
                    else
                        i += 1
                        value = parse(Int, token)
                        decimal = 0.0
                        if i+1 <= len tokens[i] == "." && isdigit(tokens[i+1])
                            decimal = parsefractional(tokens[i+1])
                            i += 2
                        end
                        if i <= len && haskey(HMS[locale], lowercase(tokens[i]))
                            idx = HMS[locale][lowercase(tokens[i])]
                        elseif idx == :hour
                            idx = :minute
                        else
                            idx = :second
                        end
                    end
                end
            elseif i+1 <= len && tokens[i] == ":"
                # HH:MM[:SS[.ss]]
                res.hour = token
                res.minute = tokens[i+1]
                i += 2
                if i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1])
                    temp = 60 * parsefractional(tokens[i+1])
                    res.second = round(Int, temp)
                    i += 2
                elseif i < len && tokens[i] == ":"
                    res.second = tokens[i+1]
                    i += 2
                    if i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1])
                        temp = 1000 * parsefractional(tokens[i+1])
                        res.millisecond = round(Int, temp)
                        i += 2
                    end
                end
            elseif i <= len && tokens[i] in ("-","/",".")
                sep = tokens[i]
                push!(ymd, parse(Int, token))
                i += 1
                if i <= len && !(lowercase(tokens[i]) in JUMP)
                    m = _tryparse(Month, tokens[i], locale=locale)
                    if !isnull(m)
                        push!(ymd, get(m))
                        monthindex = length(ymd)
                    else
                        push!(ymd, parse(Int, tokens[i]))
                    end
                    i += 1
                    if i <= len && tokens[i] == sep
                        # We have three members
                        i += 1
                        m = _tryparse(Month, tokens[i], locale=locale)
                        if !isnull(m)
                            push!(ymd, get(m))
                            monthindex = length(ymd)
                        else
                            push!(ymd, parse(Int, tokens[i]))
                        end
                        i += 1
                    end
                end
            elseif i <= len && haskey(AMPM[locale], lowercase(tokens[i]))
                # 12am
                res.hour = token
                res.hour = converthour(get(res.hour).value, AMPM[locale][lowercase(tokens[i])])
                i += 1
            else
                if length(ymd) < 3
                    push!(ymd, parse(Int, token))
                elseif tokenlength <= 2
                    if isnull(res.hour)
                        res.hour = token
                    elseif isnull(res.minute)
                        res.minute = token
                    elseif isnull(res.second)
                        res.second = token
                    elseif isnull(res.millisecond)
                        res.millisecond = token
                    elseif !fuzzy
                        error("Failed to parse date")
                    end
                elseif tokenlength == 3 && isnull(res.millisecond)
                    res.millisecond = token
                elseif tokenlength == 4 && isnull(res.hour) && isnull(res.minute)
                    res.hour = token[1:2]
                    res.minute = token[3:4]
                elseif !fuzzy
                    error("Failed to parse date")
                end
            end
        else
            # Token is not a number
            w = _tryparse(DayOfWeek, lowercase(token), locale=locale)
            m = _tryparse(Month, lowercase(token), locale=locale)
            if !isnull(w)
                # Weekday
                res.dayofweek = get(w)
                i += 1
            elseif !isnull(m)
                # Month name
                push!(ymd, get(m))
                monthindex = length(ymd)
                i += 1
                if i <= len
                    if tokens[i] in ("-", "/", ".")
                        # Jan-01[-99]
                        sep = tokens[i]
                        i += 1
                        push!(ymd, parse(Int, tokens[i]))
                        i += 1
                        if i <= len && tokens[i] == sep
                            # Jan-01-99
                            i += 1
                            push!(ymd, parse(Int, tokens[i]))
                            i += 1
                        end
                    elseif i+1 <= len && tokens[i] in PERTAIN && isdigit(tokens[i+1])
                        # Jan of 01
                        # In this case, 01 is clearly year
                        value = parse(Int, tokens[i+1])
                        # Convert it here to become unambiguous
                        push!(ymd, convertyear(value))
                        i += 2
                    end
                end
            elseif haskey(AMPM[locale], lowercase(tokens[i]))
                # am/pm
                if isnull(res.hour)
                    error("Failed to parse date")
                end
                res.hour = converthour(get(res.hour).value, AMPM[locale][lowercase(tokens[i])])
                i += 1
            elseif i+1 <= len  && tokens[i] in ("+", "-") &&
                    isnull(res.tzoffset) && isdigit(tokens[i+1])
                i = _parsetimezone_offset!(res, tokens, i)
            else
                newindex = _tryparsetimezone!(res, tokens, i, timezone_infos)
                if i != newindex
                    # We found a timezone
                    i = newindex
                elseif !(lowercase(tokens[i]) in JUMP) && !fuzzy
                    error("Failed to parse date")
                else
                    i += 1
                end
            end
        end
    end

    processymd!(res, ymd, monthindex=monthindex, yearfirst=yearfirst, dayfirst=dayfirst)

    if isnull(res.timezone) && !isnull(res.tzoffset)
        res.tzname = get(res.tzname, "local")
        res.timezone = FixedTimeZone(get(res.tzname), get(res.tzoffset))
    end

    return res
end

function _parsetimezone_offset!(res::Parts, tokens::Array{ASCIIString}, i::Int)
    # Numbered timzone
    signal = tokens[i] == "+" ? 1 : -1

    i += 1
    tokenlength = length(tokens[i])
    h = mi = 0
    if tokenlength == 4
        # -0300
        h, mi = parse(Int, tokens[i][1:2]), parse(Int, tokens[i][3:end])
    elseif i+2 <= length(tokens) && tokens[i+1] == ":" && isdigit(tokens[i+2])
        # -03:00
        h, mi = parse(Int, tokens[i]), parse(Int, tokens[i+2])
        i += 2
    elseif tokenlength <= 2
        # -[0]3
        h = parse(Int, tokens[i])
    else
        error("Failed to read timezone offset")
    end
    h < 24 || error("Hour: $h out of range (0:23)")
    mi < 60 || error("Minute: $mi out of range (0:59)")
    res.tzoffset = signal * (h * 3600 + mi * 60)
    i += 1

    return i
end

function _tryparsetimezone!(res::Parts, tokens::Array{ASCIIString}, i::Int,
        timezone_infos::Dict{AbstractString,TimeZone}
)
    len = length(tokens)
    oldindex = i
    inbrackets = false

    if i <= len && tokens[i] == "("
        inbrackets = true
        i += 1
    end

    if i <= len && ismatch(r"^\w+$", tokens[i])
        res.tzname = tokens[i]
        while i+2 <= len && ismatch(r"^\w+$", tokens[i]) &&
                (tokens[i+1] in ("/", "-", "_") || ismatch(r"^\d+$", tokens[i+1]))
            res.tzname = string(get(res.tzname), tokens[i+1], tokens[i+2])
            i += 2
        end
        i += 1
    end

    # Check for something like GMT+3, or BRST+3
    if i+1 <= len && tokens[i] in ("+", "-") && isdigit(tokens[i+1])
        newindex = _parsetimezone_offset!(res, tokens, i)
        while i < newindex
            res.tzname = string(get(res.tzname, ""), tokens[i])
            i += 1
        end
    end

    if inbrackets && i <= len && tokens[i] == ")"
        i += 1
    end

    value = _tryparse(TimeZone, get(res.tzname, ""), translation=timezone_infos)
    if !isnull(value)
        res.timezone = get(value)
    elseif !inbrackets || isnull(res.tzoffset)
        res.tzname = Nullable{AbstractString}()
        i = oldindex
    end

    return i
end

function processymd!(res::Parts, ymd::Array{Int};
        monthindex=-1, yearfirst=false, dayfirst=false
)
    # Process year/month/day
    len_ymd = length(ymd)

    if len_ymd > 3
        # More than three members!?
        error("Failed to parse date")
    elseif len_ymd == 1 || (monthindex != -1 && len_ymd == 2)
        # One member, or two members with a month string
        if monthindex != -1
            res.month = ymd[monthindex]
            deleteat!(ymd, monthindex)
        end
        if len_ymd > 1 || monthindex == -1
            if ymd[1] > 31
                res.year = ymd[1]
            else
                res.day = ymd[1]
            end
        end
    elseif len_ymd == 2
        # Two members with numbers
        if ymd[1] > 31
            # 99-01
            res.year, res.month = ymd
        elseif ymd[2] > 31
            # 01-99
            res.month, res.year = ymd
        elseif dayfirst && ymd[2] <= 12
            # 13-01
            res.day, res.month = ymd
        else
            # 01-13
            res.month, res.day = ymd
        end
    elseif len_ymd == 3
        # Three members
        if monthindex == 1
            res.month, res.day, res.year = ymd
        elseif monthindex == 2
            if ymd[1] > 31 || (yearfirst && ymd[3] <= 31)
                # 99-Jan-01
                res.year, res.month, res.day = ymd
            else
                # 01-Jan-01
                # Give precendence to day-first, since
                # two-digit years is usually hand-written.
                res.day, res.month, res.year = ymd
            end
        elseif monthindex == 3
            # WTF
            if ymd[2] > 31
                # 01-99-Jan
                res.day, res.year, res.month = ymd
            else
                res.year, res.day, res.month = ymd
            end
        else
            if ymd[1] > 31 || (yearfirst && ymd[2] <= 12 && ymd[3] <= 31)
                # 99-01-01
                res.year, res.month, res.day = ymd
            elseif ymd[1] > 12 || (dayfirst && ymd[2] <= 12)
                # 13-01-01
                res.day, res.month, res.year = ymd
            else
                # 01-13-01
                res.month, res.day, res.year = ymd
            end
        end
    end
    if !isnull(res.year)
        res.year = convertyear(get(res.year).value)
    end
end

"Helper function. Parses a `String` containing a `Int` into the fraction part of a
`Float64`. e.g \"5\" becomes `0.5` and \"450\" becomes `0.450`"
function parsefractional(s::AbstractString)
    parse(Float64, string(".", s))
end

function _tryparse(::Type{Month}, s::AbstractString; locale::AbstractString="english")
    name = lowercase(s)
    temp = Nullable{Int}(get(MONTHTOVALUE[locale], name,
        get(MONTHABBRTOVALUE[locale], name, nothing)))
    if isnull(temp)
        Nullable{Month}()
    else
        Nullable{Month}(Month(get(temp)))
    end
end

function _tryparse(::Type{DayOfWeek}, s::AbstractString; locale::AbstractString="english")
    name = lowercase(s)
    temp = Nullable{Int}(get(DAYOFWEEKTOVALUE[locale], name,
        get(DAYOFWEEKABBRTOVALUE[locale], name, nothing)))
    if isnull(temp)
        Nullable{DayOfWeek}()
    else
        Nullable{DayOfWeek}(DayOfWeek(get(temp)))
    end
end

function _tryparse(::Type{TimeZone}, name::AbstractString;
    translation::Dict{AbstractString,TimeZone}=Dict{AbstractString,TimeZone}()
)
    if haskey(translation, name)
        return Nullable{TimeZone}(translation[name])
    elseif name in TimeZones.timezone_names()
        return Nullable{TimeZone}(TimeZone(name))
    elseif lowercase(name) in UTCZONE
        return Nullable{TimeZone}(FixedTimeZone("UTC", 0))
    else
        return Nullable{TimeZone}()
    end
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

function converthour(h::Int, ampm::Symbol)
    if h < 12 && ampm == :pm
        h = h + 12
    elseif h == 12 && ampm == :am
        h = 0
    end
    return h
end

function tokenize{Str<:AbstractString}(input::Str)
    tokens = Str[]
    token = sizehint!(Char[], 10)

    # Note: A regular expression can handle almost all of this task
    # with the exception of identifying Unicode punctuation.
    state = last_state = :none
    for c in input
        if isspace(c)
            state = :none
        elseif isdigit(c)
            state = :number
        elseif isalpha(c)
            state = :word
        else
            state = :other
        end

        if state != :none
            if state != last_state && !isempty(token)
                push!(tokens, Str(token))
                empty!(token)
            end

            push!(token, c)
        end

        last_state = state
    end

    # Token will only be empty here if the entire input was whitespace
    !isempty(token) && push!(tokens, Str(token))

    return tokens
end

end # module
