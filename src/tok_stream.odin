package hl

TokenStream :: struct {
    tokens: [dynamic]Token,
    read_idx: int,
}

HL_Stream_Error :: enum {
    None, Parse_Failed,
}


tok_stream_move_back :: proc(p_tstream: ^TokenStream, count: int) {
    assert((p_tstream.read_idx - count) >= -1, "Moving back too much, the target idx is before the beginning of the stream is not allowed")
    p_tstream.read_idx -= count
}

tok_stream_next :: proc(p_tstream: ^TokenStream) -> ^Token {
    if (p_tstream.read_idx + 1) >= len(p_tstream.tokens) {
        return nil
    }

    p_tstream.read_idx += 1

    return &p_tstream.tokens[p_tstream.read_idx]
}

tok_stream_peek_expect :: proc(p_tstream: ^TokenStream, type: Token_Type) -> (p_tok: ^Token, success: bool) {
    p_tok = tok_stream_peek(p_tstream)
    success = p_tok != nil && p_tok.type == type
    return
}

tok_stream_peek :: proc(p_tstream: ^TokenStream) -> ^Token {
    if (p_tstream.read_idx + 1) >= len(p_tstream.tokens) {
        return nil
    }

    return &p_tstream.tokens[p_tstream.read_idx + 1]
}

buf_stream_parse_as_tok_stream :: proc(p_bstream: ^BufStream) -> (TokenStream, HL_Stream_Error) {
    r, s := buf_stream_next_char_skipped(p_bstream)

    tokens: [dynamic]Token

    line: int = 1

    // LEXICATION
    for s {
        rune_idx := buf_stream_get_read_idx(p_bstream)

        switch r {
        case '+': append(&tokens, token_mk_single(rune_idx, .add))
        case '-': append(&tokens, token_mk_single(rune_idx, .sub))
        case '*': append(&tokens, token_mk_single(rune_idx, .mul))
        case '/': append(&tokens, token_mk_single(rune_idx, .div))
        case '(': append(&tokens, token_mk_single(rune_idx, .lparen))
        case ')': append(&tokens, token_mk_single(rune_idx, .rparen))
        case '{': append(&tokens, token_mk_single(rune_idx, .lbrack))
        case '}': append(&tokens, token_mk_single(rune_idx, .rbrack))
        case '=': append(&tokens, token_mk_single(rune_idx, .eq))
        case '#': append(&tokens, token_mk_single(rune_idx, .hashtag))
        case ',': append(&tokens, token_mk_single(rune_idx, .comma))

        case '\n':
            append(&tokens, token_mk_single(rune_idx, .newline))
            line += 1

        case '`':
            buf_stream_move_back(p_bstream)
            tok, ss := buf_stream_try_parse_string(p_bstream)

            if ss == false {
                return TokenStream{}, .Parse_Failed
            }
            // else

            append(&tokens, tok)

        case:
            if rune_is_digit(r) {
                buf_stream_move_back(p_bstream)
                append(&tokens, buf_stream_parse_int(p_bstream))

            } else if rune_is_alpha(r) {
                buf_stream_move_back(p_bstream)
                append(&tokens, buf_stream_parse_symbol(p_bstream))

            } else {
                append(&tokens, token_mk_single(rune_idx, .unknown))
            }
        }

        r, s = buf_stream_next_char_skipped(p_bstream)
    }

    return TokenStream{tokens = tokens, read_idx = -1}, .None
}

tok_stream_destroy :: proc(tstream: TokenStream) {
    delete(tstream.tokens)
}

