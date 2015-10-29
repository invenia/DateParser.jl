import Base.Dates: unix2datetime, year

"""
Parses a `String` containing an `Integer` as the fractional part of a `Float`.

e.g. parse_as_decimal(\"5\") = 0.5
     parse_as_decimal(\"450\") = 0.450
"""
function parse_as_decimal(s::AbstractString)
    parse(Int, s) / 10^length(s)
    # parse(Float64, string(".", s))
end

"""
Parses a `String` containing an `Integer` as the fractional part of a `Float`.
The multiplier is applied to the fractional value and an `Integer` is returned.

e.g. parse_as_decimal(\"450\", 1000) = 450
"""
function parse_as_decimal(s::AbstractString, multiplier::Integer)
    round(Int, parse_as_decimal(s) * multiplier)
end

"""
Converts years represented with two digits to their absolute form. The current_year
parameter allows you to adjust how two digit years are interpreted. The resulting year will
always be within 50 years of the current_year. Note: at the moment the current_year is fixed
to the year 2000. Hopefully in the year 2050 we've got away from this practise but if we
have not we should change the default to be `year(today())`.
"""
function normalize_year(year::Integer, current_year::Integer=2000)
    if 0 <= year <= 99
        current_century = current_year - (current_year % 100)
        year += current_century

        if abs(year - current_year) >= 50
            if year < current_year
                year += 100
            else
                year -= 100
            end
        end
    end
    return year
end

function normalize_hour(hour::Integer, period::Symbol)
    if period == :pm && 0 < hour < 12
        hour = hour + 12
    elseif period == :am && hour == 12
        hour = 0
    end

    return hour
end

"""
Convenience function for converting an iterable of `AbstractString` as regex formatted
String. Note each AbstractString will be quoted such that special characters in the string
are not treated as a regex.
"""
function regex_str(iter)
    # Note: Collecting iterator as sort(::KeyIterator) doesn't exist
    # sort(collect(iter), by=length, rev=true)
    join(["\\Q$el\\E" for el in iter], "|")
end

current_year() = year(unix2datetime(time()))
