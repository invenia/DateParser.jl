import Base.Dates: VALUETODAYOFWEEK, VALUETODAYOFWEEKABBR, VALUETOMONTH, VALUETOMONTHABBR
import TimeZones: FixedTimeZone

# Name to value translations
for name in ("DAYOFWEEK", "DAYOFWEEKABBR", "MONTH", "MONTHABBR")
    valueto = Symbol("VALUETO" * name)
    tovalue = Symbol(name * "TOVALUE")
    @eval begin
        const $tovalue = [locale => Dict{UTF8String,Int}(
            zip(map(lowercase, values(d)), keys(d))) for (locale, d) in $valueto]
    end
end

const HMS = Dict{UTF8String,Dict{UTF8String,Symbol}}(
    "english" => Dict(
        "h" => :hour,   "hour" => :hour,     "hours" => :hour,
        "m" => :minute, "minute" => :minute, "minutes" => :minute,
        "s" => :second, "second" => :second, "seconds" => :second,
    )
)
const AMPM = Dict{UTF8String,Dict{UTF8String,Symbol}}(
    "english" => Dict(
        "am" => :am, "a" => :am,
        "pm" => :pm, "p" => :pm,
    )
)
const JUMP = UTF8String[
    " ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m", "t", "of", "st",
    "nd", "rd", "th", "the",
]
const PERTAIN = UTF8String["of"]
const UTC_ZONES = UTF8String["UTC", "GMT", "Z"]

const UTC = FixedTimeZone("UTC", 0)
