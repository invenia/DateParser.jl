import DateParser: Tokens, match

@test Tokens("⁇.éAû2").tokens == ["⁇.", "éAû", "2"]
@test Tokens("GMT+3").tokens == ["GMT", "+", "3"]  # Note: ispunct('+') is false
@test Tokens("1999 Feb 3 12:20:30.5").tokens == ["1999", "", "Feb", "", "3", "", "12", ":", "20", ":", "30", ".", "5"]

t = Tokens("1999 Feb 3 12:20:30.5")
@test match(t, :digit, :alpha, :digit) != nothing                   # "1999", "Feb", "3"
@test match(t, "1999", "Feb", "3") != nothing                       # "1999", "Feb", "3"
@test match(t, :alpha, :digit, :digit, offset=2) != nothing         # "Feb", "3" "12"
@test match(t, :digit, :space, :alpha, whitespace=true) != nothing  # "1999", "", "Feb"
@test match(t, :digit, ".", :digit, offset=8) != nothing            # "30", ".", "5"

@test match(t, :digit, ["February"; "Feb"], :digit)
