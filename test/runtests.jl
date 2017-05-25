import DateParser: parse, tryparse
using Base.Test

using Base.Dates
using TimeZones

import DateParser: UTC

include("extract.jl")
include("processymd.jl")
include("util.jl")

# win32 uses Int32 and Base only has a convert for a Nullable of the same type
@test get(convert(Nullable{Int64}, Int32(6))) == 6

# Basic parsing tests
@test parse(Date, "Oct 13, 1994 12:10:14 UTC") == Date(1994, 10, 13)
@test parse(DateTime, "Oct 13, 1994 12:10:14 UTC") == DateTime(1994, 10, 13, 12, 10, 14)
@test parse(ZonedDateTime, "Oct 13, 1994 12:10:14 UTC") == ZonedDateTime(DateTime(1994, 10, 13, 12, 10, 14), FixedTimeZone("UTC", 0))

@test isequal(tryparse(Date, "Oct 13, 1994 12:10:14 UTC"), Nullable{Date}(Date(1994, 10, 13)))
@test isequal(tryparse(DateTime, "Oct 13, 1994 12:10:14 UTC"), Nullable{DateTime}(DateTime(1994, 10, 13, 12, 10, 14)))
@test isequal(tryparse(ZonedDateTime, "Oct 13, 1994 12:10:14 UTC"), Nullable{ZonedDateTime}(ZonedDateTime(DateTime(1994, 10, 13, 12, 10, 14), FixedTimeZone("UTC", 0))))

# Make sure that default isn't used when we can't parse the string.
@test_throws ErrorException parse(Date, "garbage")
@test_throws ErrorException parse(DateTime, "garbage")
@test_throws ErrorException parse(ZonedDateTime, "garbage")

@test isequal(tryparse(Date, "garbage"), Nullable{Date}())
@test isequal(tryparse(DateTime, "garbage"), Nullable{DateTime}())
@test isequal(tryparse(ZonedDateTime, "garbage"), Nullable{ZonedDateTime}())


@test parse(DateTime, "1997") == DateTime(1997, 1, 1)
@test parse(DateTime, "1997-07") == DateTime(1997, 7, 1)
@test parse(DateTime, "1997-07-16") == DateTime(1997, 7, 16)
@test parse(DateTime, "1997-07-16T19:20+01:00") == DateTime(1997, 7, 16, 19, 20)
@test parse(DateTime, "1997-07-16T19:20:30+01:00") == DateTime(1997, 7, 16, 19, 20, 30)
@test parse(DateTime, "1997-07-16T19:20:30.45+01:00") == DateTime(1997, 7, 16, 19, 20, 30, 450)


# Fill in missing pieces of data with the default
warsaw = TimeZone("Europe/Warsaw")
date = Date(1976, 7, 4)
dt = DateTime(date)
zdt = ZonedDateTime(dt, warsaw)

@test parse(Date, "", default=date) == date
@test parse(DateTime, "", default=dt) == dt
@test parse(ZonedDateTime, "", default=zdt) == zdt


# Almost completely numeric formats
@test parse(DateTime, "1999") == DateTime(1999, 1, 1)
@test parse(DateTime, "990203") == DateTime(1999, 2, 3)
@test parse(DateTime, "19990203") == DateTime(1999, 2, 3)
@test parse(DateTime, "19990203235945") == DateTime(1999, 2, 3, 23, 59, 45)
@test parse(DateTime, "19990203T2359") == DateTime(1999, 2, 3, 23, 59)
@test parse(DateTime, "990203T235945.54") == DateTime(1999, 2, 3, 23, 59, 45, 540)
@test parse(DateTime, "1, 2, 3, 4") == DateTime(2003, 1, 2, 4)
@test parse(DateTime, "1999 04 05 13 59 59 99") == DateTime(1999, 4, 5, 13, 59, 59, 99)
@test parse(DateTime, "1999 04 05 13 59 59 999") == DateTime(1999, 04, 05, 13, 59, 59, 999)
@test parse(DateTime, "1999 04 05 1359") == DateTime(1999, 4, 5, 13, 59)
@test parse(DateTime, "19990405 135959") == DateTime(1999, 4, 5, 13, 59, 59)
@test_throws ErrorException parse(DateTime, "19990405 1359599")
# @test_throws ErrorException parse(DateTime, "1999 04 05 13595999")
@test parse(DateTime, "1999 04 05 135959999") == DateTime(1999, 4, 5, 13, 59, 59, 999)
@test parse(DateTime, "19990405 135959999") == DateTime(1999, 4, 5, 13, 59, 59, 999)
@test parse(DateTime, "301213", yearfirst=true) == Date(2030, 12, 13)
@test parse(DateTime, "301213", dayfirst=true) == Date(2013, 12, 30)


