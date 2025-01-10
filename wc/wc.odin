package main

/* import "base:runtime" */
import "core:bufio"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:os"

Options :: struct {
	bytes: bool `args:"name=c" usage:"Print bytes"`,
	lines: bool `args:"name=l" usage:"Print lines"`,
	words: bool `args:"name=w" usage:"Print words"`,
	file: string `args:"pos=0" usage:"FILE"`,
}

parse_args :: proc() -> Options {
	opt: Options

	flags.parse_or_exit(&opt, os.args, .Odin)

	if !opt.bytes && !opt.lines && !opt.words {
		opt.bytes = true
		opt.lines = true
		opt.words = true
	}

	return opt
}

is_whitespace :: proc(c: byte) -> bool {
	return (c >= 9 && c <= 13) || c == 32
}

main :: proc() {
	r: bufio.Reader
	buffer: [1024]byte
	bytes, words, lines: u64
	in_word: bool
	fd: os.Handle

	opt := parse_args()

//	fmt.printf("%#v\n", opt)

	if len(opt.file) == 0 {
		fd = os.stdin
	} else {
		err: os.Error

		fd, err = os.open(opt.file)
		if err != nil {
			fmt.fprintf(os.stderr, "wc: %s: %s\n", opt.file, os.error_string(err))
			os.exit(1)
		}
	}
	defer if fd != os.stdin {
		fmt.printf("closing!\n")
		os.close(fd)
	}

	bufio.reader_init_with_buf(&r, os.stream_from_handle(fd), buffer[:])
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
		bytes += 1
		if c == '\n' {
			lines += 1
		}
	}

	if opt.lines {
		fmt.printf("% 15d", lines)
	}
	if opt.words {
		fmt.printf("% 15d", words)
	}
	if opt.bytes {
		fmt.printf("% 15d", bytes)
	}
	fmt.print('\n')
}
