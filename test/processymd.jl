import DateParser: processymd, YEAR, MONTH, DAY, ALL
import Combinatorics: permutations
Y, M, D, A = YEAR, MONTH, DAY, ALL

@test_throws Exception processymd([1,2,3,4], [A,A,A,A])
@test_throws Exception processymd([1,2,3], [A,A])

# Nothing is ambigious here so modifiers don't change anything
answer = (99,12,31)
for ymd in permutations([99,12,31])
    @test processymd(ymd, [A,A,A]) == answer
end

# Since order matters and month can only be 3 we can expect certain formats
# be used based upon the position of the month.
for ymd in permutations([21,22,3])
    mask = ymd .> 12
    if mask == [false, true, true]
        @test processymd(ymd, [A,A,A]) == (ymd[3], ymd[1], ymd[2])  # M/D/Y
    elseif mask == [true, false, true]
        @test processymd(ymd, [A,A,A]) == (ymd[3], ymd[2], ymd[1])  # D/M/Y
    elseif mask == [true, true, false]
        @test processymd(ymd, [A,A,A]) == (ymd[1], ymd[3], ymd[2])  # Y/D/M
    end
end

# Month or day is not provided
for ymd in permutations([41,42,3])
    @test processymd(ymd, [A,A,A]) == nothing
end

# Values provided are ambigious and only the type mask will adjust the output
for ymd in permutations([1,2,3])
    @test processymd(ymd, [A,A,A]) == (ymd[3], ymd[1], ymd[2])  # M/D/Y

    @test processymd(ymd, [Y,A,A]) == (ymd[1], ymd[2], ymd[3])  # Y/M/D
    @test processymd(ymd, [A,Y,A]) == (ymd[2], ymd[1], ymd[3])  # M/Y/D
    @test processymd(ymd, [A,A,Y]) == (ymd[3], ymd[1], ymd[2])  # M/D/Y

    @test processymd(ymd, [M,A,A]) == (ymd[3], ymd[1], ymd[2])  # M/D/Y
    @test processymd(ymd, [A,M,A]) == (ymd[3], ymd[2], ymd[1])  # D/M/Y
    @test processymd(ymd, [A,A,M]) == (ymd[1], ymd[3], ymd[2])  # Y/D/M

    @test processymd(ymd, [D,A,A]) == (ymd[3], ymd[2], ymd[1])  # D/M/Y
    @test processymd(ymd, [A,D,A]) == (ymd[3], ymd[1], ymd[2])  # M/D/Y
    @test processymd(ymd, [A,A,D]) == (ymd[1], ymd[2], ymd[3])  # Y/M/D

    # With enough information the last field can be determined easily
    @test processymd(ymd, [Y,M,A]) == (ymd[1], ymd[2], ymd[3])  # Y/M/D
    @test processymd(ymd, [Y,A,M]) == (ymd[1], ymd[3], ymd[2])  # Y/D/M
    @test processymd(ymd, [A,M,Y]) == (ymd[3], ymd[2], ymd[1])  # D/M/Y
    @test processymd(ymd, [A,Y,M]) == (ymd[2], ymd[3], ymd[1])  # D/Y/M
    @test processymd(ymd, [M,A,Y]) == (ymd[3], ymd[1], ymd[2])  # M/D/Y
    @test processymd(ymd, [M,Y,A]) == (ymd[2], ymd[1], ymd[3])  # M/Y/D
end


for ymd in permutations([1,2])
    @test processymd(ymd, [A,A]) == (nothing, ymd[1], ymd[2])  # M/D

    @test processymd(ymd, [Y,A]) == (ymd[1], ymd[2], nothing)  # Y/M
    @test processymd(ymd, [A,Y]) == (ymd[2], ymd[1], nothing)  # M/Y

    @test processymd(ymd, [M,A]) == (nothing, ymd[1], ymd[2])  # M/D
    @test processymd(ymd, [A,M]) == (nothing, ymd[2], ymd[1])  # D/M

    @test processymd(ymd, [D,A]) == (nothing, ymd[2], ymd[1])  # D/M
    @test processymd(ymd, [A,D]) == (nothing, ymd[1], ymd[2])  # M/D

    @test processymd(ymd, [Y,M]) == (ymd[1], ymd[2], nothing)  # Y/M
    @test processymd(ymd, [M,Y]) == (ymd[2], ymd[1], nothing)  # M/Y
    @test processymd(ymd, [Y,D]) == (ymd[1], nothing, ymd[2])  # Y/D
    @test processymd(ymd, [D,Y]) == (ymd[2], nothing, ymd[1])  # D/Y
    @test processymd(ymd, [M,D]) == (nothing, ymd[1], ymd[2])  # M/D
    @test processymd(ymd, [D,M]) == (nothing, ymd[2], ymd[1])  # D/M
end

let ymd = [1]
    @test processymd(ymd, [A]) == (nothing, nothing, ymd[1])  # D

    @test processymd(ymd, [Y]) == (ymd[1], nothing, nothing)  # Y
    @test processymd(ymd, [M]) == (nothing, ymd[1], nothing)  # M
    @test processymd(ymd, [D]) == (nothing, nothing, ymd[1])  # D
end
