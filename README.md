# Hard lang v0.0.0

A "very hard" language that is easy to use! Written as an insider joke / pun :P

requires Odin compiler and fasm (flat assembler) to compile

## Usage
```
hard_lang <input_hl_file> <output_executable>
```
currently it takes in only 1 hard_lang file (abbreviated as `hl`) and outputs to an executable

## target platforms
Currently the compiler only supports fasm-linux-x86_64 native assembly
though Im planning to support fasm-windows-x84 as well!


## Compilation
```
make build
```

This should compile hard lang compiler into the `build/` directory located relative to the root directory

---
LICENSED by CXRedix UNDER MIT
