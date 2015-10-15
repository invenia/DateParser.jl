# DateParser

[![Build Status](https://travis-ci.org/invenia/DateTimeParser.jl.svg?branch=master)](https://travis-ci.org/invenia/DateTimeParser.jl)
[![Coverage Status](https://coveralls.io/repos/invenia/DateTimeParser.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/invenia/DateTimeParser.jl?branch=master)
[![codecov.io](http://codecov.io/github/invenia/DateTimeParser.jl/coverage.svg?branch=master)](http://codecov.io/github/invenia/DateTimeParser.jl?branch=master)


Automatic parsing of date strings

## Usage

`DateTimeParser` adds `Date`, `DateTime`, and `ZonedDateTime` to `Base.parse` and `Base.tryparse`.

```julia
julia> using DateTimeParser

julia> parse(DateTime, "Oct 13, 1994 17:10")
1994-10-13T17:10:00

julia> using TimeZones

julia> parse(ZonedDateTime, "Oct 13, 1994 17:10 -05:00")
1994-10-13T17:10:00-05:00
```

Use the `fuzzy` keyword Argument for fuzzy parsing. If `fuzzy=true` unknown tokens in the string will be ignored. By default `fuzzy=false`.

```julia
julia> tryparse(DateTime, "It is Oct 13, 1994 at around 17:10")
Nullable{DateTime}()

julia> tryparse(DateTime, "It is Oct 13, 1994 at around 17:10", fuzzy=true)
Nullable(1994-10-13T17:10:00)
```

If you want to fill in omitted fields with specific values use the `default` keyword Argument. `default` accepts a `ZonedDateTime`. By default `default` is set to `Jan 1, year(today()) 00:00:00 UTC`.

```julia
julia> parse(ZonedDateTime, "Oct 13, 1994")
1994-10-13T00:00:00+00:00

julia> parse(ZonedDateTime, "17:10")
2015-01-01T17:10:00+00:00

julia> default = ZonedDateTime(DateTime(1994, 10, 13, 17, 10), TimeZone("America/Winnipeg"))
1994-10-13T17:10:00-05:00

julia> parse(ZonedDateTime, "April 22, 1993", default=default)
1993-04-22T17:10:00-05:00

julia> parse(ZonedDateTime, "13:20", default=default)
1994-10-13T13:20:00-05:00
```

For ambiguous dates like `04/02/12` you can use the `dayfirst` or `yearfirst` keyword Arguments to determine what the date should be. By default they are both set to `false`.

```julia
julia> parse(Date, "04/02/03")
2003-04-02

julia> parse(Date, "04/02/03", dayfirst=true)
2003-02-04

julia> parse(Date, "04/02/03", yearfirst=true)
2004-02-03
```

As shown above, 2 digit years will get converted to a 4 digit year near year 2000. 00 to 49 becomes 2000 to 2049 and 50 to 99 becomes 1950 to 1999.


If your date has a time zone name in it then you can use the `timezone_infos` keyword Argument to specify what the time zone is. `timezone_infos` accepts a `Dict{AbstractString, TimeZone}`. If the time zone is not specified it will try to get it from `TimeZones.TimeZone("time_zone_name")`.

```julia
julia> parse(ZonedDateTime, "1994/10/13 13:00 America/Winnipeg")
1994-10-13T13:00:00-05:00

julia> timezone_infos = Dict{AbstractString, TimeZone}("CST" => FixedTimeZone("CST", -18000))
Dict{AbstractString,Base.Dates.TimeZone} with 1 entry:
  "CST" => TimeZones.FixedTimeZone(:CST,TimeZones.Offset(-18000 seconds,0 secon…

julia> parse(ZonedDateTime, "1994/10/13 13:00 CST", timezone_infos=timezone_infos)
1994-10-13T13:00:00-05:00
```
