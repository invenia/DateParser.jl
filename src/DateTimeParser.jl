module DateTimeParser

using Base.Dates
using TimeZones
import Base.Dates: VALUETODAYOFWEEK, VALUETODAYOFWEEKABBR, VALUETOMONTH, VALUETOMONTHABBR
export parse, tryparse


function Base.tryparse(::Type{ZonedDateTime}, str::AbstractString; args...)
    try
        return Nullable{ZonedDateTime}(parse(ZonedDateTime, str; args...))
    catch
        return Nullable{ZonedDateTime}()
    end
end
function Base.tryparse(::Type{DateTime}, str::AbstractString; args...)
    try
        return Nullable{DateTime}(parse(DateTime, str; args...))
    catch
        return Nullable{DateTime}()
    end
end
function Base.tryparse(::Type{Date}, str::AbstractString; args...)
    try
        return Nullable{Date}(parse(Date, str; args...))
    catch
        return Nullable{Date}()
    end
end

Base.parse(::Type{ZonedDateTime}, str::AbstractString; args...) = parsedate(str; args...)
Base.parse(::Type{DateTime}, str::AbstractString; args...) = DateTime(parsedate(str; args...))
Base.parse(::Type{Date}, str::AbstractString; args...) = Date(DateTime(parsedate(str; args...)))

# Automatic parsing of DateTime strings. Based upon Python's dateutil parser
# https://labix.org/python-dateutil#head-a23e8ae0a661d77b89dfb3476f85b26f0b30349c

# Some pointers:
# http://www.cl.cam.ac.uk/~mgk25/iso-time.html
# http://www.w3.org/TR/NOTE-datetime
# http://new-pds-rings-2.seti.org/tools/time_formats.html
# http://search.cpan.org/~muir/Time-modules-2003.0211/lib/Time/ParseDate.pm

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

