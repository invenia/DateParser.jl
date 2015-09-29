# DateTimeParser

[![Build Status](https://travis-ci.org/invenia/DateTimeParser.jl.svg?branch=master)](https://travis-ci.org/invenia/DateTimeParser.jl)

Automatic parsing of DateTime strings

## Usage

To use simply pass a string to `parsedate`, `parsedate` returns a `ZonedDateTime`.

```julia
julia> using DateTimeParser

julia> parsedate("Oct 13, 1994 17:10:02.455 -05:00")
1994-10-13T17:10:02.455-05:00
```

For `fuzzy` parsing pass `true` as the second parameter, unknown tokens in the string will be ignored. By default `fuzzy = false`.

```julia
julia> parsedate("It is Oct 13, 1994 at sometime around 17:10:02.455 with a tzoffset of -05:00", true)
1994-10-13T17:10:02.455-05:00
```

If you omit the date, time or timezone they will be filled with a default date of `today`, time of `00:00:00` and timezone of your `localzone`. You can change the default by passing your own `default = ZonedDateTime`.

```julia
julia> using TimeZones

julia> default = ZonedDateTime(DateTime(2012, 05, 04, 13, 59), TimeZone("UTC"))
2012-05-04T13:59:00+00:00

julia> parsedate("12:30", default=default)
2012-05-04T12:30:00+00:00

julia> parsedate("2014/12/04", default=default)
2014-12-04T13:59:00+00:00
```

For ambiguous dates like `04/02/12` you can use the flags `dayfirst` or `yearfirst` to determine what the date should be. By default they are both set to `false`.

```julia
julia> parsedate("4/2/12 13:01:02 Z")
2012-04-02T13:01:02+00:00

julia> parsedate("4/2/12 13:01:02 Z", dayfirst=true)
2012-02-04T13:01:02+00:00

julia> parsedate("4/2/12 13:01:02 Z", yearfirst=true)
2004-02-12T13:01:02+00:00
```

As shown above, 2 digit years will get converted to a 4 digit year near year 2000. 00 to 49 becomes 2000 to 2049 and 50 to 99 becomes 1950 to 1999.
