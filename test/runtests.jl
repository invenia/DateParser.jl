using DateTimeParser
using Base.Test

using TimeZones

# Examples if found in Python's dateutil's pointers links
timezone = TimeZone("Europe/Warsaw")
date = ZonedDateTime(DateTime(1995, 2, 4), timezone)
default = ZonedDateTime(DateTime(1969, 08, 16), timezone)
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

default = ZonedDateTime(DateTime(1976, 7, 4), timezone)
@test DateTime(parsedate("0:01:02", default=default)) == DateTime(1976, 7, 4, 0, 1, 2)
@test_throws ArgumentError parsedate("0 1 2", default=default)  # month of 0 not valid
@test DateTime(parsedate("12h 59.00s am", default=default)) == DateTime(1976, 7, 4, 0, 0, 59)
@test DateTime(parsedate("59s", default=default)) == DateTime(1976, 7, 4, 0, 0, 59)
@test DateTime(parsedate("1 m 2s", default=default)) == DateTime(1976, 7, 4, 0, 1, 2)

@test DateTime(parsedate("0:01:02 on July 4, 1976")) == DateTime(1976, 7, 4, 0, 1, 2)
@test DateTime(parsedate("1976-07-04T00:01:02Z")) == DateTime(1976, 7, 4, 0, 1, 2)
@test DateTime(parsedate("July 4, 1976 12:01:02 am")) == DateTime(1976, 7, 4, 0, 1, 2)

@test DateTime(parsedate("23:59:59", default=default)) == DateTime(1976, 7, 4, 23, 59, 59)
@test DateTime(parsedate("235959", default=default)) == DateTime(1976, 7, 4, 23, 59, 59)
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