# MMYYYY is not supported because it will parse as three two digit date tokens
@test parse(Date, "102015") == Date(2015, 10, 20)


# Parse only a time portion. Provide a default portion for the date.
default = DateTime(1997, 7, 6)
@test parse(DateTime, "12h30", default=default) == DateTime(1997, 7, 6, 12, 30)
@test parse(DateTime, "12h30s", default=default) == DateTime(1997, 7, 6, 12, 0, 30)
@test parse(DateTime, "12m30", default=default) == DateTime(1997, 7, 6, 0, 12, 30)
@test parse(DateTime, "30s5m12h", default=default) == DateTime(1997, 7, 6, 12, 5, 30)
@test parse(DateTime, "12.5h", default=default) == DateTime(1997, 7, 6, 12, 30)
@test parse(DateTime, "12.5m", default=default) == DateTime(1997, 7, 6, 0, 12, 30)
@test parse(DateTime, "12.5s", default=default) == DateTime(1997, 7, 6, 0, 0, 12, 500)
@test parse(DateTime, "12:20.5", default=default) == DateTime(1997, 7, 6, 12, 20, 30)
@test parse(DateTime, "12:20:30.5", default=default) == DateTime(1997, 7, 6, 12, 20, 30, 500)
@test parse(DateTime, "12 am", default=default) == DateTime(1997, 7, 6, 0)
@test parse(DateTime, "1 pm", default=default) == DateTime(1997, 7, 6, 13)
@test parse(DateTime, "9am", default=default) == DateTime(1997, 7, 6, 9)
@test parse(DateTime, "4pm", default=default) == DateTime(1997, 7, 6, 16)
@test parse(DateTime, "12h am", default=default) == DateTime(1997, 7, 6, 0)
@test parse(DateTime, "1h pm", default=default) == DateTime(1997, 7, 6, 13)
@test parse(DateTime, "2:30", default=default) == DateTime(1997, 7, 6, 2, 30)
@test parse(DateTime, "13h", default=default) == DateTime(1997, 7, 6, 13, 0, 0, 0)
@test parse(DateTime, "13m", default=default) == DateTime(1997, 7, 6, 0, 13, 0, 0)
@test parse(DateTime, "13s", default=default) == DateTime(1997, 7, 6, 0, 0, 13, 0)
@test parse(DateTime, "0.5s", default=default) == DateTime(1997, 7, 6, 0, 0, 0, 500)


# Parse date only portion
@test parse(DateTime, "2.3.99") == DateTime(1999, 2, 3)
@test parse(DateTime, "2.3.1999") == DateTime(1999, 2, 3)
@test parse(DateTime, "3.FEB.99") == DateTime(1999, 2, 3)
@test parse(DateTime, "1999/2/3", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "2/3/1999") == DateTime(1999, 2, 3)
@test parse(DateTime, "1999/FEB/3") == DateTime(1999, 2, 3)
@test parse(DateTime, "1999/3/FEB") == DateTime(1999, 2, 3)
@test parse(DateTime, "99 02 03") == DateTime(1999, 2, 3)
@test parse(DateTime, "99FEB03") == DateTime(1999, 2, 3)
@test parse(DateTime, "Thursday october the 13 1994") == DateTime(1994, 10, 13)
@test parse(DateTime, "February-03-1999") == DateTime(1999, 2, 3)
@test parse(DateTime, "February of 1999") == DateTime(1999, 2, 1)
@test parse(DateTime, "february the 3rd 1999") == DateTime(1999, 2, 3)
@test parse(DateTime, "FEB 03 99") == DateTime(1999, 2, 3)
@test parse(DateTime, "99 FEB 03") == DateTime(1999, 2, 3)
@test parse(DateTime, "03 FEB 04") == DateTime(2004, 2, 3)
@test parse(DateTime, "04 FEB 03", yearfirst=true) == DateTime(2004, 2, 3)
@test parse(DateTime, "03 99 FEB") == DateTime(1999, 2, 3)
@test parse(DateTime, "04 03 FEB") == DateTime(2004, 2, 3)
@test parse(DateTime, "04 02 03") == DateTime(2003, 4, 2)
@test parse(DateTime, "04 02 03", yearfirst=true) == DateTime(2004, 2, 3)
@test parse(DateTime, "04 02 03", dayfirst=true) == DateTime(2003, 2, 4)

