package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"

is_whitespace :: proc(c: byte) -> bool {
	return (c >= 9 && c <= 13) || c == 32
}

main :: proc() {
	r: bufio.Reader
	buffer: [1024]byte
	chars, words, lines: u64
	in_word: bool

	bufio.reader_init_with_buf(&r, os.stream_from_handle(os.stdin), buffer[:])
	defer bufio.reader_destroy(&r)

	for {

		c, err := bufio.reader_read_byte(&r)
		if err == .EOF {
			break
		} else if err != nil {
			fmt.fprintf(os.stderr, "input error: %w", err)
			break
		}

		if !in_word && !is_whitespace(c) {
			in_word = true
			words += 1
		} else if in_word && is_whitespace(c) {
			in_word = false
		}
		chars += 1
		if c == '\n' {
			lines += 1
		}
	}

	fmt.printf("% 15d% 15d% 15d\n", lines, words, chars)
}
