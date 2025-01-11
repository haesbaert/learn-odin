package main

import "core:bufio"
/* import "core:flags" */
import "core:fmt"
import "core:io"
import "core:os"

Options :: struct {
	bytes: bool `args:"name=c" usage:"Print bytes"`,
	lines: bool `args:"name=l" usage:"Print lines"`,
	words: bool `args:"name=w" usage:"Print words"`,
	/* file:  string `args:"pos=0" usage:"FILE"`, */
}

Result :: struct {
	bytes: u64,
	lines: u64,
	words: u64,
}

/* parse_args :: proc() -> (opt: Options) { */
/* 	flags.parse_or_exit(&opt, os.args, .Odin) */

/* 	if !opt.bytes && !opt.lines && !opt.words { */
/* 		opt.bytes = true */
/* 		opt.lines = true */
/* 		opt.words = true */
/* 	} */

/* 	return */
/* } */

usage :: proc() {
	fmt.fprintf(os.stderr, "usage: wc [-clw] [FILE...]\n")
	os.exit(1)
}

parse_args_unix :: proc() -> (opt: Options, files: [dynamic]string) {
	for o in os.args[1:] {
		switch o {
		case "-c":
			opt.bytes = true
		case "-l":
			opt.lines = true
		case "-w":
			opt.words = true
		case "-h":
			usage()
		case:
			if o != "-" && o[0] == '-' {
				fmt.fprintf(os.stderr, "bad option %v\n", o)
				usage()
			}
			append(&files, o)
		}
	}

	if !opt.bytes && !opt.lines && !opt.words {
		opt.bytes = true
		opt.lines = true
		opt.words = true
	}

	return
}

is_whitespace :: proc(c: byte) -> bool {
	return (c >= 9 && c <= 13) || c == 32
}

print_result :: proc(res: Result, name: string, opt: Options) {
	if opt.lines {
		fmt.printf("% 8d", res.lines)
	}
	if opt.words {
		fmt.printf("% 8d", res.words)
	}
	if opt.bytes {
		fmt.printf("% 8d", res.bytes)
	}
	if len(name) > 0 {
		fmt.printf(" %s", name)
	}
	fmt.print('\n')
}

do_file :: proc(file: string, opt: Options) -> (res: Result, err: os.Error) {
	r: bufio.Reader
	buffer: [1024]byte
	in_word: bool
	c: byte
	fd: os.Handle

	if file == "" || file == "-" {
		fd = os.stdin
	} else {
		fd = os.open(file) or_return
	}
	defer if fd != os.stdin {
		os.close(fd)
	}

	bufio.reader_init_with_buf(&r, os.stream_from_handle(fd), buffer[:])
	defer bufio.reader_destroy(&r)

	for {
		c, err = bufio.reader_read_byte(&r)
		if err == .EOF {
			err = nil
			break
		} else if err != nil {
			fmt.fprintf(os.stderr, "input error: %w", err)

			break
		}

		if !in_word && !is_whitespace(c) {
			in_word = true
			res.words += 1
		} else if in_word && is_whitespace(c) {
			in_word = false
		}
		res.bytes += 1
		if c == '\n' {
			res.lines += 1
		}
	}

	return
}

do_files :: proc(files: []string, opt: Options) -> (exit_code: int) {
	total: Result

	if len(files) == 0 {
		res, err := do_file("", opt)
		if err != nil {
			fmt.fprintf(os.stderr, "wc: %s\n", os.error_string(err))
			exit_code = 1
		} else {
			print_result(res, "", opt)
		}
	}

	for file in files {
		res, err := do_file(file, opt)
		if err != nil {
			fmt.fprintf(os.stderr, "wc: %s: %s\n", file, os.error_string(err))
			exit_code = 1
		} else {
			print_result(res, file, opt)

			if len(files) > 1 {
				total.bytes += res.bytes
				total.lines += res.lines
				total.words += res.words
			}
		}
	}

	if len(files) > 1 {
		print_result(total, "total", opt)
	}

	return
}

main :: proc() {
	opt, files := parse_args_unix()
	exit_code := do_files(files[:], opt)
	delete(files)

	os.exit(exit_code)
}