@test_throws ErrorException parse(DateTime, "1999-10-13 pm")
@test_throws ErrorException parse(DateTime, "1/b/c")
@test_throws ErrorException parse(DateTime, "1/b/3")


default = DateTime(1976, 7, 4)
@test parse(DateTime, "feb 3", default=default) == DateTime(1976, 2, 3)
@test parse(DateTime, "feb 1999", default=default) == DateTime(1999, 2, 4)
@test parse(DateTime, "1999", default=default) == DateTime(1999, 7, 4)
@test parse(DateTime, "99-02", default=default) == DateTime(1999, 2, 4)
@test parse(DateTime, "02-99", default=default) == DateTime(1999, 2, 4)
@test parse(DateTime, "02-03", default=default) == DateTime(1976, 2, 3)
@test parse(DateTime, "03-02", default=default, dayfirst=true) == DateTime(1976, 2, 3)
@test parse(DateTime, "1999 2:30", default=default) == DateTime(1999, 7, 4, 2, 30)
@test parse(DateTime, "99 2:30", default=default) == DateTime(1999, 7, 4, 2, 30)
@test parse(DateTime, "22 2:30", default=default) == DateTime(1976, 7, 22, 2, 30)



# TimeZones
@test parse(ZonedDateTime, "02:30, 1 Jan 1999 UTC") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), FixedTimeZone("UTC", 0))
@test parse(ZonedDateTime, "1999 2:30 Z") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), FixedTimeZone("UTC", 0))
@test parse(ZonedDateTime, "1999 2:30 WET") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), TimeZone("WET"))
@test parse(ZonedDateTime, "1999 2:30 Europe/Warsaw") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), TimeZone("Europe/Warsaw"))
@test parse(ZonedDateTime, "1999 2:30 MST7MDT") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), TimeZone("MST7MDT"))
@test parse(ZonedDateTime, "1999 2:30 +01:00") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), FixedTimeZone("+01:00", 3600))
@test parse(ZonedDateTime, "1999 2:30 -01:00 (TEST)") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), FixedTimeZone("TEST", -3600))
@test parse(ZonedDateTime, "1999 2:30 UTC+1:00") == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), FixedTimeZone("UTC+1:00", 3600))

# Parse a timezone unknown by the TimeZones library
map = Dict{AbstractString,TimeZone}("TEST" => FixedTimeZone("TEST", -7200))
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 TEST")
@test parse(ZonedDateTime, "1999 2:30 TEST", tzmap=map) ==  ZonedDateTime(DateTime(1999, 1, 1, 2, 30), map["TEST"])

# When both tzmap and the offset are set go with the tzmap.
@test parse(ZonedDateTime, "1999 2:30 -01:00 (TEST)", tzmap=map) == ZonedDateTime(DateTime(1999, 1, 1, 2, 30), map["TEST"])

# Unsupported formats
@test_throws ErrorException parse(ZonedDateTime, "02:30, 1 Jan 1999 (UTC)")
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 (FOO) +1:00")
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 +1:00 FOO")
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 (America/Winnipeg)")
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 (BAD-)")
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 (UTC+1:00)")
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 +25:00")  # Out of range
@test_throws ErrorException parse(ZonedDateTime, "1999 2:30 +00:62")  # Out of range


# Fuzzy parsing
let str = "99! Year FEB 03 Day"
    @test_throws ErrorException parse(DateTime, str)
    @test parse(DateTime, str, fuzzy=true) == DateTime(1999, 2, 3)
end

let str = "hi it's 99 february the 3rd"
    @test_throws ErrorException parse(DateTime, str)
    @test parse(DateTime, str, fuzzy=true) == DateTime(1999, 2, 3)
end

let str = "1999 04 05 13 59 59 99 92"
    @test_throws ErrorException parse(DateTime, str)
    # @test parse(DateTime, str, fuzzy=true) == DateTime(1999, 04, 05, 13, 59, 59, 999)
    @test parse(DateTime, str, fuzzy=true) == DateTime(1999, 04, 05, 13, 59, 59, 99)
end

# Additional formats
@test parse(ZonedDateTime, "21:38, 30 May 2006 UTC") == ZonedDateTime(DateTime(2006, 5, 30, 21, 38), FixedTimeZone("UTC", 0))
@test parse(ZonedDateTime, "2015.10.02 10:21:59.45") == ZonedDateTime(DateTime(2015, 10, 2, 10, 21, 59, 450), FixedTimeZone("UTC", 0))

