module DateTimeParser

using Base.Dates
using TimeZones

import Base.Dates: VALUETODAYOFWEEK, VALUETODAYOFWEEKABBR, VALUETOMONTH, VALUETOMONTHABBR
import TimeZones: localtime

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

const HMS = Dict{AbstractString, Symbol}(
    "h" => :hour, "hour" => :hour, "hours" => :hour,
    "m" => :minute, "minute" => :minute, "minutes" => :minute,
    "s" => :second, "second" => :second, "seconds" => :second,
)
const AMPM = Dict{AbstractString, Symbol}(
    "am" => :am, "a" => :am,
    "pm" => :pm, "p" => :pm,
)
const JUMP = (
    " ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m", "t", "of", "st",
    "nd", "rd", "th", "the",
)
const PERTAIN = ("of",)
const UTCZONE = ("utc", "gmt", "z",)

# Name to value translations
for name in ("DAYOFWEEK", "DAYOFWEEKABBR", "MONTH", "MONTHABBR")
    valueto = symbol("VALUETO" * name)
    tovalue = symbol(name * "TOVALUE")
    @eval begin
        const $tovalue = [locale => Dict(zip(map(lowercase, values(d)), keys(d))) for (locale, d) in $valueto]
    end
end

function Base.tryparse{T<:TimeType}(::Type{T}, str::AbstractString; args...)
    try
        return Nullable{T}(parse(T, str; args...))
    catch
        return Nullable{T}()
    end
end

function Base.parse(::Type{ZonedDateTime}, datetimestring::AbstractString;
    default::ZonedDateTime=ZonedDateTime(DateTime(year(today())), FixedTimeZone("UTC", 0)),
    args...
)
    datetimestring = strip(datetimestring)

    if isempty(datetimestring)
        return default
    end

    res = _parsedate(datetimestring; args...)

    # Fill in default values if none exits
    res.year = get(res.year, Year(default))
    res.month = get(res.month, Month(default))
    res.day = get(res.day, Day(default))
    res.hour = get(res.hour, Hour(default))
    res.minute = get(res.minute, Minute(default))
    res.second = get(res.second, Second(default))
    res.millisecond = get(res.millisecond, Millisecond(default))
    res.timezone = get(res.timezone, default.timezone)

    return ZonedDateTime(DateTime(get(res.year), get(res.month), get(res.day), get(res.hour),
        get(res.minute), get(res.second), get(res.millisecond)), get(res.timezone))
end

function Base.parse(::Type{DateTime}, datetimestring::AbstractString;
    default::DateTime=DateTime(year(today())), args...
)
    datetimestring = strip(datetimestring)

    if isempty(datetimestring)
        return default
    end

    res = _parsedate(datetimestring; args...)

    # Fill in default values if none exits
    res.year = get(res.year, Year(default))
    res.month = get(res.month, Month(default))
    res.day = get(res.day, Day(default))
    res.hour = get(res.hour, Hour(default))
    res.minute = get(res.minute, Minute(default))
    res.second = get(res.second, Second(default))
    res.millisecond = get(res.millisecond, Millisecond(default))

    return DateTime(get(res.year), get(res.month), get(res.day), get(res.hour),
        get(res.minute), get(res.second), get(res.millisecond))
end

function Base.parse(::Type{Date}, datetimestring::AbstractString;
    default::Date=Date(year(today())), args...
)
    datetimestring = strip(datetimestring)

    if isempty(datetimestring)
        return default
    end

    res = _parsedate(datetimestring; args...)

    # Fill in default values if none exits
    res.year = get(res.year, Year(default))
    res.month = get(res.month, Month(default))
    res.day = get(res.day, Day(default))

    return Date(get(res.year), get(res.month), get(res.day))
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
    Parts() = new(Nullable{Year}(), Nullable{Month}(), Nullable{Day}(), Nullable{Hour}(),
        Nullable{Minute}(), Nullable{Second}(), Nullable{Millisecond}(), Nullable{TimeZone}(),
        Nullable{DayOfWeek}(), Nullable{Int}(), Nullable{AbstractString}())
end
Base.convert{T}(::Type{Nullable{T}}, x::Any) = Nullable{T}(T(x))

