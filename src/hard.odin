package hl

import "core:fmt"
import "core:os"
import "core:strings"

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
    
    tok_str := tok_stream_peek(p_tstream)

    node = ast_node_cmd_make(cmd_str)

    // eat string arguments until unable
    for tok_str != nil && tok_str.type == .lit_str {
        tstr := next_str_from_stream(p_bstream, p_tstream)
        ast_node_cmd_append_arg(&node, ast_node_lit_str_make(tstr))

        tok_str = tok_stream_peek(p_tstream)
    }

    return
}

compile_fasm :: proc(asm_path: string) {
    pid, fork_err := os.fork()

    if fork_err != nil {
        fmt.eprintln("Error forking:", fork_err)
        return
    }
    // else

    if pid == 0 {
        // child process
        exec_err := os.execvp("fasm", {asm_path})
        if exec_err != nil {
            fmt.eprintln("Error executing fasm:", exec_err)
            return
        }
    }
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
            str := buf_stream_string_from_tok(p_bstream, p_tok^)
            
            if str == "var" {
                tok_stream_move_back(p_tstream, 1)
                var_declare_node := parse_var_declare(p_bstream, p_tstream)
                ast_node_seq_append(&ast_node, var_declare_node)
                fmt.println("Created variable declaration node -> ", var_declare_node)

            } else if str == "println" {
                tok_stream_move_back(p_tstream, 1)

                cmd_node := parse_cmd(p_bstream, p_tstream)

                ast_node_seq_append(&ast_node, cmd_node)
                fmt.println("Created CMD Node -> ", cmd_node)
            }

        }

        p_tok = tok_stream_next(p_tstream)
        is_newline = false
    }

    return ast_node, .None
}


main :: proc() {
    if len(os.args) != 2 + 1 {
        fmt.println("Hard lang compiler v0.0.0")
        fmt.println("An extremely simple language that is written just for fun!")

        fmt.println()

        fmt.println("Command usage:")
        fmt.printfln("%s <input file> <output file>", os.args[0])
        return
    }

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

    // === TRANSLATION FROM AST TO ASM === //
    alloc_static_strings: [dynamic]string
    defer delete(alloc_static_strings)

    // start printing basic content
    asm_builder := strings.builder_make()

    fmt.println("Translating from Abstract syntax tree...")

    // ELF64 x86_64 linux header
    fmt.sbprintln(&asm_builder, "format ELF64 executable 3\nsegment readable executable\nentry main\n")

    // useful print
    fmt.sbprintln(&asm_builder, "print:\npush rax\npush rdi\nmov rax, 1\nmov rdi, 1\nsyscall\npop rdi\npop rax\nret\n")

    // MAIN BEGIN
    fmt.sbprintln(&asm_builder, "main:")

    for node in ast_node.sequence {
        #partial switch snode in node {
        case ASTCmdNode:
            str := snode.args[0].value

            msg_content := str[1:len(str) - 1]

            str_idx := len(alloc_static_strings)
            append(&alloc_static_strings, msg_content)
            fmt.sbprintfln(&asm_builder, "lea rsi, [__str_%d]\nmov rdx, __str_%d_len\ncall print\n", str_idx, str_idx)
            
        }
    }

    // MAIN END
    fmt.sbprintfln(&asm_builder, "xor rdi, rdi\nmov rax, 60\nsyscall")

    // Define strings

    if len(alloc_static_strings) > 0 {
        fmt.sbprintln(&asm_builder, "\nsegment readable writable")

        for i in 0..<len(alloc_static_strings) {
            str := alloc_static_strings[i]
            fmt.sbprintfln(&asm_builder, "__str_%d: db \"%s\", 10, 0", i, str)
            fmt.sbprintfln(&asm_builder, "__str_%d_len = $-__str_%d", i, i)
        }
    }

    fmt.println("Translation Complete!")


    // ASM COMPILATION
    tmp_asm_path := strings.concatenate({os.args[2], ".asm"})
    defer delete(tmp_asm_path)
    fmt.printfln("Writing to %s...", tmp_asm_path)

    write_success := os.write_entire_file(tmp_asm_path, transmute([]byte)strings.to_string(asm_builder))

    if write_success == false {
        fmt.eprintfln("Failed to write to %s", tmp_asm_path)
        return
    }

    fmt.printfln("Writing to %s complete.", tmp_asm_path)

    fmt.println("Compiling using fasm...")

    // start compilation for fasm
    compile_fasm(tmp_asm_path)
}
