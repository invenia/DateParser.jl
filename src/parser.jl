import Base.Dates: Date, DateTime
import TimeZones: TimeZone, ZonedDateTime

# Automatic parsing of DateTime strings. Based upon Python's dateutil parser
# https://labix.org/python-dateutil#head-a23e8ae0a661d77b89dfb3476f85b26f0b30349c

# Some pointers:
# http://www.cl.cam.ac.uk/~mgk25/iso-time.html
# http://www.w3.org/TR/NOTE-datetime
# http://new-pds-rings-2.seti.org/tools/time_formats.html
# http://search.cpan.org/~muir/Time-modules-2003.0211/lib/Time/ParseDate.pm

type DateParts
    year::Nullable{Int}
    month::Nullable{Int}
    day::Nullable{Int}
    hour::Nullable{Int}
    minute::Nullable{Int}
    second::Nullable{Int}
    millisecond::Nullable{Int}
    dayofweek::Nullable{Int}
    timezone::Nullable{TimeZone}

    DateParts() = new(
        nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,
    )
end

function DateParts(
    str::AbstractString;
    fuzzy::Bool=false,
    tzmap::Dict{AbstractString, TimeZone}=Dict{AbstractString, TimeZone}(), # Specify what a timezone is
    dayfirst::Bool=false, # MM-DD-YY vs DD-MM-YY
    yearfirst::Bool=false, # MM-DD-YY vs YY-MM-DD
    locale::AbstractString="english", # Locale in Dates.VALUETOMONTH and VALUETODAYOFWEEK
)
    res = DateParts()

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
                    res.hour = parse(Int, digit[9:10])
                    res.minute = parse(Int, digit[11:12])
                    if length(digit) > 12
                        res.second = parse(Int, digit[13:14])
                    end
                end

            elseif length(digit) == 9
                # HHMMSS[mil]
                res.hour = parse(Int, digit[1:2])
                res.minute = parse(Int, digit[3:4])
                res.second = parse(Int, digit[5:6])
                res.millisecond = parse(Int, digit[7:9])

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
                        res.minute = parse_as_decimal(decimal, 60) + get(res.minute, 0)
                    end
                    hint = :minute
                elseif label == :minute
                    res.minute = value
                    if decimal != ""
                        res.second = parse_as_decimal(decimal, 60) + get(res.second, 0)
                    end
                    hint = :second
                elseif label == :second
                    res.second = value
                    if decimal != ""
                        res.millisecond = parse_as_decimal(decimal, 1000) + get(res.millisecond, 0)
                    end
                    hint = :none
                end

            elseif (m = match(r"\G:(\d+)(?:\:(\d+))?(?:\.(\d+))?", str, index)) != nothing
                # HH:MM[:SS[.ss]]
                res.hour = parse(Int, digit)

                minute, second, decimal = m.captures
                index = nextind(str, index + endof(m.match) - 1)

                res.minute = parse(Int, minute)

                if second != nothing
                    res.second = parse(Int, second)
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
                period = AMPM[locale][lowercase(m["key"])]
                res.hour = normalize_hour(hour, period)
                index = nextind(str, index + endof(m.match) - 1)

            else
                value = parse(Int, digit)

                if length(digit) == 3 && isnull(res.millisecond)
                    res.millisecond = value
                elseif length(date_values) < 3
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
                elseif length(digit) == 4 && isnull(res.hour) && isnull(res.minute)
                    res.hour = parse(Int, digit[1:2])
                    res.minute = parse(Int, digit[3:4])
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
            isnull(res.hour) && error("Expected to find hour prior to the period indicator: $(m["key"])")
            period = AMPM[locale][lowercase(m["key"])]
            res.hour = normalize_hour(get(res.hour), period)
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

    # Determine order of year, month, and day digits
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
        year != nothing && (year = normalize_year(year))
        res.year, res.month, res.day = year, month, day
    end

    return res
end

function Date(dp::DateParts, default::Date=Date(current_year()))
    Date(
        get(dp.year, year(default)),
        get(dp.month, month(default)),
        get(dp.day, day(default)),
    )
end

function DateTime(dp::DateParts, default::DateTime=DateTime(current_year()))
    DateTime(
        get(dp.year, year(default)),
        get(dp.month, month(default)),
        get(dp.day, day(default)),
        get(dp.hour, hour(default)),
        get(dp.minute, minute(default)),
        get(dp.second, second(default)),
        get(dp.millisecond, millisecond(default))
    )
end

function ZonedDateTime(dp::DateParts, default::ZonedDateTime=ZonedDateTime(DateTime(current_year()), UTC))
    ZonedDateTime(
        DateTime(dp, DateTime(default)),
        get(dp.timezone, default.timezone),
    )
end
