package hl

import "core:os"

BufStream :: struct {
    buf: string,
    read_idx: int,
}

INVALID_TOKEN :: Token{ -1, -1, Token_Type.none }
INVALID_BUF_STREAM :: BufStream{ "", -1 }

DIGIT_STRINGS :: "0123456789"

rune_is_digit :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

rune_is_alpha :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
}

Buf_Stream_Read_Error :: enum {
    None, Open_File, Read_File,
}

buf_stream_read_from_file :: proc(path: string) -> (BufStream, Buf_Stream_Read_Error) {
    file, err := os.open(path) 
    defer os.close(file)

    if err != nil {
        return INVALID_BUF_STREAM, .Open_File
    }
    buf, success := os.read_entire_file_from_handle(file)
    if success == false {
        return INVALID_BUF_STREAM, .Read_File
    }

    return BufStream{string(buf), -1}, .None
}

buf_stream_destroy :: proc(bstream: BufStream) {
    delete(bstream.buf)
}

/// returns a string slice given based on the token's generated associated in the token stream
buf_stream_string_from_tok :: proc(p_stream: ^BufStream, token: Token) -> string {
    assert(token.from < len(p_stream.buf), "token.from is an invalid index")
    assert(token.to < len(p_stream.buf), "token.to is an invalid index")
    
    return p_stream.buf[token.from : token.to + 1]
}

/// Returns the currently read index, returns -1 if the stream is at the beginning
buf_stream_get_read_idx :: proc(p_stream: ^BufStream) -> int {
    return p_stream.read_idx
}

buf_stream_move_back :: proc(p_stream: ^BufStream) {
    assert(p_stream.read_idx >= 0, "Cannot move back before the beginning of the stream")
    p_stream.read_idx -= 1
}

buf_stream_next_char :: proc(p_stream: ^BufStream) -> (rune, bool) {
    p_stream.read_idx += 1

    if p_stream.read_idx >= len(p_stream.buf) {
        return '0', false
    }
    // else

    return rune(p_stream.buf[p_stream.read_idx]), true
}

buf_stream_next_char_skipped :: proc(p_stream: ^BufStream) -> (rune, bool) {
    r, s := buf_stream_next_char(p_stream)
    
    for r == ' ' && s != false {
        r, s = buf_stream_next_char(p_stream)
    }

    return r, s
}

buf_stream_parse_int :: proc(p_stream: ^BufStream) -> Token {
    r, s := buf_stream_next_char(p_stream)
    assert(s, "Expects the next rune to parse be integer, but got EOF instead")
    assert(rune_is_digit(r), "Expects the next rune to parse to be integer, but got something else instead")

    start_idx := buf_stream_get_read_idx(p_stream)

    
    r, s = buf_stream_next_char(p_stream)
    for rune_is_digit(r) {
        r, s = buf_stream_next_char(p_stream)
    }

    // at this point, we already consumed more than enough
    buf_stream_move_back(p_stream)

    end_idx := buf_stream_get_read_idx(p_stream)

    return Token{ start_idx, end_idx, Token_Type.lit_int }
}

buf_stream_parse_symbol :: proc(p_stream: ^BufStream) -> Token {
    r, s := buf_stream_next_char(p_stream)
    assert(s, "Expects the next rune to parse be alphabetic, but got EOF instead")
    // checks if the first one is an alphabet
    assert(rune_is_alpha(r), "Expects the next rune to be alphabetic, but got something else instead")

    start_idx := buf_stream_get_read_idx(p_stream)

    // checks the remaining is a valid symbol:
    // alpha alpha*|digit*|underscore*

    r, s = buf_stream_next_char(p_stream)
    for (rune_is_alpha(r) || rune_is_digit(r) || r == '_') && s {
        r, s = buf_stream_next_char(p_stream)
    }

    // at this point, we already consumed more than enough
    buf_stream_move_back(p_stream)
    
    end_idx := buf_stream_get_read_idx(p_stream)

    return Token{ start_idx, end_idx, Token_Type.sym }
}

buf_stream_try_parse_string :: proc(p_stream: ^BufStream) -> (Token, bool) {
    r, s := buf_stream_next_char(p_stream)
    assert(s, "Expects the next rune to be a grave symbol representing a string, but got EOF instead")
    assert(r == '`', "Expects the next rune to be a grave symbol represeting a string, but got something else instead")

    start_idx := buf_stream_get_read_idx(p_stream)

    // search until EOF, \n or ` grave
    r, s = buf_stream_next_char(p_stream)
    for (r != '\n' && r != '`') && s {
        r, s = buf_stream_next_char(p_stream)
    }

    // only consume the ending grave, otherwise
    if r != '`' {
        buf_stream_move_back(p_stream)
        return INVALID_TOKEN, false
    }
    // else

    end_idx := buf_stream_get_read_idx(p_stream)

    return Token{ start_idx, end_idx, Token_Type.lit_str }, true
}


