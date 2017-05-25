import Base.Dates: VALUETODAYOFWEEK, VALUETODAYOFWEEKABBR, VALUETOMONTH, VALUETOMONTHABBR
import TimeZones: FixedTimeZone

# Forces Dicts to store UTF8String on Julia 0.4.
# Note: The Dict type parameters can be dropped when support for Julia 0.4 is dropped.
const String = VERSION < v"0.5" ? UTF8String : Base.String

# Name to value translations
for name in ("DAYOFWEEK", "DAYOFWEEKABBR", "MONTH", "MONTHABBR")
    valueto = Symbol("VALUETO" * name)
    tovalue = Symbol(name * "TOVALUE")

    @eval const $tovalue = Dict([
        Pair(locale, Dict([
            Pair(lowercase(b), a)
            for (a, b) in d
        ]))
        for (locale, d) in $valueto
    ])

    # Better version for Julia v0.5+ only
    # @eval const $tovalue = Dict(
    #     locale => Dict(
    #         lowercase(b) => a
    #         for (a, b) in d
    #     )
    #     for (locale, d) in $valueto
    # )
end

const HMS = Dict{String, Dict{String, Symbol}}(
    "english" => Dict(
        "h" => :hour,   "hour" => :hour,     "hours" => :hour,
        "m" => :minute, "minute" => :minute, "minutes" => :minute,
        "s" => :second, "second" => :second, "seconds" => :second,
    )
)
const AMPM = Dict{String, Dict{String, Symbol}}(
    "english" => Dict(
        "am" => :am, "a" => :am,
        "pm" => :pm, "p" => :pm,
    )
)
const JUMP = String[
    " ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m", "t", "of", "st",
    "nd", "rd", "th", "the",
]
const PERTAIN = String["of"]
const UTC_ZONES = String["UTC", "GMT", "Z", "z"]

const UTC = FixedTimeZone("UTC", 0)