function parsedate(datetimestring::AbstractString; fuzzy::Bool=false,
    default::ZonedDateTime=ZonedDateTime(DateTime(year(today())), TimeZone("UTC")),
    timezone_infos::Dict{AbstractString, TimeZone} = Dict{AbstractString, TimeZone}(), # Specify what a timezone is
    dayfirst::Bool=false, # MM-DD-YY vs DD-MM-YY
    yearfirst::Bool=false, # MM-DD-YY vs YY-MM-DD
    locale::AbstractString="english", # Locale in Dates.VALUETOMONTH and VALUETODAYOFWEEK
)
    datetimestring = strip(datetimestring)

    if isempty(datetimestring)
        return default
    end

    weekday = Dict{UTF8String, Int}()
    for (value, name) in VALUETODAYOFWEEK[locale]
        weekday[lowercase(name)] = value
    end
    for (value, name) in VALUETODAYOFWEEKABBR[locale]
        weekday[lowercase(name)] = value
    end

    monthtovalue = Dict{UTF8String, Int}()
    for (value, name) in VALUETOMONTH[locale]
        monthtovalue[lowercase(name)] = value
    end
    for (value, name) in VALUETOMONTHABBR[locale]
        monthtovalue[lowercase(name)] = value
    end

    res = Dict()

    # year/month/day list
    ymd = sizehint!(Int[], 3)
    # Index of the month string in ymd
    mstridx = -1

    tokens = _parsedatetokens(datetimestring)
    len = length(tokens)
    i = 1
    while i <= len
        token = tokens[i]
        tokenlength = length(token)
        # Check if it's a number
        if !isnull(tryparse(Float64, tokens[i]))
            # Token is a number
            i += 1
            if length(ymd) == 3 && tokenlength in (2,4) &&
                (i>=len || (tokens[i] != ":" && !haskey(HMS, lowercase(tokens[i]))))
                # 19990101T23[59]
                res["hour"] = parse(Int, token[1:2])
                if tokenlength == 4
                    res["minute"] = parse(Int, token[3:4])
                end
            elseif tokenlength == 6 || (tokenlength > 6 && search(token, '.') == 7)
                # YYMMDD or HHMMSS[.ss]
                if length(ymd) == 0 && !contains(token, ".")
                    push!(ymd, convertyear(parse(Int, token[1:2])))
                    push!(ymd, parse(Int, token[3:4]))
                    push!(ymd, parse(Int, token[5:end]))
                else
                    # 19990101T235959[.59]
                    res["hour"] = parse(Int, token[1:2])
                    res["minute"] = parse(Int, token[3:4])
                    temp = parse(Float64, token[5:end])
                    res["second"] = floor(Int, temp)
                    res["millisecond"] = round(Int, (temp % 1) * 1000)
                end
            elseif tokenlength in (8, 12, 14)
                # YYYYMMDD[hhmm[ss]]
                push!(ymd, parse(Int, token[1:4]))
                push!(ymd, parse(Int, token[5:6]))
                push!(ymd, parse(Int, token[7:8]))
                if tokenlength > 8
                    res["hour"] = parse(Int, token[9:10])
                    res["minute"] = parse(Int, token[11:12])
                    if tokenlength > 12
                        res["second"] = parse(Int, token[13:14])
                    end
                end
            elseif (i <= len && haskey(HMS, lowercase(tokens[i]))) ||
                    (i+1 <= len && tokens[i] == " " && haskey(HMS, lowercase(tokens[i+1])))
                # HH[ ]h or MM[ ]m or SS[.ss][ ]s
                if tokens[i] == " "
                    i += 1
                end
                idx = HMS[lowercase(tokens[i])]
                while true
                    if idx == :hour
                        temp = parse(Float64, token)
                        res["hour"] = floor(Int, temp)
                        temp = temp % 1
                        if temp != 0
                            res["minute"] = round(Int, 60 * temp)
                        end
                    elseif idx == :minute
                        temp = parse(Float64, token)
                        res["minute"] = floor(Int, temp)
                        temp = temp % 1
                        if temp != 0
                            res["second"] = round(Int, 60 * temp)
                        end
                    elseif idx == :second
                        temp = parse(Float64, token)
                        res["second"] = floor(Int, temp)
                        temp = temp % 1
                        if temp != 0
                            res["millisecond"] = round(Int, 1000 * temp)
                        end
                    end
                    i += 1
                    if i > len || idx == :second
                        break
                    end
                    # 12h00
                    token = tokens[i]
                    if isnull(tryparse(Float64, token))
                        break
                    else
                        i += 1
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
                res["hour"] = floor(Int, parse(Float64, token))
                i += 1
                value = parse(Float64, tokens[i])
                res["minute"] = floor(Int, value)
                if value % 1 != 0
                    res["second"] = round(Int, 60 * (value % 1))
                end
                i += 1
                if i < len && tokens[i] == ":"
                    temp = parse(Float64, tokens[i+1])
                    res["second"] = floor(Int, temp)
                    res["millisecond"] = round(Int, temp%1*1000)
                    i += 2
                end
            elseif i <= len && tokens[i] in ("-","/",".")
                sep = tokens[i]
                push!(ymd, round(Int, parse(Float64, token)))
                i += 1
                if i <= len && !(lowercase(tokens[i]) in JUMP)
                    if isnull(tryparse(Float64, tokens[i]))
                        if haskey(monthtovalue, lowercase(tokens[i]))
                            push!(ymd, monthtovalue[lowercase(tokens[i])])
                            mstridx = length(ymd)
                        end
                    else
                        temp = parse(Float64, tokens[i])
                        push!(ymd, floor(Int, temp))
                        if temp % 1 != 0
                            if length(tokens[i]) <= 5
                                # DD.YY
                                push!(ymd, round(Int, (temp % 1) * 100))
                            else
                                # DD.YYYY
                                push!(ymd, round(Int, (temp % 1) * 10000))
                            end
                        end
                    end
                    i += 1
                    if i <= len && tokens[i] == sep
                        # We have three members
                        i += 1
                        if haskey(monthtovalue, lowercase(tokens[i]))
                            push!(ymd, monthtovalue[lowercase(tokens[i])])
                            mstridx = len(ymd)
                        else
                            push!(ymd, round(Int, parse(Float64, tokens[i])))
                        end
                        i += 1
                    end
                end
            elseif i > len || lowercase(tokens[i]) in JUMP ||
                    haskey(monthtovalue, lowercase(tokens[i]))
                if i+1 <= len && haskey(AMPM, lowercase(tokens[i+1]))
                    # 12 am
                    i += 1
                    res["hour"] = round(Int, parse(Float64, token))
                    res["hour"] = converthour(res["hour"], AMPM[lowercase(tokens[i])])
                    i += 1
                else
                    push!(ymd, round(Int, parse(Float64, token)))
                    if i > len || !haskey(monthtovalue, lowercase(tokens[i]))
                        i += 1
                    end
                end
            elseif i <= len && haskey(AMPM, lowercase(tokens[i]))
                # 12am
                res["hour"] = round(Int, parse(Float64, token))
                res["hour"] = converthour(res["hour"], AMPM[lowercase(tokens[i])])
                i += 1
            elseif !fuzzy
                error("Failed to parse date")
            else
                i += 1
            end
        else
            # Token is not a number
            if haskey(weekday, lowercase(token))
                # Weekday
                res["weekday"] = weekday[lowercase(token)]
                i += 1
            elseif haskey(monthtovalue, lowercase(token))
                # Month name
                push!(ymd, round(Int, monthtovalue[lowercase(token)]))
                mstridx = length(ymd)
                i += 1
                if i <= len
                    if tokens[i] in ("-", "/")
                        # Jan-01[-99]
                        sep = tokens[i]
                        i += 1
                        push!(ymd, round(Int, parse(Float64, tokens[i])))
                        i += 1
                        if i <= len && tokens[i] == sep
                            # Jan-01-99
                            i += 1
                            push!(ymd, round(Int, parse(Float64, tokens[i])))
                            i += 1
                        end
                    elseif (i+3 <= len && tokens[i] == tokens[i+2] == " " &&
                            tokens[i+1] in PERTAIN)
                        # Jan of 01
                        # In this case, 01 is clearly year
                        try
                            # Make a guess
                            value = parse(Int, tokens[i+3])
                            # Convert it here to become unambiguous
                            push!(ymd, convertyear(value))
                        end
                        i += 4
                    end
                end
            elseif haskey(AMPM, lowercase(tokens[i]))
                # am/pm
                res["hour"] = converthour(res["hour"], AMPM[lowercase(tokens[i])])
                i += 1
            elseif haskey(res, "hour") && !haskey(res, "tzname") &&
                    !haskey(res, "tzoffset") &&
                    ismatch(r"^\w*$", tokens[i]) && !(lowercase(tokens[i]) in JUMP)
                # Timezone name
                res["tzname"] = tokens[i]
                while i+2 <= len && tokens[i+1] == "/"
                    res["tzname"] = string(res["tzname"], "/", tokens[i+2])
                    i += 2
                end
                i += 1
                # Check for something like GMT+3, or BRST+3. Notice
                # that it doesn't mean "I am 3 hours after GMT", but
                # "my time +3 is GMT". If found, we reverse the
                # logic so that timezone parsing code will get it
                # right.
                if i <= len && tokens[i] in ("+", "-")
                    tokens[i] = tokens[i] == "+" ? "-" : "+"
                    if lowercase(res["tzname"]) in UTCZONE
                        # With something like GMT+3, the timezone
                        # is *not* GMT.
                        delete!(res, "tzname")
                    end
                end
            elseif haskey(res, "hour") && tokens[i] in ("+", "-")
                # Numbered timzone
                signal = tokens[i] == "+" ? 1 : -1
                try
                    i += 1
                    tokenlength = length(tokens[i])
                    hour = minute = 0
                    if tokenlength == 4
                        # -0300
                        hour, minute = parse(Int, tokens[i][1:2]), parse(Int, tokens[i][3:end])
                    elseif i+1 <= len && tokens[i+1] == ":"
                        # -03:00
                        hour, minute = parse(Int, tokens[i]), parse(Int, tokens[i+2])
                        i += 2
                    elseif tokenlength <= 2
                        # -[0]3
                        hour = parse(Int, tokens[i])
                    else
                        error("Faild to read timezone offset after +/-")
                    end
                    res["tzoffset"] = hour * 3600 + minute * 60
                catch
                    error("Faild to read timezone offset after +/-")
                end
                i += 1
                res["tzoffset"] *= signal
            elseif i+2 <= len && tokens[i] == "(" &&
                    tokens[i+2] == ")" && ismatch(r"^\w*$", tokens[i+1])
                # Look for a timezone name between parenthesis
                # -0300 (BRST)
                res["tzname"] = tokens[i+1]
                i += 3
            elseif !(lowercase(tokens[i]) in JUMP) && !fuzzy
                error("Failed to parse date")
            else
                i += 1
            end
        end
    end

    # Process year/month/day
    len_ymd = length(ymd)

    if len_ymd > 3
        # More than three members!?
        error("Failed to parse date")
    elseif len_ymd == 1 || (mstridx != -1 && len_ymd == 2)
        # One member, or two members with a month string
        if mstridx != -1
            res["month"] = ymd[mstridx]
            deleteat!(ymd, mstridx)
        end
        if len_ymd > 1 || mstridx == -1
            if ymd[1] > 31
                res["year"] = ymd[1]
            else
                res["day"] = ymd[1]
            end
        end
    elseif len_ymd == 2
        # Two members with numbers
        if ymd[1] > 31
            # 99-01
            res["year"], res["month"] = ymd
        elseif ymd[2] > 31
            # 01-99
            res["month"], res["year"] = ymd
        elseif dayfirst && ymd[2] <= 12
            # 13-01
            res["day"], res["month"] = ymd
        else
            # 01-13
            res["month"], res["day"] = ymd
        end
    elseif len_ymd == 3
        # Three members
        if mstridx == 1
            res["month"], res["day"], res["year"] = ymd
        elseif mstridx == 2
            if ymd[1] > 31 || (yearfirst && ymd[3] <= 31)
                # 99-Jan-01
                res["year"], res["month"], res["day"] = ymd
            else
                # 01-Jan-01
                # Give precendence to day-first, since
                # two-digit years is usually hand-written.
                res["day"], res["month"], res["year"] = ymd
            end
        elseif mstridx == 3
            # WTF
            if ymd[2] > 31
                # 01-99-Jan
                res["day"], res["year"], res["month"] = ymd
            else
                res["year"], res["day"], res["month"] = ymd
            end
        else
            if ymd[1] > 31 || (yearfirst && ymd[2] <= 12 && ymd[3] <= 31)
                # 99-01-01
                res["year"], res["month"], res["day"] = ymd
            elseif ymd[1] > 12 || (dayfirst && ymd[2] <= 12)
                # 13-01-01
                res["day"], res["month"], res["year"] = ymd
            else
                # 01-13-01
                res["month"], res["day"], res["year"] = ymd
            end
        end
    end

    # Fill in default values if none exits
    res["year"] = convertyear(get(res, "year", year(default)))
    get!(res, "month", month(default))
    get!(res, "day", day(default))
    get!(res, "hour", hour(default))
    get!(res, "minute", minute(default))
    get!(res, "second", second(default))
    get!(res, "millisecond", millisecond(default))

    # determine timezone
    if !haskey(res, "tzname") && !haskey(res, "tzoffset")
        res["timezone"] = default.timezone
    elseif !haskey(res, "tzoffset")
        if haskey(timezone_infos, res["tzname"])
            res["timezone"] = timezone_infos[res["tzname"]]
        elseif res["tzname"] in TimeZones.timezone_names()
            res["timezone"] = TimeZone(res["tzname"])
        elseif lowercase(res["tzname"]) in UTCZONE
            res["timezone"] = TimeZone("utc")
        else
            error("Failed to parse date")
        end
    elseif !haskey(res, "tzname")
        res["timezone"] = FixedTimeZone("local",res["tzoffset"])
    else
        res["timezone"] = FixedTimeZone(res["tzname"], res["tzoffset"])
    end

    return ZonedDateTime(DateTime(res["year"], res["month"], res["day"], res["hour"],
            res["minute"], res["second"], res["millisecond"]), res["timezone"])
end

"Converts a 2 digit year to a 4 digit one within 50 years of convert_year. At the momment
 convert_year defaults to 2000, if people are still using 2 digit years after year 2049
 (hopefully not) then we can change the default to year(today())"
function convertyear(year::Int, convert_year=2000)
    if year <= 99
        century = convert_year - convert_year % 100
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

function converthour(hour::Int, ampm::Symbol)
    if hour < 12 && ampm == :pm
        hour += 12
    elseif hour == 12 && ampm == :am
        hour = 0
    end
    return hour
end

function _parsedatetokens(input::AbstractString)
    tokens = AbstractString[]
    regex = r"^(?<token>(\d+\.\d+(?=[^\.\d]|$))|(\d+)|(((?=[^\d])\w)+))(?<extra>.*)$"
    input = strip(input)
    while !isempty(input)
        if ismatch(regex,input)
            tokenmatch = match(regex, input)
            push!(tokens, tokenmatch["token"])
            input = tokenmatch["extra"]
        else
            if ismatch(r"\s", string(input[1:1]))
                push!(tokens, " ")
            else
                push!(tokens, input[1:1])
            end
            input = strip(input[2:end])
        end
    end
    return tokens
end

end # module
