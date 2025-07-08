package hl

import "core:fmt"
import "core:os"
import "core:strings"

HL_VERSION_STR :: "v0.0.0"

// TODO: rewrite the code to utilize expectation of the next given the token, build from basic
// instead of doing the same thing over and over again

str_to_int :: proc(str: string) -> int {
    result: int = 0

    for rune in str {
        assert(rune_is_digit(rune), "the given string is not a valid int")
        result *= 10
        result += int(rune - '0')
    }

    return result
}

// AST short hand parsing
parse_var_declare :: proc(p_bstream: ^BufStream, p_tstream: ^TokenStream) -> ASTVarDeclareNode {
    tok_stream_next(p_tstream) // consume var
    tok_id := tok_stream_next(p_tstream)
    str := buf_stream_string_from_tok(p_bstream, tok_id^)

    tok_stream_next(p_tstream)
    tok_value := tok_stream_next(p_tstream)

    #partial switch tok_value.type {
    case .lit_int:
        v := str_to_int(buf_stream_string_from_tok(p_bstream, tok_value^))
        return ASTVarDeclareNode{id = str, value = ast_node_lit_int_make(v)}

    case .lit_str:
        v := buf_stream_string_from_tok(p_bstream, tok_value^)
        return ASTVarDeclareNode{id = str, value = ast_node_lit_str_make(v[1:len(v) - 1])}
    }
    // else

    fmt.eprintln("Cannot parse variable declaration, unknown rvalue")
    os.exit(1)
}

parse_cmd :: proc(p_bstream: ^BufStream, p_tstream: ^TokenStream) -> (node: ASTCmdNode) {
    cmd_str := next_str_from_stream(p_bstream, p_tstream) // consume cmd token
    
    node = ast_node_cmd_make(cmd_str)

    // eat string arguments until unable
    for {
        _, success := tok_stream_peek_expect(p_tstream, .lit_str)
        if success == false {
            break
        }
        // else consume

        tstr := next_str_from_stream(p_bstream, p_tstream)
        ast_node_cmd_append_arg(&node, ast_node_lit_str_make(tstr))
    }

    return
}

AST_Parse_Error :: enum {
    None, Failed,
}

parse_ast_from_stream :: proc(p_bstream: ^BufStream, p_tstream: ^TokenStream) -> (ASTSeqNode, AST_Parse_Error) {
    ast_node := ast_node_seq_make()

    is_newline := true

    // TODO: ERROR propagation from parsing
    p_tok := tok_stream_next(p_tstream)
    for p_tok != nil {

        #partial switch p_tok.type {
        case .newline:
            is_newline = true

        case .sym:
            if is_newline == false {
                // some other symbol that is not a variable declaration or symbolic call
                return ast_node, .Failed
            }
            // else, on a start of newline

            str := buf_stream_string_from_tok(p_bstream, p_tok^)

            switch str {
            case "var":
                tok_stream_move_back(p_tstream, 1)
                var_declare_node := parse_var_declare(p_bstream, p_tstream)
                ast_node_seq_append(&ast_node, var_declare_node)
                fmt.println("Created variable declaration node -> ", var_declare_node)

            case "if":
                fmt.println("Reserved if keyword found, but is not implemented yet")

            case:
                tok_stream_move_back(p_tstream, 1)
                cmd_node := parse_cmd(p_bstream, p_tstream)

                ast_node_seq_append(&ast_node, cmd_node)
                fmt.println("Created CMD Node -> ", cmd_node)
            }

        }

        p_tok = tok_stream_next(p_tstream)
    }

    return ast_node, .None
}


main :: proc() {
    if len(os.args) != 2 + 1 {
        fmt.printfln("Hard lang compiler %s", HL_VERSION_STR)
        fmt.println("An extremely simple language that is written just for fun!")

        fmt.println()

        fmt.println("Command usage:")
        fmt.printfln("%s <input file> <output file>", os.args[0])
        return
    }

    fmt.printfln("Using Hard lang compiler %s", HL_VERSION_STR)

    bstream, read_err := buf_stream_read_from_file(os.args[1])
    defer buf_stream_destroy(bstream)

    if read_err != .None {
        fmt.eprintln("Error reading from code file:", read_err)
        os.exit(1)
    }


    // LEXICATION
    tstream, tok_stream_err := buf_stream_parse_as_tok_stream(&bstream)
    defer tok_stream_destroy(tstream)

    if tok_stream_err != .None {
        fmt.eprintln("Error parsing code:", tok_stream_err)
        os.exit(1)
    }

    // convert to AST grammatical analysis
    fmt.println("Converting to Abstract syntax tree...")

    ast_node, ast_err := parse_ast_from_stream(&bstream, &tstream)
    if ast_err != .None {
        fmt.eprintln("Cannot parse AST from token stream:", ast_err)
        os.exit(1)
    }
    // else

    ctarget : CompilationTarget = LINUX_FASM_X86_64_COMPILATION_TARGET

    // start writing assembly
    asm_builder := strings.builder_make()

    ctarget.asm_construct_proc(ast_node, &asm_builder)

    // writing to file for compilation
    tmp_asm_path := strings.concatenate({os.args[2], ".asm"})
    defer delete(tmp_asm_path)
    fmt.printfln("Writing to %s...", tmp_asm_path)

    write_success := os.write_entire_file(tmp_asm_path, transmute([]byte)strings.to_string(asm_builder))

    if write_success == false {
        fmt.eprintfln("Failed to write to %s", tmp_asm_path)
        return
    }

    fmt.printfln("Writing to %s complete.", tmp_asm_path)

    ctarget.asm_compile_proc(tmp_asm_path)
}