function _parsedate(datetimestring::AbstractString; fuzzy::Bool=false,
    timezone_infos::Dict{AbstractString, TimeZone}=Dict{AbstractString, TimeZone}(), # Specify what a timezone is
    dayfirst::Bool=false, # MM-DD-YY vs DD-MM-YY
    yearfirst::Bool=false, # MM-DD-YY vs YY-MM-DD
    locale::AbstractString="english", # Locale in Dates.VALUETOMONTH and VALUETODAYOFWEEK
)
    res = Parts()

    ymd = sizehint!(Int[], 3)  # year/month/day list
    monthindex = -1  # Index of the month string in ymd

    tzoffset = Nullable{Int}()

    tokens = tokenize(datetimestring)
    len = length(tokens)

    i = 1
    while i <= len
        token = tokens[i]
        tokenlength = length(token)
        if isdigit(token)
            # Token is a number
            i += 1 # We want to look at what comes after the number
            if length(ymd) == 3 && tokenlength in (2,4) &&
                (i>=len || (tokens[i] != ":" && !haskey(HMS, lowercase(tokens[i]))))
                # 19990101T23[59]
                res.hour = Hour(token[1:2])
                if tokenlength == 4
                    res.minute = Minute(token[3:4])
                end
            elseif tokenlength == 6
                # YYMMDD or HHMMSS[.ss]
                if length(ymd) != 0 || (i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1]))
                    # 19990101T235959[.59]
                    res.hour = Hour(token[1:2])
                    res.minute = Minute(token[3:4])
                    res.second = Second(token[5:6])
                    if i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1])
                        temp = round(Int, 1000 * parse(Float64, string(tokens[i], tokens[i+1])))
                        res.millisecond = Millisecond(temp)
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
                    res.hour = Hour(token[9:10])
                    res.minute = Minute(token[11:12])
                    if tokenlength > 12
                        res.second = Second(token[13:14])
                    end
                end
            elseif (i <= len && haskey(HMS, lowercase(tokens[i]))) ||
                    (i+2 <= len && tokens[i] == "." && isdigit(tokens[i+1]) &&
                    haskey(HMS, lowercase(tokens[i+2])))
                # HH[ ]h or MM[ ]m or SS[.ss][ ]s

                value = parse(Int, token)
                decimal = 0.0
                if tokens[i] == "."
                    decimal = parse(Float64, string(".", tokens[i+1]))
                    i += 2
                end
                idx = HMS[lowercase(tokens[i])]
                while true
                    if idx == :hour
                        res.hour = Hour(value)
                        if decimal != 0
                            res.minute = Minute(round(Int, 60 * decimal))
                        end
                    elseif idx == :minute
                        res.minute = Minute(value)
                        if decimal != 0
                            res.second = Second(round(Int, 60 * decimal))
                        end
                    elseif idx == :second
                        res.second = Second(value)
                        if decimal != 0
                            res.millisecond = Millisecond(round(Int, 1000 * decimal))
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
                            decimal = parse(Float64, string(".", tokens[i+1]))
                            i += 2
                        end
                        if i <= len && haskey(HMS, lowercase(tokens[i]))
                            idx = HMS[lowercase(tokens[i])]
                        elseif idx == :hour
                            idx = :minute
                        else
                            idx = :second
                        end
                    end
                end
            elseif i+1 <= len && tokens[i] == ":"
                # HH:MM[:SS[.ss]]
                res.hour = Hour(token)
                res.minute = Minute(tokens[i+1])
                i += 2
                if i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1])
                    temp = 60 * parse(Float64, string(".", tokens[i+1]))
                    res.second = Second(round(Int, temp))
                    i += 2
                elseif i < len && tokens[i] == ":"
                    res.second = Second(tokens[i+1])
                    i += 2
                    if i+1 <= len && tokens[i] == "." && isdigit(tokens[i+1])
                        temp = 1000 * parse(Float64, string(".", tokens[i+1]))
                        res.millisecond = Millisecond(round(Int, temp))
                        i += 2
                    end
                end
            elseif i <= len && tokens[i] in ("-","/",".")
                sep = tokens[i]
                push!(ymd, parse(Int, token))
                i += 1
                if i <= len && !(lowercase(tokens[i]) in JUMP)
                    if isdigit(tokens[i])
                        push!(ymd, parse(Int, tokens[i]))
                    else
                        month = _tryparse(Month, tokens[i])
                        if !isnull(month)
                            push!(ymd, get(month))
                            monthindex = length(ymd)
                        end
                    end
                    i += 1
                    if i <= len && tokens[i] == sep
                        # We have three members
                        i += 1
                        month = _tryparse(Month, tokens[i])
                        if !isnull(month)
                            push!(ymd, get(month))
                            monthindex = length(ymd)
                        else
                            push!(ymd, parse(Int, tokens[i]))
                        end
                        i += 1
                    end
                end
            elseif i <= len && haskey(AMPM, lowercase(tokens[i]))
                # 12am
                res.hour = Hour(token)
                res.hour = converthour(get(res.hour), AMPM[lowercase(tokens[i])])
                i += 1
            else
                push!(ymd, parse(Int, token))
            end
        else
            # Token is not a number
            weekday = _tryparse(DayOfWeek, lowercase(token))
            month = _tryparse(Month, lowercase(token))
            if !isnull(weekday)
                # Weekday
                res.dayofweek = get(weekday)
                i += 1
            elseif !isnull(month)
                # Month name
                push!(ymd, get(month))
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
                        push!(ymd, convertyear(Year(value)).value)
                        i += 2
                    end
                end
            elseif haskey(AMPM, lowercase(tokens[i]))
                # am/pm
                if isnull(res.hour)
                    error("Failed to parse date")
                end
                res.hour = converthour(get(res.hour), AMPM[lowercase(tokens[i])])
                i += 1
            elseif tokens[i] in ("+", "-") && isnull(tzoffset) && i+1 <= len && isdigit(tokens[i+1])
                # Numbered timzone
                signal = tokens[i] == "+" ? 1 : -1

                i += 1
                tokenlength = length(tokens[i])
                hour = minute = 0
                if tokenlength == 4
                    # -0300
                    hour, minute = parse(Int, tokens[i][1:2]), parse(Int, tokens[i][3:end])
                elseif i+2 <= len && tokens[i+1] == ":" && isdigit(tokens[i+2])
                    # -03:00
                    hour, minute = parse(Int, tokens[i]), parse(Int, tokens[i+2])
                    i += 2
                elseif tokenlength <= 2
                    # -[0]3
                    hour = parse(Int, tokens[i])
                else
                    error("Failed to read timezone offset after +/-")
                end
                tzoffset = Nullable{Int}(signal * (hour * 3600 + minute * 60))
                i += 1
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

    processymd!(res, ymd, monthindex, yearfirst=yearfirst, dayfirst=dayfirst)

    if isnull(res.timezone) && !isnull(tzoffset)
        res.timezone = FixedTimeZone("local", get(tzoffset))
    end

    return res
