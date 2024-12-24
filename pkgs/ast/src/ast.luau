--!strict



local lex = require("./lex")

export type Span = vector

export type Separated<Node> = { Node }

export type Expression_Nil = {
    read kind: "nil",
    read token: lex.TokenNoText<"nil">
}

export type Expression_Boolean = {
    read kind: "boolean",
    read token: lex.TokenNoText<"true">
} | {
    read kind: "boolean",
    read token: lex.TokenNoText<"false">
}

export type Expression_Number = {
    read kind: "number",
    read token: lex.TokenText<"number">
}

export type Expression_String = {
    read kind: "string",
    read token: lex.TokenText<"string">
}

export type Expression_Table = {
    read kind: "table",
    read table: Table
}

export type Expression_Function = {
    read kind: "function",
    read body: FunctionBody
}

export type Expression_Var = {
	read kind: "var",

	read var: Var,
}

export type Expression =
	| Expression_Nil
	| Expression_Boolean
	| Expression_Number
	| Expression_String
	| Expression_Table
	| Expression_Function
	| Expression_Var

export type FunctionArg_String = {
    read kind: "string",
    read token: lex.TokenText<"string">
} | {
    read kind: "string",
    read token: lex.TokenText<"identifier">
}

export type FunctionArg_Number = {
    read kind: "number",
    read token: lex.TokenText<"number">
}

export type FunctionArg_Boolean = {
    read kind: "boolean",
    read token: lex.TokenNoText<"true">
} | {
    read kind: "boolean",
    read token: lex.TokenNoText<"false">
}

export type FunctionArg_Table = {
    read kind: "table",
    read table: Table
}

export type FunctionArg_Expr = {
    read kind: "expression",
    read expr: Expression,
}

export type FunctionArg =
    | FunctionArg_String
    | FunctionArg_Number
    | FunctionArg_Boolean
    | FunctionArg_Table
    | FunctionArg_Expr

export type VarRoot_Global = {
    read kind: "global",

    read token: lex.TokenText<"identifier">
}

export type VarRoot_Name = {
	read kind: "name",

	read token: lex.TokenText<"variable">,
}

export type VarRoot_Paren = {
	read kind: "paren",

	read expr: Expression,
}

export type VarRoot = 
    | VarRoot_Global
    | VarRoot_Name
    | VarRoot_Paren

export type VarSuffix_NameIndex = {
	read kind: "nameindex",
	read name: lex.TokenText<"identifier">,
}

export type VarSuffix_ExprIndex = {
	read kind: "exprindex",

	read expr: Expression,
}

export type VarSuffix_Call = {
    read kind: "call",

    read args: { FunctionArg }
}

export type VarSuffix =
	| VarSuffix_NameIndex
	| VarSuffix_ExprIndex
	| VarSuffix_Call

export type Var = {
    read prefix: VarRoot,
    read suffixes: { VarSuffix }
}

export type TableField_NameKey = {
    read kind: "namekey",
    read name: lex.TokenText<"identifier">,
    read value: Expression
}

export type TableField_ExprKey = {
    read kind: "exprkey",
    read key: Expression,
    read value: Expression
}

export type TableField_NoKey = {
    read kind: "nokey",
    read value: Expression
}

export type TableField = 
    | TableField_ExprKey
    | TableField_NameKey
    | TableField_NoKey  

export type Table = {
    read fields: { TableField }
}

export type FunctionParam = {
    read kind: "param",
    read token: lex.TokenText<"identifier">
}

export type FunctionBody = {
    read params: { FunctionParam },
    read block: Block
}

export type Stat_Assign = {
	read kind: "assign",

	read left: lex.TokenText<"identifier">,
	read right: Expression,
}

export type Stat_Call = {
    read kind: "call",

    read call: Var
}

export type Stat =
    | Stat_Assign
    | Stat_Call

export type Block = {
	read stats: { Stat },
}

export type Ast = {
	read block: Block,

	read eof: lex.TokenNoText<"eof">,
}

