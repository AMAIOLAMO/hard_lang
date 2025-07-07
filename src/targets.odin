package hl

import "core:fmt"
import "core:strings"
import "core:os"

Asm_Construct_Proc :: #type proc(root_seq_ast: ASTSeqNode, p_asm_builder: ^strings.Builder)
Asm_Compile_Proc :: #type proc(asm_path: string)

CompilationTarget :: struct {
    asm_construct_proc: Asm_Construct_Proc,
    asm_compile_proc: Asm_Compile_Proc,
}

LINUX_FASM_X86_64_COMPILATION_TARGET :: CompilationTarget {
    asm_construct_proc = linux_fasm_x86_64_construct,
    asm_compile_proc = linux_fasm_x86_64_compile,
}

linux_fasm_x86_64_construct :: proc(root_seq_ast: ASTSeqNode, p_asm_builder: ^strings.Builder) {
    // === TRANSLATION FROM AST TO ASM === //
    alloc_static_strings: [dynamic]string
    defer delete(alloc_static_strings)

    fmt.println("Translating from Abstract syntax tree to asm...")

    // TODO: instead of hard coding a certain assembly instruction, we can support multiple different
    // implementations called "targets"
    // which simply accepts an AST and string builder, then outputs code
    // and runs compilation for us
    // probably not that hard to abstract this

    // ELF64 x86_64 linux header
    fmt.sbprintln(p_asm_builder, "format ELF64 executable 3\nsegment readable executable\nentry main\n")

    // useful print
    fmt.sbprintln(p_asm_builder, "print:\npush rax\npush rdi\nmov rax, 1\nmov rdi, 1\nsyscall\npop rdi\npop rax\nret\n")

    // MAIN BEGIN
    fmt.sbprintln(p_asm_builder, "main:")

    for node in root_seq_ast.sequence {
        #partial switch snode in node {
        case ASTCmdNode:
            str := snode.args[0].value

            msg_content := str[1:len(str) - 1]

            str_idx := len(alloc_static_strings)
            append(&alloc_static_strings, msg_content)
            fmt.sbprintfln(p_asm_builder, "lea rsi, [__str_%d]\nmov rdx, __str_%d_len\ncall print\n", str_idx, str_idx)
            
        }
    }

    // MAIN END
    fmt.sbprintfln(p_asm_builder, "xor rdi, rdi\nmov rax, 60\nsyscall")

    // Define strings
    if len(alloc_static_strings) > 0 {
        fmt.sbprintln(p_asm_builder, "\nsegment readable writable")

        for i in 0..<len(alloc_static_strings) {
            str := alloc_static_strings[i]
            fmt.sbprintfln(p_asm_builder, "__str_%d: db \"%s\", 10, 0", i, str)
            fmt.sbprintfln(p_asm_builder, "__str_%d_len = $-__str_%d", i, i)
        }
    }

    fmt.println("Translation Complete!")

}


linux_fasm_x86_64_compile :: proc(asm_path: string) {
    fmt.println("Compiling using fasm...")

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


