import Base.Dates: LOCALES
import TimeZones: FixedTimeZone

# TODO: We should probably make a struct like DateLocale instead of doing this.
for (name, field) in [
    (:DAYOFWEEK, :day_of_week_value),
    (:DAYOFWEEKABBR, :day_of_week_abbr_value),
    (:MONTH, :month_value),
    (:MONTHABBR, :month_abbr_value),
]
    valueto = Symbol(:VALUETO, name)
    tovalue = Symbol(name, :TOVALUE)

    @eval begin
        const $tovalue = Dict(
            locale => data.$field
            for (locale, data) in LOCALES
        )

        const $valueto = Dict(
            locale => Dict(
                b => lowercase(a)
                for (a, b) in data.$field
            )
            for (locale, data) in LOCALES
        )
    end
end

const HMS = Dict(
    "english" => Dict(
        "h" => :hour,   "hour" => :hour,     "hours" => :hour,
        "m" => :minute, "minute" => :minute, "minutes" => :minute,
        "s" => :second, "second" => :second, "seconds" => :second,
    )
)
const AMPM = Dict(
    "english" => Dict(
        "am" => :am, "a" => :am,
        "pm" => :pm, "p" => :pm,
    )
)
const JUMP = [
    " ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m", "t", "of", "st",
    "nd", "rd", "th", "the",
]
const PERTAIN = ["of"]
const UTC_ZONES = ["UTC", "GMT", "Z", "z"]

const UTC = FixedTimeZone("UTC", 0)
