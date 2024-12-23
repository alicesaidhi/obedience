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
    read function_token: lex.TokenNoText<"fn">,
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
    read name: lex.TokenText<"string">,
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
    read token: lex.TokenText<string>
}

export type FunctionBody = {
    read params: { FunctionParam },
    read block: Block
}

export type Stat_Assign = {
	read kind: "assign",

	read left: Var,
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

	read last_expressions: { Expression }?,
}

export type Ast = {
	read block: Block,

	read eof: lex.TokenNoText<"eof">,
}

local function ast(input: buffer): Ast
    local stream = lex(input)

    local bump_peek = stream.bump_peek
    local peek = stream.peek

    local function display(token: lex.Token): string
        local kind = token.kind
    
        if 
            kind == "ident"
            or kind == "number"
            or kind == "string"
        then
            return kind
        elseif kind == "attribute" or kind == "error" then
            return "'" .. (token :: any).text .. "'"
        else
            return "'" .. kind .. "'"
        end
    end

    local function report(message: string, span: vector?): never
        local report = {
            message = message,
            span = span or peek().span,
        }
    
        error(report)
    end

    local function expect_failure(kind: lex.TokenKindText | lex.TokenKindRest): never
        return report(`expected {display({ kind = kind } :: any)}, but got {display(peek())} instead`)
    end

    local function expect<T>(kind: T & lex.TokenKindRest): lex.TokenNoText<T>
        if peek().kind == kind :: any then
            local token = peek()
            return token :: any
        else
            return expect_failure(kind)
        end
    end

    local function expectwtext<T>(kind: T & lex.TokenKindText): lex.TokenText<T>
        if peek().kind == kind :: any then
            local token = peek()
            return token :: any
        else
            return expect_failure(kind)
        end
    end

    local parse_var
    local parse_var_root
    local parse_var_suffixex
    local parse_simple_expr
    local parse_function_arg
    local parse_table
    local parse_expr

    function parse_var_root(): VarRoot
        local current_kind = peek().kind

        if current_kind == "identifier" then
            return { kind = "global" :: "global", token = expectwtext("identifier") }
        elseif current_kind == "variable" then
            return { kind = "name" :: "name", token = expectwtext("variable") }
        elseif current_kind == "(" then
            expect("(")
            local expr: Expression = parse_expr()
            expect(")")
            return { kind = "paren" :: "paren", expr = expr }
        end

        return report(`expected identifier, variable or (, but got {display(peek())} instead`)
    end

    function parse_var_suffix(delimiter: lex.TokenKindRest): VarSuffix
        local current_kind = peek().kind

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
            while peek().kind ~= delimiter or peek().kind == "eof" do
                table.insert(function_args, parse_function_arg())
            end
            expect(")")
            return { kind = "call" :: "call", args = function_args }
        end
    end

    function parse_var_suffixes(delimiter: lex.TokenKindRest): { VarSuffix }
        local suffixes = {}

        while peek().kind ~= delimiter or peek().kind == "eof" do
           local suffix = parse_var_suffix(delimiter)
           table.insert(suffixes, suffix)
        end
        expect(delimiter)

        return suffixes
    end

    function parse_var(delimiter: lex.TokenKindRest): Var
        local root = parse_var_root()
        local suffixes = parse_var_suffixes(delimiter)

        return {
            prefix = root,
            suffixes = suffixes
        }
    end

    function parse_function_arg(): FunctionArg
        local current_kind = peek().kind

        if current_kind == "identifier" then
            return { kind = "string" :: "string", token = expectwtext("identifier") }
        elseif current_kind == "string" then
            return { kind = "string" :: "string", token = expectwtext("string") }
        elseif current_kind == "number" then
            return { kind = "number" :: "number", token = expectwtext("number") }
        elseif current_kind == "{" then
            return { kind = "table", table = parse_table() }
        elseif current_kind == "(" then
            expect("(")
            local expression = parse_expr()
            expect(")")
            return { kind = "expression", expr = expression }
        elseif #current_kind > 1 then
            return {
                kind = "string" :: "string",
                token = { kind = "string" :: "string", text = current_kind :: string, span = peek().span }
            }
        else
            return report(`expected identifier, string, table or number, but got {display(peek())}`)
        end
    end

    function parse_table_assignment()

    end

    function parse_table(): Table
        local fields = {}
        local first = true

        expect("{")
        
        while peek().kind ~= "}" or peek().kind ~= "eof" do
            if first then first = false else expect(",") end
            
            
        end

        expect("}")
    end

    function parse_simple_expr(): Expression
        local current_kind = peek().kind

        if current_kind == "nil" then
            return { kind = current_kind, token = expect("nil") }
        elseif current_kind == "true" then
            return { kind = "boolean" :: "boolean", token = expect("true") }
        elseif current_kind == "false" then
            return { kind = "boolean" :: "boolean", token = expect("false") }
        elseif current_kind == "number" then
            return { kind = "number" :: "number", token = expectwtext("number") }
        elseif current_kind == "string" then
            return { kind = "string" :: "string", token = expectwtext("string") }

        elseif current_kind == "identifier" then
            return { kind = "string" :: "string", token = expectwtext("string") }
        elseif current_kind == "variable" then
            return { kind = "var", var = parse_var() }
        end

    end

    function parse_expr(): Expression
        
    end

    return {
        block = {},
        eof = peek()
    }
end

return 