local function ast(input: buffer): Ast
    local stream = lex(input)
    local next_token = stream.bump_peek

    local current_token = next_token()
    local current_kind = current_token.kind
    local lookahead_token = next_token()
    local lookahead_kind = lookahead_token.kind

    local function consume()
        local old_token, old_kind = current_token, current_kind
        current_token, current_kind = lookahead_token, lookahead_kind
        lookahead_token = next_token()
        lookahead_kind = lookahead_token.kind
        return old_token, old_kind
    end

    local function display(token: lex.Token): string
        local kind = token.kind
    
        if 
            kind == "ident"
            or kind == "number"
            or kind == "string"
        then
            return kind
        elseif token.kind == "error" then
            return "'" .. token.text .. "'"
        else
            return "'" .. kind .. "'"
        end
    end

    local function report(message: string, span: vector?): never
        local report = {
            message = message,
            span = span or current_token.span,
        }
    
        error(report)
    end

    local function expect_failure(kind: lex.TokenKindText | lex.TokenKindRest): never
        return report(`expected {display({ kind = kind } :: any)}, but got {display(current_token)} instead`)
    end

    local function expect<T>(kind: T & lex.TokenKindRest): lex.TokenNoText<T>
        if current_kind == kind :: any then
            return consume() :: any
        else
            return expect_failure(kind)
        end
    end

    local function expectwtext<T>(kind: T & lex.TokenKindText): lex.TokenText<T>
        if current_kind == kind :: any then
            return consume() :: any
        else
            return expect_failure(kind)
        end
    end

    local function skip_nl()
        while current_kind == "\n" do consume() end
    end

    local parse_var
    local parse_var_root
    local parse_var_suffix
    local parse_var_suffixes
    local parse_expr
    local parse_function_arg
    local parse_table
    local parse_expr
    local parse_block

    function parse_var_root(): VarRoot
        if current_kind == "identifier" then
            return { kind = "global" :: "global", token = expectwtext("identifier") }
        elseif current_kind == "variable" then
            return { kind = "name" :: "name", token = expectwtext("variable") }
        elseif current_kind == "(" then
            expect("(")
            skip_nl()
            local expr: Expression = parse_expr()
            skip_nl()
            expect(")")
            return { kind = "paren" :: "paren", expr = expr }
        end

        return report(`expected identifier, variable or (, but got {display(current_token)} instead`)
    end

    function parse_var_suffix(): VarSuffix
        if current_kind == "." then
            expect(".")
            return { kind = "nameindex" :: "nameindex", name = expectwtext("identifier") }
        elseif current_kind == "[" then
            expect("[")
            local expression = parse_expr()
            expect("]")
            return { kind = "exprindex" :: "exprindex", expr = expression }
        else
            local function_args = {}
            while current_kind ~= "eof" and current_kind ~= "\n" and current_kind ~= "." and current_kind ~= "," and current_kind ~= "]" and current_kind ~= "}" and current_kind ~= ")" do
                table.insert(function_args, parse_function_arg())
            end
            return { kind = "call" :: "call", args = function_args }
        end
    end

    function parse_var_suffixes(): { VarSuffix }
        local suffixes = {}

        skip_nl()
        while current_kind ~= "eof" and current_kind ~= "." and current_kind ~= "," and current_kind ~= "]" and current_kind ~= "}" and current_kind ~= ")" and current_kind ~= "\n" do
           local suffix = parse_var_suffix()
           table.insert(suffixes, suffix)
           skip_nl()
        end

        return suffixes
    end

    function parse_var(): Var
        local root = parse_var_root()
        local suffixes = parse_var_suffixes()

        return {
            prefix = root,
            suffixes = suffixes
        }
    end

    function parse_function_arg(): FunctionArg
        if current_kind == "identifier" then
            return { kind = "string" :: "string", token = expectwtext("identifier") }
        elseif current_kind == "string" then
            return { kind = "string" :: "string", token = expectwtext("string") }
        elseif current_kind == "number" then
            return { kind = "number" :: "number", token = expectwtext("number") }
        elseif current_kind == "true" then
            return { kind = "boolean" :: "boolean", token = expect("true") }
        elseif current_kind == "false" then
            return { kind = "boolean" :: "boolean", token = expect("false") }
        elseif current_kind == "{" then
            return { kind = "table", table = parse_table() }
        elseif current_kind == "(" then
            expect("(")
            local expression = parse_expr()
            expect(")")
            return { kind = "expression", expr = expression }
        else
            return report(`expected identifier, string, table or number, but got {display(current_token)}`)
        end
    end

    function parse_table(): Table
        local fields: { TableField } = {}
        local first = true

        expect("{")
        skip_nl()
        
        while current_kind ~= "}" do
            skip_nl()
            if first then first = false else expect(",") end
            skip_nl()

            if current_kind == "identifier" and lookahead_kind == "=" then
                local key = expectwtext("identifier")
                expect("=")
                local expression = parse_expr()
                local field: TableField_NameKey = {
                    kind = "namekey",
                    name = key,
                    value = expression
                }

                table.insert(fields, field)
            elseif current_kind == "[" then
                expect("[")
                skip_nl()
                local key = parse_expr()
                skip_nl()
                expect("]")
                expect("=")
                local value = parse_expr()
                skip_nl()
                local field: TableField_ExprKey = {
                    kind = "exprkey",
                    key = key,
                    value = value
                }

                table.insert(fields, field)
            else
                -- regular index
                local field: TableField_NoKey = {
                    kind = "nokey",
                    value = parse_expr()
                }
                skip_nl()

                table.insert(fields, field)
            end
        end

        expect("}")

        return { fields = fields }
    end

    function parse_function(): FunctionBody
        skip_nl()
        expect("(")
        skip_nl()

        local params: { FunctionParam } = {}

        while current_kind ~= ")" do
            local token = expectwtext("identifier")
            local param: FunctionParam = { kind = "param", token = token }
            table.insert(params, param)
            skip_nl()
        end

        expect(")")
        
        skip_nl()

        expect("(")
        skip_nl()
        local block = parse_block()
        skip_nl()
        expect(")")
        
        return {
            params = params,
            block = block
        }
    end

    function parse_expr(): Expression
        if current_kind == "nil" then
            return { kind = "nil" :: "nil", token = expect("nil") }
        elseif current_kind == "true" then
            return { kind = "boolean" :: "boolean", token = expect("true") }
        elseif current_kind == "false" then
            return { kind = "boolean" :: "boolean", token = expect("false") }
        elseif current_kind == "number" then
            return { kind = "number" :: "number", token = expectwtext("number") }
        elseif current_kind == "string" then
            return { kind = "string" :: "string", token = expectwtext("string") }
        elseif current_kind == "identifier" then
            return { kind = "var", var = parse_var() }
        elseif current_kind == "variable" then
            return { kind = "var", var = parse_var() }
        elseif current_kind == "fn" then
            expect("fn")
            skip_nl()
            return {
                kind = "function",
                body = parse_function()
            }
        else
            return report(`expected expression, got {display(current_token)}`)
        end
    end

    function parse_block(): Block
        local statements: { Stat } = {}

        -- there are calls and variable assignments.
        skip_nl()
        while current_kind ~= "eof" and current_kind ~= ")" do
            if current_kind == "identifier" and lookahead_kind == "=" then
                local key = expectwtext("identifier")
                expect("=")
                skip_nl()
                local value = parse_expr()
                local statement: Stat_Assign = { kind = "assign", left = key, right = value }

                table.insert(statements, statement)
            else
                local statement: Stat_Call = { kind = "call", call = parse_var() }

                table.insert(statements, statement)
            end
            skip_nl()
        end

        return {
            stats = statements
        }
    end

    return {
        block = parse_block(),
        eof = expect("eof")
    }
end

return ast