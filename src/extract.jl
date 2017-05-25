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
        hour, minute = map(d -> d != nothing ? Base.parse(Int, d) : 0, m.captures[3:end])
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
