--!strict
export type TokenKindText =
    | "identifier"
    | "number"
    | "string"
    | "variable"
    | "error"

export type TokenKindRest =
    | "="
    | "["
    | "]"
    | "("
    | ")"
    | "."
    | ","
    | "\n"

    | "{"
    | "}"

    | "whitespace"
    | "comment"
    
    | "fn"
    | "true"
    | "false"
    | "nil"

    | "eof"

export type TokenText<T> = {
    kind: T,
    text: string,
    span: vector
}

export type TokenNoText<T> = {
    kind: T,
    span: vector
}

export type Token = {
    kind: TokenKindText,
    text: string,
    span: vector
} | {
    kind: TokenKindRest,
    span: vector
}

export type TokenSpecific<T> = {
    kind: T,
    text: string,
    span: vector
}

local function char(c: string): number
    return string.byte(c) :: number
end

--[=[
    Lexes the given input into tokens
]=]
local function lex(input: buffer)

	local pos = 0
    local line = 0
    local len = buffer.len(input)

    local function peek(): number
        if pos == len then return 0 end
		return buffer.readu8(input, pos) :: any
	end
        
    local function bump()
        pos = math.min((pos + 1) :: any, len)
    end

    local function bump_any()
        if peek() == char("\n") then
            line += 1
        end

        bump()
        return peek()
    end

    local function bump_peek()
        bump()
        return peek()
    end

    local function is_whitespace(c: number): boolean
		return c == char(" ") or c == char("\t") or c == char("\r")
	end

	local function is_digit(c: number): boolean
		return char("0") <= c and c <= char("9")
	end

	local function is_alpha(c: number): boolean
		return (char("a") <= c and c <= char("z")) or (char("A") <= c and c <= char("Z")) or c == char("_")
	end

    local function string_backslash()
		local c = peek()

		if c == char("\r") then
			c = bump_peek()

			if c == char("\n") then
				bump()
				line += 1
			end
		elseif c == char("z") then
			bump()

			while is_whitespace(peek()) do
				bump_any()
			end
		else
			bump_any()
		end
	end

    local function quoted_string(): "string" | "error"
		local delim = peek()
		local c = bump_peek()

		while c ~= delim do
			if c == 0 or c == char("\n") or c == char("\r") then
				return "error"
			elseif c == char("\\") then
				bump()
				string_backslash()
			else
				bump()
			end

			c = peek()
		end

		bump()
		return "string"
	end

    local function number(): "number" | "error"
		local start = pos
		local base = 10

		local c: number = peek()

		if c == char("0") then
			c = bump_peek()

			if c == char("x") or c == char("X") then
				c = bump_peek()
				base = 16
			elseif c == char("b") or c == char("B") then
				c = bump_peek()
				base = 2
			end
		end

		while is_digit(c) or c == char(".") or c == char("_") do
			c = bump_peek()
		end

		if c == char("e") or c == char("E") then
			c = bump_peek()

			if c == char("+") or c == char("-") then
				c = bump_peek()
			end
		end

		while is_digit(c) or is_alpha(c :: any) or c == char("_") do
			c = bump_peek()
		end

		local text: string
		if base == 10 then
			text = buffer.readstring(input, start, pos - start) :: string
		else
			text = buffer.readstring(input, start + 2, pos - start - 2) :: string
		end

        text = string.gsub(text, "_", "")

		if tonumber(text, base) then
			return "number"
		else
			return "error"
		end
	end

    local function read_kind(): TokenKindRest | TokenKindText
        local c: number = peek()
        
        if c == 0 then
            return "eof"
        end

        if c == char("#") then
            while c ~= char("\n") do
                bump_any()
            end
            return "comment"
        elseif is_whitespace(c) then
            bump()
            return "whitespace"
        elseif is_alpha(c) then
            local start = pos

            repeat
                c = bump_peek()
            until not (is_alpha(c :: number) or is_digit(c :: number) or c == char("-"))

            local value = buffer.readstring(input, start, pos - start)

            if value == "fn" then
                return "fn"
            elseif value == "true" then
                return "true"
            elseif value == "false" then
                return "false"
            elseif value == "nil" then
                return "nil"
            end
            
            return "identifier"
        elseif is_digit(c :: number) then
            return number()
        elseif c == char("$") then
            local start = pos

            repeat
                c = bump_peek()
            until not (c and is_alpha(c) or c and is_digit(c))

            local value = buffer.readstring(input, start, pos - start)

            if value == "fn" then
                return "error"
            elseif value == "true" then
                return "error"
            elseif value == "false" then
                return "error"
            elseif value == "nil" then
                return "error"
            end

            return "variable"
        elseif c == char("\"") then
            return quoted_string()
        elseif c == char(".") then
            c = peek()

			if is_digit(c) then
				pos -= 1
				return number()
			else
                bump()
				return "."
			end
        elseif c == char("=") then
            bump()
            return "="
        elseif c == char("[") then
            bump()
            return "["
        elseif c == char("]") then
            bump()
            return "]"
        elseif c == char("{") then
            bump()
            return "{"
        elseif c == char("}") then
            bump()
            return "}"
        elseif c == char("(") then
            bump()
            return "("
        elseif c == char(")") then
            bump()
            return ")"
        elseif c == char(",") then
            bump()
            return ","
        elseif c == char("\n") then
            bump_any()
            return "\n"
        end

        return "error"
    end

    local function next_token(): Token
        local start = pos
        local kind = read_kind()
        
        while kind == "whitespace" or kind == "comment" do
            start = pos
            kind = read_kind()
        end

        if
            kind == "error"
            or kind == "identifier"
            or kind == "number"
            or kind == "variable"
            or kind == "string"
        then
            return {
                kind = kind,
                text = buffer.readstring(input, start, pos - start),
                span = vector.create(start, pos, 0),
            }
        else
            return {
                kind = kind,
                span = vector.create(start, pos, 0),
            }
        end
    end

    local token: Token?
    local function peek_token(): Token
        token = if not token then next_token() else token
        return token
    end

    local function bump_peek_token()
        token = next_token()
        return token
    end

    return {
        peek = peek_token,
        bump_peek = bump_peek_token
    }
end

return lex