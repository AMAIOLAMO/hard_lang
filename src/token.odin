package hl

Token_Type :: enum {
    hashtag, eq, grave,
    lparen, rparen, lbrack, rbrack, // symbols (): [paren]thesis, {}: [brack]ets
    add, sub, mul, div, // operations
    lit_int, lit_str, // literals
    sym, newline, unknown, none,
}

// Lexical Analysis:
// expression: command [arguments] [("or" | "and") action]
// var_name "=" expression
// EXAMPLE: 
// value_here = 15 + (2 + 1 * 3)
// println `This is some cool commands here {value_here}`
// os_run `steam` or println `Failed to run steam!`
// os_run `grep -e "I love hard lang!"` and println `found something!`
//
// if value_here == 20 then
//   println `Good job!`
// else
//   println `ahh kinda not exactly 20, but that's okay!`
// end

Token :: struct {
    from, to: int,
    type: Token_Type,
}

token_mk_single :: proc(rune_idx: int, type: Token_Type) -> Token {
    return {
        rune_idx, rune_idx, type,
    }
}

