using DateTimeParser
using Base.Test

using TimeZones


timezone = TimeZone("Europe/Warsaw")
default = ZonedDateTime(DateTime(1976, 7, 4), timezone)

# Test all code paths
@test parsedate("", default=default) == default
@test DateTime(parsedate("19990203T2359", default=default)) == DateTime(1999, 2, 3, 23, 59)
@test DateTime(parsedate("990203", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("990203T235945.54", default=default)) == DateTime(1999, 2, 3, 23, 59, 45, 540)
@test DateTime(parsedate("19990203", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("19990203235945", default=default)) == DateTime(1999, 2, 3, 23, 59, 45)
@test DateTime(parsedate("12h30", default=default)) == DateTime(1976, 7, 4, 12, 30)
@test DateTime(parsedate("12h30s", default=default)) == DateTime(1976, 7, 4, 12, 0, 30)
@test DateTime(parsedate("12.5h", default=default)) == DateTime(1976, 7, 4, 12, 30)
@test DateTime(parsedate("12.5m", default=default)) == DateTime(1976, 7, 4, 0, 12, 30)
@test DateTime(parsedate("12.5s", default=default)) == DateTime(1976, 7, 4, 0, 0, 12, 500)
@test DateTime(parsedate("12:20.5", default=default)) == DateTime(1976, 7, 4, 12, 20, 30)
@test DateTime(parsedate("12:20:30.5", default=default)) == DateTime(1976, 7, 4, 12, 20, 30, 500)
@test DateTime(parsedate("2.3.99", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("2.3.1999", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("3.FEB.99", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("2/3/1999", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("1999/FEB/3", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("12 am", default=default)) == DateTime(1976, 7, 4, 0)
@test DateTime(parsedate("1 pm", default=default)) == DateTime(1976, 7, 4, 13)
@test DateTime(parsedate("12am", default=default)) == DateTime(1976, 7, 4, 0)
@test DateTime(parsedate("1pm", default=default)) == DateTime(1976, 7, 4, 13)
@test DateTime(parsedate("99 02 03", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("99FEB03", default=default)) == DateTime(1999, 2, 3)
@test_throws ErrorException parsedate("8! 99 Year FEB 03 Day", default=default)
@test DateTime(parsedate("8! 99 Year FEB 03 Day", true, default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("Thursday october the 13 1994")) == DateTime(1994, 10, 13)
@test DateTime(parsedate("February-03-1999")) == DateTime(1999, 2, 3)
@test DateTime(parsedate("February of 1999")) == DateTime(1999, 2)
@test DateTime(parsedate("12h am", default=default)) == DateTime(1976, 7, 4, 0)
@test DateTime(parsedate("1h pm", default=default)) == DateTime(1976, 7, 4, 13)
@test parsedate("13h GMT+3", default=default).timezone.offset.utc == Dates.Second(-10800)
@test parsedate("13h +03:00", default=default).timezone.offset.utc == Dates.Second(10800)
@test parsedate("13h -0300", default=default).timezone.offset.utc == Dates.Second(-10800)
@test parsedate("13h +03", default=default).timezone.offset.utc == Dates.Second(10800)
@test parsedate("13h -3", default=default).timezone.offset.utc == Dates.Second(-10800)
@test parsedate("13h -0 (GMT)", default=default).timezone.offset.utc == Dates.Second(0)
@test_throws ErrorException parsedate("13h +")
@test DateTime(parsedate("february the 3rd 1999", default=default)) == DateTime(1999, 2, 3)
@test_throws ErrorException parsedate("hi it's 99 february the 3rd", default=default)
@test DateTime(parsedate("hi it's 99 february the 3rd", true, default=default)) == DateTime(1999, 2, 3)
@test_throws ErrorException parsedate("1, 2, 3, 4", default=default)
@test DateTime(parsedate("feb 3", default=default)) == DateTime(1976, 2, 3)
@test DateTime(parsedate("feb 1999", default=default)) == DateTime(1999, 2)
@test DateTime(parsedate("1999", default=default)) == DateTime(1999)
@test DateTime(parsedate("99-02", default=default)) == DateTime(1999, 2)
@test DateTime(parsedate("02-99", default=default)) == DateTime(1999, 2)
@test DateTime(parsedate("02-03", default=default)) == DateTime(1976, 2, 3)
@test DateTime(parsedate("03-02", dayfirst=true, default=default)) == DateTime(1976, 2, 3)
@test DateTime(parsedate("FEB 03 99", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("99 FEB 03", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("03 FEB 04", default=default)) == DateTime(2004, 2, 3)
@test DateTime(parsedate("04 FEB 03", yearfirst=true, default=default)) == DateTime(2004, 2, 3)
@test DateTime(parsedate("03 99 FEB", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("04 03 FEB", default=default)) == DateTime(2004, 2, 3)
@test DateTime(parsedate("99 02 03", default=default)) == DateTime(1999, 2, 3)
@test DateTime(parsedate("04 02 03", yearfirst=true, default=default)) == DateTime(2004, 2, 3)
@test DateTime(parsedate("13 02 04", default=default)) == DateTime(2004, 2, 13)
@test DateTime(parsedate("03 02 04", dayfirst=true, default=default)) == DateTime(2004, 2, 3)
@test DateTime(parsedate("02 03 04", default=default)) == DateTime(2004, 2, 3)
@test DateTime(parsedate("2:30", default=default)) == DateTime(1976, 7, 4, 2, 30)
@test DateTime(parsedate("1999 2:30", default=default)) == DateTime(1999, 1, 1, 2, 30)
@test DateTime(parsedate("99 2:30", default=default)) == DateTime(1999, 1, 1, 2, 30)
@test DateTime(parsedate("22 2:30", default=default)) == DateTime(1976, 1, 22, 2, 30)
@test DateTime(parsedate("1994/10/13", default=default)) == DateTime(1994, 10, 13, 0, 0, 0)
@test DateTime(parsedate("13h", default=default)) == DateTime(1976, 7, 4, 13, 0, 0, 0)
@test DateTime(parsedate("13m", default=default)) == DateTime(1976, 7, 4, 0, 13, 0, 0)
@test DateTime(parsedate("13s", default=default)) == DateTime(1976, 7, 4, 0, 0, 13, 0)
@test DateTime(parsedate("0.5s", default=default)) == DateTime(1976, 7, 4, 0, 0, 0, 500)
@test parsedate("1999", default=default).timezone == default.timezone
timezone_infos = Dict{String, TimeZone}("TEST" => FixedTimeZone("TEST", 3600))
@test parsedate("1999 2:30 TEST", timezone_infos=timezone_infos, default=default).timezone == timezone_infos["TEST"]
@test parsedate("1999 2:30 WET", default=default).timezone.name == :WET
@test parsedate("1999 2:30 Z", default=default).timezone == TimeZone("UTC")
@test_throws ErrorException parsedate("1999 2:30 FAIL")
@test parsedate("1999 2:30 +01:00").timezone.name == :local
@test parsedate("1999 2:30 +01:00").timezone.offset.utc == Dates.Second(3600)
@test parsedate("1999 2:30 TEST -01:00").timezone.name == :TEST
@test parsedate("1999 2:30 TEST -01:00").timezone.offset.utc == Dates.Second(-3600)


# Examples I found in Python's dateutil's pointers links
date = ZonedDateTime(DateTime(1995, 2, 4), timezone)
@test parsedate("1995-02-04", default=default) == date
@test parsedate("2/4/95", default=default) == date
@test parsedate("4/2/95", default=default, dayfirst=true) == date
@test parsedate("95/2/4", default=default) == date
@test parsedate("4.2.1995", default=default, dayfirst=true) == date
@test parsedate("04-FEB-1995", default=default) == date
@test parsedate("4-February-1995", default=default) == date
@test parsedate("19950204", default=default) == date
@test parsedate("1995FEB04", default=default) == date

@test DateTime(parsedate("1995-02", default=default)) == DateTime(1995, 2)
@test DateTime(parsedate("1995", default=default)) == DateTime(1995)

@test DateTime(parsedate("1997", default=default)) == DateTime(1997)
@test DateTime(parsedate("1997-07", default=default)) == DateTime(1997, 07)
@test DateTime(parsedate("1997-07-16", default=default)) == DateTime(1997, 07, 16)
@test DateTime(parsedate("1997-07-16T19:20+01:00", default=default)) == DateTime(1997, 07, 16, 19, 20)
@test DateTime(parsedate("1997-07-16T19:20:30+01:00", default=default)) == DateTime(1997, 07, 16, 19, 20, 30)
@test DateTime(parsedate("1997-07-16T19:20:30.45+01:00", default=default)) == DateTime(1997, 07, 16, 19, 20, 30, 450)

date = DateTime(1976, 7, 4)
@test DateTime(parsedate("July 4, 1976", default=default)) == date
@test DateTime(parsedate("7 4 1976", default=default)) == date
@test DateTime(parsedate("4 jul 1976", default=default)) == date
@test DateTime(parsedate("7-4-76", default=default)) == date
@test DateTime(parsedate("19760704", default=default)) == date

@test DateTime(parsedate("0:01:02", default=default)) == DateTime(1976, 7, 4, 0, 1, 2)
@test_throws ArgumentError parsedate("0 1 2", default=default)  # month of 0 not valid
@test DateTime(parsedate("12h 59.00s am", default=default)) == DateTime(1976, 7, 4, 0, 0, 59)
@test DateTime(parsedate("59s", default=default)) == DateTime(1976, 7, 4, 0, 0, 59)
@test DateTime(parsedate("1 m 2s", default=default)) == DateTime(1976, 7, 4, 0, 1, 2)

@test DateTime(parsedate("0:01:02 on July 4, 1976")) == DateTime(1976, 7, 4, 0, 1, 2)
@test DateTime(parsedate("1976-07-04T00:01:02Z")) == DateTime(1976, 7, 4, 0, 1, 2)
@test DateTime(parsedate("July 4, 1976 12:01:02 am")) == DateTime(1976, 7, 4, 0, 1, 2)

@test DateTime(parsedate("23:59:59", default=default)) == DateTime(1976, 7, 4, 23, 59, 59)
@test DateTime(parsedate("23:59", default=default)) == DateTime(1976, 7, 4, 23, 59)
@test DateTime(parsedate("2359", default=default)) == DateTime(2359)
@test DateTime(parsedate("23", default=default)) == DateTime(1976, 1, 23)
@test DateTime(parsedate("23:59:59.9942", default=default)) == DateTime(1976, 7, 4, 23, 59, 59, 994)
@test DateTime(parsedate("1995-02-05 00:00", default=default)) == DateTime(1995, 2, 5)
@test DateTime(parsedate("19951231T235959", default=default)) == DateTime(1995, 12, 31, 23, 59, 59)

@test DateTime(parsedate("1995-02-04 22:45:00")) == DateTime(1995, 2, 4, 22, 45)

@test DateTime(parsedate("23:59:59Z", default=default)) == DateTime(1976, 7, 4, 23, 59, 59)
@test DateTime(parsedate("12:00Z", default=default)) == DateTime(1976, 7, 4, 12)
@test DateTime(parsedate("13:00+01:00", default=default)) == DateTime(1976, 7, 4, 13)
