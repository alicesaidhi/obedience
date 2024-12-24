local testkit = require("./testkit")
local lex = require("../src/lex")
local ast = require("../src/ast")

local TEST, CASE, CHECK, FINISH, SKIP = testkit.test()

TEST("lex identifier", function()

    do CASE "alphanumeric"
        local input = lex(buffer.fromstring("test256215"))
        CHECK(input.bump_peek().kind == "identifier")
        CHECK(input.peek().text == "test256215")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "kebab-case"
        local input = lex(buffer.fromstring("kebab-case"))
        CHECK(input.bump_peek().kind == "identifier")
        CHECK(input.peek().text == "kebab-case")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "snake_case"
        local input = lex(buffer.fromstring("snake_case"))
        CHECK(input.bump_peek().kind == "identifier")
        CHECK(input.peek().text == "snake_case")
        CHECK(input.bump_peek().kind == "eof")
    end

end)

TEST("lex number", function()

    do CASE "integer"
        local input = lex(buffer.fromstring("1234"))
        CHECK(input.bump_peek().kind == "number")
        CHECK(input.peek().text == "1234")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "float"
        local input = lex(buffer.fromstring("124.512"))
        CHECK(input.bump_peek().kind == "number")
        CHECK(input.peek().text == "124.512")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "_"
        local input = lex(buffer.fromstring("100_000"))
        CHECK(input.bump_peek().kind == "number")
        CHECK(input.peek().text == "100_000")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "binary"
        local input = lex(buffer.fromstring("0b1111"))
        CHECK(input.bump_peek().kind == "number")
        CHECK(input.peek().text == "0b1111")
        CHECK(input.bump_peek().kind == "eof")
    end

end)

TEST("lex keywords", function()

    do CASE "fn"
        local input = lex(buffer.fromstring("fn"))
        CHECK(input.bump_peek().kind == "fn")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "true"
        local input = lex(buffer.fromstring("true"))
        CHECK(input.bump_peek().kind == "true")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "false"
        local input = lex(buffer.fromstring("false"))
        CHECK(input.bump_peek().kind == "false")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "nil"
        local input = lex(buffer.fromstring("nil"))
        CHECK(input.bump_peek().kind == "nil")
        CHECK(input.bump_peek().kind == "eof")
    end

end)

TEST("lex symbols", function()

    do CASE "("
        local input = lex(buffer.fromstring("("))
        CHECK(input.bump_peek().kind == "(")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE ")"
        local input = lex(buffer.fromstring(")"))
        CHECK(input.bump_peek().kind == ")")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "["
        local input = lex(buffer.fromstring("["))
        CHECK(input.bump_peek().kind == "[")
        CHECK(input.bump_peek().kind == "eof")
    end
    
    do CASE "]"
        local input = lex(buffer.fromstring("]"))
        CHECK(input.bump_peek().kind == "]")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "{"
        local input = lex(buffer.fromstring("{"))
        CHECK(input.bump_peek().kind == "{")
        CHECK(input.bump_peek().kind == "eof")
    end
    
    do CASE "}"
        local input = lex(buffer.fromstring("}"))
        CHECK(input.bump_peek().kind == "}")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "="
        local input = lex(buffer.fromstring("="))
        CHECK(input.bump_peek().kind == "=")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE "."
        local input = lex(buffer.fromstring("."))
        CHECK(input.bump_peek().kind == ".")
        CHECK(input.bump_peek().kind == "eof")
    end

    do CASE ","
        local input = lex(buffer.fromstring(","))
        CHECK(input.bump_peek().kind == ",")
        CHECK(input.bump_peek().kind == "eof")
    end
    
    do CASE "\n"
        local input = lex(buffer.fromstring("\n"))
        CHECK(input.bump_peek().kind == "\n")
        CHECK(input.bump_peek().kind == "eof")
    end
end)

TEST("lex examples", function()

    do CASE "set-health 100 true { test = false }\\na"
        local input = lex(buffer.fromstring("set-health 100 true { test = false }\na"))
        CHECK(input.bump_peek().kind == "identifier")
        CHECK(input.peek().text == "set-health")
        CHECK(input.bump_peek().kind == "number")
        CHECK(input.peek().text == "100")
        CHECK(input.bump_peek().kind == "true")
        CHECK(input.bump_peek().kind == "{")
        CHECK(input.bump_peek().kind == "identifier")
        CHECK(input.peek().text == "test")
        CHECK(input.bump_peek().kind == "=")
        CHECK(input.bump_peek().kind == "false")
        CHECK(input.bump_peek().kind == "}")
        CHECK(input.bump_peek().kind == "\n")
        CHECK(input.bump_peek().kind == "identifier")
        CHECK(input.peek().text == "a")
        CHECK(input.bump_peek().kind == "eof")
    end

end)

TEST("ast", function()

    do CASE "ast test"
        local input = ast(buffer.fromstring("set-health 100 true { test = false }"))
        testkit.print(input)

        CHECK(#input.block.stats == 1)
        local first = input.block.stats[1]
        CHECK(first.kind == "call")
        CHECK(first.call.prefix.kind == "global")
        CHECK(first.call.prefix.token.kind == "identifier")
        CHECK(first.call.prefix.token.text == "set-health")
        CHECK(#first.call.suffixes == 1)
        CHECK(first.call.suffixes[1].kind == "call")
        CHECK(#first.call.suffixes[1].args == 3)
        CHECK(first.call.suffixes[1].args[1].kind == "number")
        CHECK(first.call.suffixes[1].args[1].token.kind == "number")
        CHECK(first.call.suffixes[1].args[1].token.text == "100")
        CHECK(first.call.suffixes[1].args[2].kind == "boolean")
        CHECK(first.call.suffixes[1].args[2].token.kind == "true")
        CHECK(first.call.suffixes[1].args[3].kind == "table")
        CHECK(#first.call.suffixes[1].args[3].table.fields == 1)
        CHECK(first.call.suffixes[1].args[3].table.fields[1].kind == "namekey")
        CHECK(first.call.suffixes[1].args[3].table.fields[1].name.kind == "identifier")
        CHECK(first.call.suffixes[1].args[3].table.fields[1].name.text == "test")
        CHECK(first.call.suffixes[1].args[3].table.fields[1].value.kind == "boolean")
        CHECK(first.call.suffixes[1].args[3].table.fields[1].value.token.kind == "false")
        
    end

    do CASE "ast function"
        local input = ast(buffer.fromstring("test = fn (hello test) (hi)"))
        testkit.print(input)

        CHECK(#input.block.stats == 1)
        local first = input.block.stats[1]
        CHECK(first.kind == "assign")
        CHECK(first.left.kind == "identifier")
        CHECK(first.left.text == "test")
        
        local right = first.right
        CHECK(right.kind == "function")
        assert(right.kind == "function")
        CHECK(#right.body.params == 2)
        
        
    end

end)

FINISH()