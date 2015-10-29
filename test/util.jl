@test DateParser.parse_as_decimal("5") == 0.5
@test DateParser.parse_as_decimal("50") == 0.5
@test DateParser.parse_as_decimal("05") == 0.05
@test DateParser.parse_as_decimal("999") == 0.999

@test DateParser.parse_as_decimal("5", 1000) == 500
@test DateParser.parse_as_decimal("50", 1000) == 500
@test DateParser.parse_as_decimal("05", 1000) == 50
@test DateParser.parse_as_decimal("999", 1000) == 999
@test DateParser.parse_as_decimal("9999", 1000) == 1000  # 999.9


@test DateParser.normalize_year(0) == 2000
@test DateParser.normalize_year(10) == 2010
@test DateParser.normalize_year(95) == 1995
@test DateParser.normalize_year(49) == 2049
@test DateParser.normalize_year(50) == 1950
@test DateParser.normalize_year(50) == 1950
@test DateParser.normalize_year(2010) == 2010
@test DateParser.normalize_year(10, 2075) == 2110  # set current year to 2075


@test DateParser.normalize_hour(1, :am) == 1
@test DateParser.normalize_hour(1, :pm) == 13
@test DateParser.normalize_hour(12, :am) == 0
@test DateParser.normalize_hour(12, :pm) == 12

# Period indicator is misleading
@test DateParser.normalize_hour(0, :pm) == 0
@test DateParser.normalize_hour(23, :am) == 23


@test DateParser.regex_str(["A", "B", "C"]) == "\\QA\\E|\\QB\\E|\\QC\\E"


@test DateParser.current_year() == year(now())
