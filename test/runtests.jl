using DateTimeParser
using Base.Test

using TimeZones


timezone = TimeZone("Europe/Warsaw")
default = ZonedDateTime(DateTime(1976, 7, 4), timezone)
timezone_infos = Dict{AbstractString, TimeZone}(
    "TEST" => FixedTimeZone("TEST", 3600),
    "UTC" => FixedTimeZone("UTC", 0),
    "GMT" => FixedTimeZone("GMT", 0),
    "Etc/GMT+3" => FixedTimeZone("GMT+3", -10800),
)

# Test all code paths
@test parse(ZonedDateTime, "", default=default) == default
@test parse(DateTime, "", default=default) == DateTime(1976, 7, 4)
@test parse(Date, "", default=default) == Date(1976, 7, 4)
@test parse(DateTime, "19990203T2359", default=default) == DateTime(1999, 2, 3, 23, 59)
@test parse(DateTime, "990203", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "990203T235945.54", default=default) == DateTime(1999, 2, 3, 23, 59, 45, 540)
@test parse(DateTime, "19990203", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "19990203235945", default=default) == DateTime(1999, 2, 3, 23, 59, 45)
@test parse(DateTime, "12h30", default=default) == DateTime(1976, 7, 4, 12, 30)
@test parse(DateTime, "12h30s", default=default) == DateTime(1976, 7, 4, 12, 0, 30)
@test parse(DateTime, "12.5h", default=default) == DateTime(1976, 7, 4, 12, 30)
@test parse(DateTime, "12.5m", default=default) == DateTime(1976, 7, 4, 0, 12, 30)
@test parse(DateTime, "12.5s", default=default) == DateTime(1976, 7, 4, 0, 0, 12, 500)
@test parse(DateTime, "12:20.5", default=default) == DateTime(1976, 7, 4, 12, 20, 30)
@test parse(DateTime, "12:20:30.5", default=default) == DateTime(1976, 7, 4, 12, 20, 30, 500)
@test parse(DateTime, "2.3.99", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "2.3.1999", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "3.FEB.99", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "2/3/1999", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "1999/FEB/3", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "12 am", default=default) == DateTime(1976, 7, 4, 0)
@test parse(DateTime, "1 pm", default=default) == DateTime(1976, 7, 4, 13)
@test parse(DateTime, "12am", default=default) == DateTime(1976, 7, 4, 0)
@test parse(DateTime, "1pm", default=default) == DateTime(1976, 7, 4, 13)
@test parse(DateTime, "99 02 03", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "99FEB03", default=default) == DateTime(1999, 2, 3)
@test isnull(tryparse(DateTime, "99! Year FEB 03 Day", default=default))
@test parse(DateTime, "99! Year FEB 03 Day", fuzzy=true, default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "Thursday october the 13 1994", default=default) == DateTime(1994, 10, 13)
@test parse(DateTime, "February-03-1999", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "February of 1999", default=default) == DateTime(1999, 2, 4)
@test parse(DateTime, "12h am", default=default) == DateTime(1976, 7, 4, 0)
@test parse(DateTime, "1h pm", default=default) == DateTime(1976, 7, 4, 13)
@test parse(ZonedDateTime, "13h Etc/GMT+3", default=default, timezone_infos=timezone_infos).timezone.offset.utc == Dates.Second(-10800)
@test parse(ZonedDateTime, "13h +03:00", default=default).timezone.offset.utc == Dates.Second(10800)
@test parse(ZonedDateTime, "13h -0300", default=default).timezone.offset.utc == Dates.Second(-10800)
@test parse(ZonedDateTime, "13h +03", default=default).timezone.offset.utc == Dates.Second(10800)
@test parse(ZonedDateTime, "13h -3", default=default).timezone.offset.utc == Dates.Second(-10800)
@test parse(ZonedDateTime, "13h -0 (GMT)", default=default, timezone_infos=timezone_infos).timezone.offset.utc == Dates.Second(0)
@test isnull(tryparse(ZonedDateTime, "13h +"))
@test parse(DateTime, "february the 3rd 1999", default=default) == DateTime(1999, 2, 3)
@test isnull(tryparse(ZonedDateTime, "hi it's 99 february the 3rd", default=default))
@test parse(DateTime, "hi it's 99 february the 3rd", fuzzy=true, default=default) == DateTime(1999, 2, 3)
@test isnull(tryparse(ZonedDateTime, "1, 2, 3, 4", default=default))
@test parse(DateTime, "feb 3", default=default) == DateTime(1976, 2, 3)
@test parse(DateTime, "feb 1999", default=default) == DateTime(1999, 2, 4)
@test parse(DateTime, "1999", default=default) == DateTime(1999, 7, 4)
@test parse(DateTime, "99-02", default=default) == DateTime(1999, 2, 4)
@test parse(DateTime, "02-99", default=default) == DateTime(1999, 2, 4)
@test parse(DateTime, "02-03", default=default) == DateTime(1976, 2, 3)
@test parse(DateTime, "03-02", dayfirst=true, default=default) == DateTime(1976, 2, 3)
@test parse(DateTime, "FEB 03 99", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "99 FEB 03", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "03 FEB 04", default=default) == DateTime(2004, 2, 3)
@test parse(DateTime, "04 FEB 03", yearfirst=true, default=default) == DateTime(2004, 2, 3)
@test parse(DateTime, "03 99 FEB", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "04 03 FEB", default=default) == DateTime(2004, 2, 3)
@test parse(DateTime, "99 02 03", default=default) == DateTime(1999, 2, 3)
@test parse(DateTime, "04 02 03", yearfirst=true, default=default) == DateTime(2004, 2, 3)
@test parse(DateTime, "13 02 04", default=default) == DateTime(2004, 2, 13)
@test parse(DateTime, "03 02 04", dayfirst=true, default=default) == DateTime(2004, 2, 3)
@test parse(DateTime, "02 03 04", default=default) == DateTime(2004, 2, 3)
@test parse(DateTime, "2:30", default=default) == DateTime(1976, 7, 4, 2, 30)
@test parse(DateTime, "1999 2:30", default=default) == DateTime(1999, 7, 4, 2, 30)
@test parse(DateTime, "99 2:30", default=default) == DateTime(1999, 7, 4, 2, 30)
@test parse(DateTime, "22 2:30", default=default) == DateTime(1976, 7, 22, 2, 30)
@test parse(DateTime, "1994/10/13", default=default) == DateTime(1994, 10, 13, 0, 0, 0)
@test parse(DateTime, "13h", default=default) == DateTime(1976, 7, 4, 13, 0, 0, 0)
@test parse(DateTime, "13m", default=default) == DateTime(1976, 7, 4, 0, 13, 0, 0)
@test parse(DateTime, "13s", default=default) == DateTime(1976, 7, 4, 0, 0, 13, 0)
@test parse(DateTime, "0.5s", default=default) == DateTime(1976, 7, 4, 0, 0, 0, 500)
@test parse(ZonedDateTime, "1999", default=default).timezone == default.timezone
@test parse(ZonedDateTime, "1999 2:30 TEST", timezone_infos=timezone_infos, default=default).timezone == timezone_infos["TEST"]
@test parse(ZonedDateTime, "1999 2:30 WET", default=default).timezone.name == :WET
@test parse(ZonedDateTime, "1999 2:30 Z", default=default).timezone == FixedTimeZone("UTC", 0)
@test isnull(tryparse(ZonedDateTime, "1999 2:30 FAIL", default=default))
@test parse(ZonedDateTime, "1999 2:30 +01:00", default=default).timezone.name == :local
@test parse(ZonedDateTime, "1999 2:30 +01:00", default=default).timezone.offset.utc == Dates.Second(3600)
@test parse(ZonedDateTime, "1999 2:30 -01:00 (TEST)", default=default).timezone.name == :TEST
@test parse(ZonedDateTime, "1999 2:30 -01:00 (TEST)", default=default).timezone.offset.utc == Dates.Second(-3600)
@test parse(ZonedDateTime, "1999 2:30 America/Winnipeg", default=default).timezone.name == symbol("America/Winnipeg")

