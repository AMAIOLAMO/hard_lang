package hl

import "core:fmt"
import "core:os"
import "core:strings"

str_to_int :: proc(str: string) -> int {
    result: int = 0

    for rune in str {
        assert(rune_is_digit(rune), "the given string is not a valid int")
        result *= 10
        result += int(rune - '0')
    }

    return result
}

translate_add :: proc(p_asm_builder: ^strings.Builder, p_bstream: ^BufStream, p_tstream: ^TokenStream) {
    p_tok_lhs := tok_stream_next(p_tstream)
    tok_stream_next(p_tstream)
    p_tok_rhs := tok_stream_next(p_tstream)

    str_lhs := buf_stream_string_from_tok(p_bstream, p_tok_lhs^)
    str_rhs := buf_stream_string_from_tok(p_bstream, p_tok_rhs^)

    lhs := str_to_int(str_lhs)
    rhs := str_to_int(str_rhs)

    fmt.sbprintfln(p_asm_builder, "mov rax, %d", lhs)
    fmt.sbprintfln(p_asm_builder, "add rax, %d", rhs)
}

// translate_println :: proc(p_asm_builder: ^strings.Builder, p_bstream: ^BufStream, p_tstream: ^TokenStream, p_static_strings: ^[dynamic]string) {
    // tok_stream_next(p_tstream) // consume println token
    // p_tok_msg := tok_stream_next(p_tstream)
    //
    // str := buf_stream_string_from_tok(p_bstream, p_tok_msg^)
    //
    // msg_content := str[1:len(str) - 1]
    //
    // str_idx := len(p_static_strings^)
    // append(p_static_strings, msg_content)
    //
    // fmt.sbprintfln(p_asm_builder, "lea rsi, [__str_%d]\nmov rdx, __str_%d_len\ncall print\n", str_idx, str_idx)
// }

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
    tstream, parse_err := buf_stream_parse_as_tok_stream(&bstream)
    defer tok_stream_destroy(tstream)

    if parse_err != .None {
        fmt.eprintln("Error parsing code:", parse_err)
        os.exit(1)
    }

    ast_node := ast_node_seq_make()

    // convert to AST grammatical analysis
    fmt.println("Converting to Abstract syntax tree...")
    p_tok := tok_stream_next(&tstream)

    is_newline := true

    for p_tok != nil {

        #partial switch p_tok.type {
        case .newline:
            is_newline = true
        // case .add:
        //     tok_stream_move_back(&tstream, 2) // revert + and lhs
        //
        //     translate_add(&asm_builder, &bstream, &tstream)
        case .sym:
            str := buf_stream_string_from_tok(&bstream, p_tok^)

            if str == "println" {
                tok_stream_move_back(&tstream, 1)
                tok_stream_next(&tstream) // consume println token

                p_tok_msg := tok_stream_next(&tstream)
                tstr := buf_stream_string_from_tok(&bstream, p_tok_msg^)

                cmd_node := ast_node_cmd_make("println")
                ast_node_cmd_append_arg(&cmd_node, ast_node_lit_str_make(tstr))

                ast_node_seq_append(&ast_node, cmd_node)
                fmt.println("Created CMD Node -> cmd:", cmd_node.cmd, ", args:", cmd_node.args)

            //
            //     tok_stream_next(&tstream) // consume println token
            //     p_tok_msg := tok_stream_next(&tstream)
            //
            //     p_node := ast_node_make(type = .cmd, parent = p_ast)
            //
            //     args := make([dynamic]Token)
            //
            //     append(&args, p_tok_msg^)
            //
            //     p_node.data = ASTNodeCmdData{ p_tok^, args }
            //     #partial switch v in p_ast.data {
            //     case ASTNodeSequenceData:
            //         seq := v.sequence
            //         append(&seq, p_node)
            //     }

                // tstr := buf_stream_string_from_tok(&bstream, p_tok_msg^)
                //
                // msg_content := tstr[1:len(tstr) - 1]

                // p_node.type = .cmd
                // p_node.data = ASTNodeCmdData{ p_tok^, args[:] }
                // p_node.parent = &ast
                // p_node.children = make([dynamic]^ASTNode)
                //
                // append(&ast.children, p_node)

                // str_idx := len(p_static_strings^)
                // append(p_static_strings, msg_content)
                //
                // fmt.sbprintfln(p_asm_builder, "lea rsi, [__str_%d]\nmov rdx, __str_%d_len\ncall print\n", str_idx, str_idx)
                // translate_println(&asm_builder, &bstream, &tstream, &alloc_static_strings)
            }

        }

        p_tok = tok_stream_next(&tstream)
        is_newline = false
    }


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
    pid, fork_err := os.fork()

    if fork_err != nil {
        fmt.eprintln("Error forking:", fork_err)
        return
    }
    // else

    if pid == 0 {
        // child process
        exec_err := os.execvp("fasm", {tmp_asm_path})
        if exec_err != nil {
            fmt.eprintln("Error executing fasm:", exec_err)
            return
        }
    }

}
