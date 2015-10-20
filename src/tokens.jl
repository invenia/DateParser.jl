import Base: getindex, length

typealias TokenComparate{S<:AbstractString} Union{Function,S,Array{S}}

type Tokens{S<:AbstractString}
    tokens::Array{S}
    lowercase::Array{S}
    types::Array{Symbol}
end

function Tokens{S<:AbstractString}(input::S)
    tokens = S[]
    token = sizehint!(Char[], 10)

    types = Symbol[]

    # Note: A regular expression can handle almost all of this task
    # with the exception of identifying Unicode punctuation.
    state = last_state = :none
    for c in input
        if isspace(c)
            state = :space
        elseif isdigit(c)
            state = :digit
        elseif isalpha(c)
            state = :word
        else
            state = :other
        end

        if state != :none
            if state != last_state && !isempty(token)
                token_str = last_state == :space ? "" : S(token)
                empty!(token)

                push!(tokens, token_str)
                push!(types, last_state)
            end

            push!(token, c)
        end

        last_state = state
    end

    # Token will only be empty here if the entire input was whitespace
    if !isempty(token)
        token_str = S(token)

        push!(tokens, token_str)
        push!(types, last_state)
    end

    return Tokens(tokens, map(lowercase, tokens), types)
end

getindex(tokens::Tokens, index) = tokens.tokens[index]
length(tokens::Tokens) = length(tokens.tokens)

function match(tokens::Tokens, checks::Array{TokenComparate}, idx::Integer=1; case_insensitive::Bool=false, whitespace::Bool=false)
    num_tokens = length(tokens)
    space_offset = 0

    # Determine the number of whitespace elements to skip
    if !whitespace && idx > 1
        for i in 1:num_tokens
            if tokens[i] == ""
                space_offset += 1
            end

            idx == i - space_offset && break
        end
    end

    for i in eachindex(checks)
        j = idx + space_offset + i - 1

        # Does not need to be a loop as all sequential whitespace is combined
        if !whitespace && j <= num_tokens && tokens[j] == ""
            space_offset += 1
            j += 1
        end

        # Comparisons extend beyond the last token and can never be matched.
        j <= num_tokens || return false

        check = checks[i]
        token = case_insensitive ? lowercase(tokens[j]) : tokens[j]

        if isa(check, Function)
            result = check(token)
            isa(result, Bool) || error("Check Functions needs to return a Bool")
            result == false && return false
        elseif isa(check, AbstractString)
            if case_insensitive
                check = lowercase(check)
            end
            check != token && return false
        elseif isa(check, Array) && eltype(check) <: AbstractString
            if case_insensitive
                check = map(lowercase, check)
            end
            any(s -> s == token, check) == false && return false
        else
            error("Unhandled type in check: \"$(typeof(check))\"")
        end
    end

    return true
end