end

function _tryparsetimezone!(res::Parts, tokens::Array{ASCIIString}, i::Int, timezone_infos::Dict{AbstractString,TimeZone})
    len = length(tokens)
    tzname = ""
    oldindex = i

    if i <= len && tokens[i] == "("
        i += 1
    end

    if i <= len && ismatch(r"^\w+$", tokens[i])
        tzname = tokens[i]
        while i+2 <= len && ismatch(r"^\w+$", tokens[i]) &&
                (tokens[i+1] in ("/", "-", "_") || ismatch(r"^\d+$", tokens[i+1]))
            tzname = string(tzname, tokens[i+1], tokens[i+2])
            i += 2
        end
        i += 1
    end

    # Check for something like GMT+3, or BRST+3
    if i+1 <= len && tokens[i] in ("+", "-") &&
            isdigit(tokens[i+1]) && length(tokens[i+1]) in (1,2) &&
            (i+2 > len || tokens[i+2] != ":")
        tzname = string(tzname, tokens[i], tokens[i+1])
        i += 2
    end

    if i <= len && tokens[i] == ")"
        i += 1
    end

    value = _tryparse(TimeZone, tzname, translation=timezone_infos)
    if !isnull(value)
        res.timezone = get(value)
    else
        i = oldindex
    end

    return i
end

