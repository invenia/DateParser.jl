module DateTimeParser

using Base.Dates
using TimeZones
import Base.Dates: VALUETODAYOFWEEK, VALUETODAYOFWEEKABBR, VALUETOMONTH, VALUETOMONTHABBR
export parsedate

# Automatic parsing of DateTime strings. Based upon Python's dateutil parser
# https://labix.org/python-dateutil#head-a23e8ae0a661d77b89dfb3476f85b26f0b30349c

# Some pointers:
# http://www.cl.cam.ac.uk/~mgk25/iso-time.html
# http://www.w3.org/TR/NOTE-datetime
# http://new-pds-rings-2.seti.org/tools/time_formats.html
# http://search.cpan.org/~muir/Time-modules-2003.0211/lib/Time/ParseDate.pm

const HMS = Dict{AbstractString, Int}(
    "h" => 1, "hour" => 1, "hours" => 1,
    "m" => 2, "minute" => 2, "minutes" => 2,
    "s" => 3, "second" => 3, "seconds" => 3,
)
const AMPM = Dict{AbstractString, Int}(
    "am" => 1, "a" => 1,
    "pm" => 2, "p" => 2,
)
const JUMP = (
    " ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m", "t", "of", "st",
    "nd", "rd", "th", "the",
)
const PERTAIN = ("of",)
const UTCZONE = ("utc", "gmt", "z",)

function parsedate(datetimestring::AbstractString, fuzzy::Bool=false;
    default::ZonedDateTime=ZonedDateTime(DateTime(today()),localzone()),
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
    ymd = []
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
            elseif tokenlength == 8
                # YYYYMMDD
                push!(ymd, parse(Int, token[1:4]))
                push!(ymd, parse(Int, token[5:6]))
                push!(ymd, parse(Int, token[7:8]))
            elseif tokenlength in (12,14)
                # YYYYMMDDhhmm[ss]
                push!(ymd, parse(Int, token[1:4]))
                push!(ymd, parse(Int, token[5:6]))
                push!(ymd, parse(Int, token[7:8]))
                res["hour"] = parse(Int, token[9:10])
                res["minute"] = parse(Int, token[11:12])
                if tokenlength == 14
                    res["second"] = parse(Int, token[13:14])
                end
            elseif (i <= len && haskey(HMS, lowercase(tokens[i]))) ||
                    (i+1 <= len && tokens[i] == " " && haskey(HMS, lowercase(tokens[i+1])))
                # HH[ ]h or MM[ ]m or SS[.ss][ ]s
                if tokens[i] == " "
                    i += 1
                end
                idx = HMS[lowercase(tokens[i])]
                while true
                    if idx == 1
                        temp = parse(Float64, token)
                        res["hour"] = floor(Int, temp)
                        temp = temp % 1
                        if temp != 0
                            res["minute"] = round(Int, 60 * temp)
                        end
                    elseif idx == 2
                        temp = parse(Float64, token)
                        res["minute"] = floor(Int, temp)
                        temp = temp % 1
                        if temp != 0
                            res["second"] = round(Int, 60 * temp)
                        end
                    elseif idx == 3
                        temp = parse(Float64, token)
                        res["second"] = floor(Int, temp)
                        temp = temp % 1
                        if temp != 0
                            res["millisecond"] = round(Int, 1000 * temp)
                        end
                    end
                    i += 1
                    if i > len || idx >= 3
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
                        else
                            idx += 1
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
                            if length(tokens[i]) <= 4
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
                    res["hour"] = round(Int, parse(Float64, token))
                    if res["hour"] < 12 && AMPM[lowercase(tokens[i+1])] == 2
                        res["hour"] += 12
                    elseif res["hour"] == 12 && AMPM[lowercase(tokens[i+1])] == 1
                        res["hour"] = 0
                    end
                    i += 2
                else
                    push!(ymd, round(Int, parse(Float64, token)))
                    if i > len || !haskey(monthtovalue, lowercase(tokens[i]))
                        i += 1
                    end
                end
            elseif i <= len && haskey(AMPM, lowercase(tokens[i]))
                # 12am
                res["hour"] = round(Int, parse(Float64, token))
                if res["hour"] < 12 && AMPM[lowercase(tokens[i])] == 2
                    res["hour"] += 12
                elseif res["hour"] == 12 && AMPM[lowercase(tokens[i])] == 1
                    res["hour"] = 0
                end
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
                value = AMPM[lowercase(tokens[i])]
                if value == 2 && res["hour"] < 12
                    res["hour"] += 12
                elseif value == 1 && res["hour"] == 12
                    res["hour"] = 0
                end
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
                    if tokenlength == 4
                        # -0300
                        res["tzoffset"] = parse(Int, tokens[i][1:2])*3600+parse(Int, tokens[i][3:end])*60
                    elseif i+1 <= len && tokens[i+1] == ":"
                        # -03:00
                        res["tzoffset"] = parse(Int, tokens[i])*3600+parse(Int, tokens[i+2])*60
                        i += 2
                    elseif tokenlength <= 2
                        # -[0]3
                        res["tzoffset"] = parse(Int, tokens[i])*3600
                    else
                        error("Faild to read timezone offset after +/-")
                    end
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
    if !haskey(res, "year") && !haskey(res, "month") && !haskey(res, "day")
        res["year"], res["month"], res["day"] = Dates.yearmonthday(default)
    else
        if haskey(res, "year")
            res["year"] = convertyear(res["year"])
        else
            res["year"] = year(default)
        end
        if !haskey(res, "month")
            res["month"] = 1
        end
        if !haskey(res, "day")
            res["day"] = 1
        end
    end
    if !haskey(res, "hour") && !haskey(res, "minute") && !haskey(res, "second") && !haskey(res, "millisecond")
        res["hour"] = hour(default)
        res["minute"] = minute(default)
        res["second"] = second(default)
        res["millisecond"] = millisecond(default)
    else
        if !haskey(res, "hour")
            res["hour"] = 0
        end
        if !haskey(res, "minute")
            res["minute"] = 0
        end
        if !haskey(res, "second")
            res["second"] = 0
        end
        if !haskey(res, "millisecond")
            res["millisecond"] = 0
        end
    end
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

# converts a 2 digit year to a 4 didgit one near year 2000 (e.g. 95 becomes 1995)
function convertyear(year::Int)
    if year > 99
        return year
    elseif year < 50
        return year + 2000
    else
        return year + 1900
    end
end

function _parsedatetokens(input::AbstractString)
    tokens = []
    regex = r"^(?P<token>(\d+\.\d+(?=[^\.\d]|$))|(\d+)|(((?=[^\d])\w)+))(?P<extra>.*)$"
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