@test parse(DateTime, "21:38, 30 May 2006 (UTC)", default=default, timezone_infos=timezone_infos) == DateTime(2006, 5, 30, 21, 38)

@test parse(DateTime, "2015.10.02 10:21:59.45", default=default) == DateTime(2015, 10, 2, 10, 21, 59, 450)

# Test tryparse
@test get(tryparse(ZonedDateTime, "Oct 13, 1994 12:10:14 UTC", default=default, timezone_infos=timezone_infos)) == ZonedDateTime(DateTime(1994, 10, 13, 12, 10, 14), FixedTimeZone("UTC", 0))
@test isnull(tryparse(ZonedDateTime, "garbage"))
@test get(tryparse(DateTime, "Oct 13, 1994 12:10:14 UTC", default=default, timezone_infos=timezone_infos)) == DateTime(1994, 10, 13, 12, 10, 14)
@test isnull(tryparse(DateTime, "garbage"))
@test get(tryparse(Date, "Oct 13, 1994 12:10:14 UTC", default=default, timezone_infos=timezone_infos)) == Date(1994, 10, 13)
@test isnull(tryparse(Date, "garbage"))


# Examples I found in Python's dateutil's pointers links
date = ZonedDateTime(DateTime(1995, 2, 4), timezone)
@test parse(ZonedDateTime, "1995-02-04", default=default) == date
@test parse(ZonedDateTime, "2/4/95", default=default) == date
@test parse(ZonedDateTime, "4/2/95", default=default, dayfirst=true) == date
@test parse(ZonedDateTime, "95/2/4", default=default) == date
@test parse(ZonedDateTime, "4.2.1995", default=default, dayfirst=true) == date
@test parse(ZonedDateTime, "04-FEB-1995", default=default) == date
@test parse(ZonedDateTime, "4-February-1995", default=default) == date
@test parse(ZonedDateTime, "19950204", default=default) == date
@test parse(ZonedDateTime, "1995FEB04", default=default) == date