function processymd!(res::Parts, ymd::Array{Int}, monthindex=-1; yearfirst=false, dayfirst=false)
    # Process year/month/day
    len_ymd = length(ymd)

    if len_ymd > 3
        # More than three members!?
        error("Failed to parse date")
    elseif len_ymd == 1 || (monthindex != -1 && len_ymd == 2)
        # One member, or two members with a month string
        if monthindex != -1
            res.month = Month(ymd[monthindex])
            deleteat!(ymd, monthindex)
        end
        if len_ymd > 1 || monthindex == -1
            if ymd[1] > 31
                res.year = Year(ymd[1])
            else
                res.day = Day(ymd[1])
            end
        end
    elseif len_ymd == 2
        # Two members with numbers
        if ymd[1] > 31
            # 99-01
            res.year = Year(ymd[1])
            res.month = Month(ymd[2])
        elseif ymd[2] > 31
            # 01-99
            res.month = Month(ymd[1])
            res.year = Year(ymd[2])
        elseif dayfirst && ymd[2] <= 12
            # 13-01
            res.day = Day(ymd[1])
            res.month = Month(ymd[2])
        else
            # 01-13
            res.month = Month(ymd[1])
            res.day = Day(ymd[2])
        end
    elseif len_ymd == 3
        # Three members
        if monthindex == 1
            res.month = Month(ymd[1])
            res.day = Day(ymd[2])
            res.year = Year(ymd[3])
        elseif monthindex == 2
            if ymd[1] > 31 || (yearfirst && ymd[3] <= 31)
                # 99-Jan-01
                res.year = Year(ymd[1])
                res.month = Month(ymd[2])
                res.day = Day(ymd[3])
            else
                # 01-Jan-01
                # Give precendence to day-first, since
                # two-digit years is usually hand-written.
                res.day = Day(ymd[1])
                res.month = Month(ymd[2])
                res.year = Year(ymd[3])
            end
        elseif monthindex == 3
            # WTF
            if ymd[2] > 31
                # 01-99-Jan
                res.day = Day(ymd[1])
                res.year = Year(ymd[2])
                res.month = Month(ymd[3])
            else
                res.year = Year(ymd[1])
                res.day = Day(ymd[2])
                res.month = Month(ymd[3])
            end
        else
            if ymd[1] > 31 || (yearfirst && ymd[2] <= 12 && ymd[3] <= 31)
                # 99-01-01
                res.year = Year(ymd[1])
                res.month = Month(ymd[2])
                res.day = Day(ymd[3])
            elseif ymd[1] > 12 || (dayfirst && ymd[2] <= 12)
                # 13-01-01
                res.day = Day(ymd[1])
                res.month = Month(ymd[2])
                res.year = Year(ymd[3])
            else
                # 01-13-01
                res.month = Month(ymd[1])
                res.day = Day(ymd[2])
                res.year = Year(ymd[3])
            end
        end
    end
    if !isnull(res.year)
        res.year = convertyear(get(res.year))
    end
end

function _tryparse(::Type{Month}, s::AbstractString; locale::AbstractString="english")
    name = lowercase(s)
    temp = Nullable{Int}(get(MONTHTOVALUE[locale], name, get(MONTHABBRTOVALUE[locale], name, nothing)))
    if isnull(temp)
        Nullable{Month}()
    else
        Nullable{Month}(Month(get(temp)))
    end
end

function _tryparse(::Type{DayOfWeek}, s::AbstractString; locale::AbstractString="english")
    name = lowercase(s)
    temp = Nullable{Int}(get(DAYOFWEEKTOVALUE[locale], name, get(DAYOFWEEKABBRTOVALUE[locale], name, nothing)))
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
 (hopefully not) then we can change the default to Year(today())"
function convertyear(year::Year, convert_year=Year(2000))
    value = year.value
    if value <= 99
        century = convert_year.value - (convert_year.value % 100)
        value += century
        if abs(value - convert_year.value) >= 50
            if value < convert_year.value
                value += 100
            else
                value -= 100
            end
        end
    end
    return Year(value)
end

function converthour(hour::Hour, ampm::Symbol)
    if hour.value < 12 && ampm == :pm
        hour = Hour(hour.value + 12)
    elseif hour.value == 12 && ampm == :am
        hour = Hour(0)
    end
    return hour
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