# Overflow
@test parse(DateTime, "dec 2 2015 24:00:00", overflow=true) == DateTime(2015, 12, 03)
@test parse(DateTime, "dec 2 2015 168h", overflow=true) == DateTime(2015, 12, 09)
@test parse(DateTime, "dec 29 1999 99:99:99.999", overflow=true) == DateTime(2000, 01, 02, 04, 40, 39, 999)


# Alternative locales
DateParser.DAYOFWEEKTOVALUE["french"] = Dict(
    "lundi" => 1, "mardi" => 2, "mercredi" => 3, "jeudi" => 4,
    "vendredi" => 5, "samedi" => 6, "dimanche" => 7,
)
DateParser.DAYOFWEEKABBRTOVALUE["french"] = Dict(
    "lun" => 1, "mar" => 2, "mer" => 3, "jeu" => 4, "ven" => 5, "sam" => 6, "dim" => 7,
)
DateParser.MONTHTOVALUE["french"] = Dict(
    "janvier" => 1, "février" => 2, "mars" => 3, "avril" => 4, "mai" => 5, "juin" => 6,
    "juillet" => 7, "août" => 8, "septembre" => 9, "octobre" => 10, "novembre" => 11,
    "décembre" => 12,
)
DateParser.MONTHABBRTOVALUE["french"] = Dict(
    "janv" => 1, "févr" => 2, "mars" => 3, "avril" => 4, "mai" => 5, "juin" => 6,
    "juil" => 7, "août" => 8, "sept" => 9, "oct" => 10, "nov" => 11, "déc" => 12,
)
DateParser.HMS["french"] = DateParser.HMS["english"]
DateParser.AMPM["french"] = DateParser.AMPM["english"]

@test parse(DateTime, "28 mai 2014", locale="french") == DateTime(2014, 5, 28)
@test parse(DateTime, "28 févr 2014", locale="french") == DateTime(2014, 2, 28)
@test parse(DateTime, "jeu 28 août 2014", locale="french") == DateTime(2014, 8, 28)
@test parse(DateTime, "lundi 28 avril 2014", locale="french") == DateTime(2014, 4, 28)
@test parse(DateTime, "28 févr 2014", locale="french") == DateTime(2014, 2, 28)
# @test parse(DateTime, "12 am", locale="french") == DateTime(1976, 7, 4, 0)
# @test parse(DateTime, "1 pm", locale="french", default=default_dt) == DateTime(1976, 7, 4, 13)


### Additional tests derived from external resources ###


# Tests derived from: http://www.cl.cam.ac.uk/~mgk25/iso-time.html
expected_date = Date(1995, 2, 4)
@test parse(Date, "1995-02-04") == expected_date
@test parse(Date, "2/4/95") == expected_date
@test parse(Date, "4/2/95", dayfirst=true) == expected_date
@test parse(Date, "95/2/4") == expected_date
@test parse(Date, "4.2.1995", dayfirst=true) == expected_date
@test parse(Date, "04-FEB-1995") == expected_date
@test parse(Date, "4-February-1995") == expected_date
@test parse(Date, "19950204") == expected_date
@test parse(Date, "1995FEB04") == expected_date
@test parse(Date, "February 4, 1995") == expected_date

@test parse(Date, "19950204") == expected_date
@test parse(Date, "1995-02") == Date(1995, 2, 1)
@test parse(Date, "1995") == Date(1995, 1, 1)
# @test parse(Date, "1997-W01") == Date(1997, 1, 1)
# @test parse(Date, "1997W01") == Date(1997, 1, 1)
# @test parse(Date, "1997-W01-2") == Date(1997, 1, 2)
# @test parse(Date, "1997W012") == Date(1997, 1, 2)
# @test parse(Date, "1995W05") == Date(1995, X, Y)
# @test parse(Date, "1995-035") == Date(1995, X, Y)
# @test parse(Date, "1995035") == Date(1995, X, Y)

