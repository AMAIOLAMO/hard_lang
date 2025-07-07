package hl

next_int_from_stream :: proc(p_bstream: ^BufStream, p_tstream: ^TokenStream) -> int {
    tok_value := tok_stream_next(p_tstream)
    return str_to_int(buf_stream_string_from_tok(p_bstream, tok_value^))
}

next_str_from_stream :: proc(p_bstream: ^BufStream, p_tstream: ^TokenStream) -> string {
    tok_value := tok_stream_next(p_tstream)
    return buf_stream_string_from_tok(p_bstream, tok_value^)
}

