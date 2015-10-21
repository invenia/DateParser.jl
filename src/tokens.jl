import Base: getindex, length, eltype, match, ismatch

type Tokens{S<:AbstractString}
    string::S
    tokens::Array{S}
    offsets::Array{Int}
    types::Array{Symbol}
end

function Tokens{S<:AbstractString}(input::S)
    tokens = S[]
    offsets = Int[]
    types = Symbol[]

    token_chars = sizehint!(Char[], 10)

    # Note: A regular expression can handle almost all of this task
    # with the exception of identifying Unicode punctuation.
    state = last_state = :none
    start = chr2ind(input, 1)
    for (i, c) in enumerate(input)
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
            if state != last_state && !isempty(token_chars)
                token = last_state == :space ? "" : S(token_chars)
                push!(tokens, token)
                push!(offsets, start)
                push!(types, last_state)

                empty!(token_chars)
                start = chr2ind(input, i)
            end

            push!(token_chars, c)
        end

        last_state = state
    end

    # Token will only be empty here if the entire input was whitespace
    if !isempty(token_chars)
        token = last_state == :space ? "" : S(token_chars)
        push!(tokens, token)
        push!(offsets, start)
        push!(types, last_state)
    end

    return Tokens(input, tokens, offsets, types)
end

getindex(tokens::Tokens, index) = tokens.tokens[index]
length(tokens::Tokens) = length(tokens.tokens)
eltype(tokens::Tokens) = eltype(tokens.tokens)

# function match(regex::Regex, tokens::Tokens, offset::Integer=1)
#     match(regex, tokens.string, tokens.offsets[offset])
# end

# function ismatch(regex::Regex, tokens::Tokens, offset::Integer=1)
#     ismatch(regex, tokens.string, tokens.offsets[offset])
# end

function match(regex::Regex, tokens::Tokens, idx::Integer=1)
    m = match(regex, tokens.string, tokens.offsets[idx])
    if m != nothing
        for i in eachindex(m.captures)
            m[i] != tokens[idx + i - 1] && return nothing
        end
    end
    return m
end

function match(tokens::Tokens, checks::Any...; offset::Integer=1, case_insensitive::Bool=false, whitespace::Bool=false)
    matched = sizehint!(eltype(tokens)[], length(checks))
    num_tokens = length(tokens)
    space_offset = 0

    # Determine the number of whitespace elements to skip
    if !whitespace && offset > 1
        for i in 1:num_tokens
            if tokens.types[i] == :space
                space_offset += 1
            end

            offset == i - space_offset && break
        end
    end

    for i in 1:length(checks)
        j = offset + space_offset + i - 1

        # Does not need to be a loop as all sequential whitespace is combined
        if !whitespace && j <= num_tokens && tokens.types[j] == :space
            space_offset += 1
            j += 1
        end

        # Comparisons extend beyond the last token and can never be matched.
        j <= num_tokens || break

        check = checks[i]
        token = case_insensitive ? lowercase(tokens[j]) : tokens[j]

        if isa(check, Symbol)
            equal = check == tokens.types[j]
        elseif isa(check, AbstractString)
            if case_insensitive
                check = lowercase(check)
            end
            equal = check == token
        elseif eltype(check) <: AbstractString
            if case_insensitive
                check = map(lowercase, check)
            end
            equal = any(s -> s == token, check)
        else
            error("Unhandled type in check: \"$(typeof(check))\"")
        end

        !equal && break
        push!(matched, tokens[j])
    end

    if length(matched) == length(checks)
        return matched
    else
        return nothing
    end
end
