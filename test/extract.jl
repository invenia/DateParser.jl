import TimeZones: TimeZone, FixedTimeZone

@test DateParser.extract_dayofweek("Monday") == (1, 7)
@test DateParser.extract_dayofweek("Wed") == (3, 4)
@test DateParser.extract_dayofweek("Tuednesday") == nothing

@test DateParser.extract_month("January") == (1, 8)
@test DateParser.extract_month("Oct") == (10, 4)
@test DateParser.extract_month("Febtober") == nothing

@test DateParser.extract_tz("UTC") == (FixedTimeZone("UTC", 0), 4)
@test DateParser.extract_tz("GMT") == (FixedTimeZone("GMT", 0), 4)
@test DateParser.extract_tz("Z") == (FixedTimeZone("UTC", 0), 2)

@test DateParser.extract_tz("+1") == (FixedTimeZone("+1", 3600), 3)
@test DateParser.extract_tz("-01") == (FixedTimeZone("-01", -3600), 4)
@test DateParser.extract_tz("+2:00") == (FixedTimeZone("+2:00", 7200), 6)
@test DateParser.extract_tz("-02:00") == (FixedTimeZone("-02:00", -7200), 7)
@test DateParser.extract_tz("+0200") == (FixedTimeZone("+0200", 7200), 6)
@test DateParser.extract_tz("+12345") == nothing
@test DateParser.extract_tz(" +X") == nothing

# Names prior to offsets require preceeding whitespace
@test DateParser.extract_tz("UTC+1") == nothing
@test DateParser.extract_tz(" UTC+1", 2) == (FixedTimeZone("UTC+1", 3600), 7)
@test DateParser.extract_tz(" BRT-05:00", 2) == (FixedTimeZone("BRT-05:00", -3600 * 5), 11)
@test DateParser.extract_tz(" Europe/Warsaw-02:00", 2) == nothing
@test DateParser.extract_tz("-5:00 (BRT)") == (FixedTimeZone("BRT", -3600 * 5), 12)
@test DateParser.extract_tz("-0 (GMT)") == (FixedTimeZone("GMT", 0), 9)

# Note: Ignores the manually specified offset
@test DateParser.extract_tz("-02:00 (Europe/Warsaw)") == (TimeZone("Europe/Warsaw"), 23)

@test DateParser.extract_tz("Europe/Warsaw") == (TimeZone("Europe/Warsaw"), 14)
@test DateParser.extract_tz("MST7MDT") == (TimeZone("MST7MDT"), 8)
@test DateParser.extract_tz("Asia/Ho_Chi_Minh") == (TimeZone("Asia/Ho_Chi_Minh"), 17)
@test DateParser.extract_tz("America/North_Dakota/New_Salem") == (TimeZone("America/North_Dakota/New_Salem"),31)
@test DateParser.extract_tz("America/Port-au-Prince") == (TimeZone("America/Port-au-Prince"), 23)

@test DateParser.extract_tz("Europe / Warsaw") == nothing

# Allow users to supply name to TimeZone mappings
etc_gmt3 = FixedTimeZone("GMT+3", -10800)
mapping = Dict{AbstractString,TimeZone}("Etc/GMT+3" => etc_gmt3)
@test DateParser.extract_tz("Etc/GMT+3") == nothing
@test DateParser.extract_tz("Etc/GMT+3", 1, tzmap=mapping) == (etc_gmt3, 10)