@test parse(DateTime, "1995-02", default=default) == DateTime(1995, 2, 4)
@test parse(DateTime, "1995", default=default) == DateTime(1995, 7, 4)

@test parse(DateTime, "1997", default=default) == DateTime(1997, 7, 4)
@test parse(DateTime, "1997-07", default=default) == DateTime(1997, 7, 4)
@test parse(DateTime, "1997-07-16", default=default) == DateTime(1997, 7, 16)
@test parse(DateTime, "1997-07-16T19:20+01:00", default=default) == DateTime(1997, 7, 16, 19, 20)
@test parse(DateTime, "1997-07-16T19:20:30+01:00", default=default) == DateTime(1997, 7, 16, 19, 20, 30)
@test parse(DateTime, "1997-07-16T19:20:30.45+01:00", default=default) == DateTime(1997, 7, 16, 19, 20, 30, 450)

date = DateTime(1976, 7, 4)
@test parse(DateTime, "July 4, 1976", default=default) == date
@test parse(DateTime, "7 4 1976", default=default) == date
@test parse(DateTime, "4 jul 1976", default=default) == date
@test parse(DateTime, "7-4-76", default=default) == date
@test parse(DateTime, "19760704", default=default) == date

@test parse(DateTime, "0:01:02", default=default) == DateTime(1976, 7, 4, 0, 1, 2)
@test isnull(tryparse(DateTime, "0 1 2", default=default))  # month of 0 not valid
@test parse(DateTime, "12h 59.00s am", default=default) == DateTime(1976, 7, 4, 0, 0, 59)
@test parse(DateTime, "59s", default=default) == DateTime(1976, 7, 4, 0, 0, 59)
@test parse(DateTime, "1 m 2s", default=default) == DateTime(1976, 7, 4, 0, 1, 2)

@test parse(DateTime, "0:01:02 on July 4, 1976", default=default) == DateTime(1976, 7, 4, 0, 1, 2)
@test parse(DateTime, "1976-07-04T00:01:02Z", default=default) == DateTime(1976, 7, 4, 0, 1, 2)
@test parse(DateTime, "July 4, 1976 12:01:02 am", default=default) == DateTime(1976, 7, 4, 0, 1, 2)

@test parse(DateTime, "23:59:59", default=default) == DateTime(1976, 7, 4, 23, 59, 59)
@test parse(DateTime, "23:59", default=default) == DateTime(1976, 7, 4, 23, 59)
@test parse(DateTime, "2359", default=default) == DateTime(2359,7, 4)
@test parse(DateTime, "23", default=default) == DateTime(1976, 7, 23)
@test parse(DateTime, "23:59:59.9942", default=default) == DateTime(1976, 7, 4, 23, 59, 59, 994)
@test parse(DateTime, "1995-02-05 00:00", default=default) == DateTime(1995, 2, 5)
@test parse(DateTime, "19951231T235959", default=default) == DateTime(1995, 12, 31, 23, 59, 59)

@test parse(DateTime, "1995-02-04 22:45:00", default=default) == DateTime(1995, 2, 4, 22, 45)

@test parse(DateTime, "23:59:59Z", default=default) == DateTime(1976, 7, 4, 23, 59, 59)
@test parse(DateTime, "12:00Z", default=default) == DateTime(1976, 7, 4, 12)
@test parse(DateTime, "13:00+01:00", default=default) == DateTime(1976, 7, 4, 13)