default_dt = DateTime(1997, 1, 1)
@test parse(DateTime, "23:59:59", default=default_dt) == DateTime(1997, 1, 1, 23, 59, 59)
# We don't support 235959 because xxyyzz is xx/yy/20zz and not xx:yy:zz
# @test parse(DateTime, "235959", default=default_dt) == DateTime(1997, 1, 1, 23, 59, 59)
@test parse(DateTime, "23:59", default=default_dt) == DateTime(1997, 1, 1, 23, 59)
# We don't support 2359 because xxyy is a year and not xx:yy
# @test parse(DateTime, "2359", default=default_dt) == DateTime(1997, 1, 1, 23, 59)
# We don't support 23, it's ambiguous and shouldn't be used
# @test parse(DateTime, "23", default=default_dt) == DateTime(1997, 1, 1, 23)
@test parse(DateTime, "23:59:59.9942", default=default_dt) == DateTime(1997, 1, 1, 23, 59, 59, 994)
@test parse(DateTime, "235959.9942", default=default_dt) == DateTime(1997, 1, 1, 23, 59, 59, 994)
@test parse(DateTime, "1995-02-04 24:00", overflow=true) == Date(1995, 2, 5)
@test parse(DateTime, "19951231T235959", default=default_dt) == DateTime(1995, 12, 31, 23, 59, 59)

default_zdt = ZonedDateTime(DateTime(1997, 1, 1), FixedTimeZone("GMT", 0))
@test parse(ZonedDateTime, "23:59:59Z", default=default_zdt) == ZonedDateTime(DateTime(1997, 1, 1, 23, 59, 59), FixedTimeZone("UTC", 0))
@test parse(ZonedDateTime, "12:00Z", default=default_zdt) == ZonedDateTime(DateTime(1997, 1, 1, 12), FixedTimeZone("UTC", 0))
@test parse(ZonedDateTime, "13:00+01:00", default=default_zdt) == ZonedDateTime(DateTime(1997, 1, 1, 13), FixedTimeZone("+01:00", 3600))
# TODO add support for this
# @test parse(ZonedDateTime, "0700-0500", default=default_zdt) == ZonedDateTime(DateTime(1997, 1, 1, 7), FixedTimeZone("-0500", -18000))


# Tests derived from: http://www.w3.org/TR/NOTE-datetime
@test parse(Date, "1997") == Date(1997, 1, 1)
@test parse(Date, "1997-07") == Date(1997, 7, 1)
@test parse(Date, "1997-07-16") == Date(1997, 7, 16)

tz = FixedTimeZone("+01:00", 3600)
@test parse(ZonedDateTime, "1997-07-16T19:20+01:00") == ZonedDateTime(DateTime(1997, 7, 16, 19, 20), tz)
@test parse(ZonedDateTime, "1997-07-16T19:20:30+01:00") == ZonedDateTime(DateTime(1997, 7, 16, 19, 20, 30), tz)
@test parse(ZonedDateTime, "1997-07-16T19:20:30.45+01:00") == ZonedDateTime(DateTime(1997, 7, 16, 19, 20, 30, 450), tz)


# Tests created from: http://new-pds-rings-2.seti.org/tools/time_formats.html
expected_date = DateTime(1976, 7, 4)
@test parse(Date, "July 4, 1976") == expected_date
@test parse(Date, "7 4 1976") == expected_date
@test parse(Date, "4 jul 1976") == expected_date
@test parse(Date, "7-4-76") == expected_date
@test parse(Date, "19760704") == expected_date
# @test parse(Date, "76/186") == expected_date
# @test parse(Date, "76.186") == expected_date

default_dt = DateTime(1976, 7, 4)
expected_dt = DateTime(1976, 7, 4, 0, 1, 2)
@test parse(DateTime, "0:01:02", default=default_dt) == expected_dt
# We don't support 0 1 2 being 00:01:02 because it is 2000-01-02T00:00:00
# @test parse(DateTime, "0 1 2", default=default_dt) == expected_dt
@test parse(DateTime, "12h 62.00s am", default=default_dt, overflow=true) == expected_dt
@test parse(DateTime, "62s", default=default_dt, overflow=true) == expected_dt
@test parse(DateTime, "1 m 2s 000z", default=default_dt) == expected_dt
@test parse(DateTime, "1 m 2s 000", default=default_dt) == expected_dt

@test parse(DateTime, "0:01:02 on July 4, 1976") == expected_dt
@test parse(DateTime, "7 4 76 0 1 2") == expected_dt
@test parse(DateTime, "1976-07-04T00:01:02Z") == expected_dt
@test parse(DateTime, "July 4, 1976 12:01:02 am") == expected_dt
# @test parse(DateTime, "0 1 2 19760704") == expected_dt
# @test parse(DateTime, "MJD 42963.00071759259") == expected_dt
