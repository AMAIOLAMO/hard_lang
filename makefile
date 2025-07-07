.PHONY: run build

build:
	odin build src/ -vet -strict-style -out:build/hard_lang

