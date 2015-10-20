import DateParser: Tokens, TokenComparate, match

TC = TokenComparate

@test Tokens("⁇.éAû2").tokens == ["⁇.", "éAû", "2"]
@test Tokens("GMT+3").tokens == ["GMT", "+", "3"]  # Note: ispunct('+') is false
@test Tokens("1999 Feb 3 12:20:30.5").tokens == ["1999", "", "Feb", "", "3", "", "12", ":", "20", ":", "30", ".", "5"]

t = Tokens("1999 Feb 3 12:20:30.5")
@test match(t, TC[isdigit, isalpha, isdigit])  # "1999", "Feb", "3"
@test match(t, TC["1999", "Feb", "3"])         # "1999", "Feb", "3"
@test match(t, TC[isalpha, isdigit, isdigit], 2)  # "Feb", "3" "12"
@test match(t, TC[isdigit, isspace, isalpha], whitespace=true)  # "1999", "", "Feb"
@test match(t, TC[isdigit, ".", isdigit], 8)  # "30", ".", "5"

@test match(t, TC[isdigit, ["February"; "Feb"], isdigit])
