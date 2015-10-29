# DateParser

[![Build Status](https://travis-ci.org/invenia/DateParser.jl.svg?branch=master)](https://travis-ci.org/invenia/DateParser.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/xbyk0v7m9p369ier/branch/master?svg=true)](https://ci.appveyor.com/project/Michael-Klassen/dateparser-jl/branch/master)
[![Coverage Status](https://coveralls.io/repos/invenia/DateParser.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/invenia/DateParser.jl?branch=master)
[![codecov.io](http://codecov.io/github/invenia/DateParser.jl/coverage.svg?branch=master)](http://codecov.io/github/invenia/DateParser.jl?branch=master)


Automatic parsing of date strings

## Usage

`DateParser` extends the functions `parse` and `tryparse` by adding support for the types:  `Date`, `DateTime`, and `ZonedDateTime`.

```julia
julia> using DateParser

julia> parse(DateTime, "Oct 13, 1994 17:10")
1994-10-13T17:10:00

julia> using TimeZones

julia> parse(ZonedDateTime, "Oct 13, 1994 17:10 -05:00")
1994-10-13T17:10:00-05:00
```

Use the `fuzzy` keyword argument for fuzzy parsing. When `fuzzy` is true any unknown tokens in the string will be ignored. By default `fuzzy` is set to false.

```julia
julia> tryparse(DateTime, "It is Oct 13, 1994 at around 17:10")
Nullable{DateTime}()

julia> tryparse(DateTime, "It is Oct 13, 1994 at around 17:10", fuzzy=true)
Nullable(1994-10-13T17:10:00)
```

If you want to fill in omitted fields with specific values use the `default` keyword argument. When `default` is unused it will be set to the the first instant of the current year.

```julia
julia> Dates.today()
2015-10-16

julia> parse(DateTime, "13:20")
2015-01-01T13:20:00

julia> parse(DateTime, "13:20", default=convert(DateTime, Dates.today()))
2015-10-29T13:20:00

julia> parse(ZonedDateTime, "Oct 13, 1994")
1994-10-13T00:00:00+00:00

julia> default = ZonedDateTime(DateTime(1994, 10, 5, 17, 10), TimeZone("Europe/Warsaw"))
1994-10-05T17:10:00+01:00

julia> parse(ZonedDateTime, "Oct 13, 1994", default=default)
1994-10-13T17:10:00+01:00
```

For ambiguous dates like `04/02/03` you can use the `dayfirst` or `yearfirst` keyword arguments to determine what the date should be. By default they are both set to `false`.

```julia
julia> parse(Date, "04/02/03")
2003-04-02

julia> parse(Date, "04/02/03", yearfirst=true)
2004-02-03

julia> parse(Date, "04/02/03", dayfirst=true)
2003-02-04
```

As shown above, 2 digit years will get converted to a 4 digit year near year 2000. 00 to 49 becomes 2000 to 2049 and 50 to 99 becomes 1950 to 1999.

When the string includes a recognized time zone it will automatically be parsed. If the time zone information is ambiguous when using a time zone abbreviation you can use `tzmap` to disambiguate the time zone information.

```julia
julia> parse(ZonedDateTime, "1994/11/13 13:00 America/Winnipeg")
1994-11-13T13:00:00-06:00

julia> parse(ZonedDateTime, "1994/11/13 13:00 CST")
ERROR: Failed to parse date

julia> map = Dict{AbstractString,TimeZone}("CST" => TimeZone("America/Winnipeg"))
Dict{AbstractString,Base.Dates.TimeZone} with 1 entry:
  "CST" => America/Winnipeg

julia> zdt = parse(ZonedDateTime, "1994/11/13 13:00 CST", tzmap=map)
1994-11-13T13:00:00-06:00

julia> Dates.format(zdt, "yyyy/mm/dd HH:MM ZZZ")
"1994/11/13 13:00 CST"
```
