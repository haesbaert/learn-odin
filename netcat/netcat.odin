/*
 * Copyright (c) 2025 Christiano Haesbaert <haesbaert@haesbaert.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

package main

import "core:c"
import "core:flags"
import "core:fmt"
import "core:net"
import "core:os"
import "core:sys/posix"

Error :: union #shared_nil {
	net.Network_Error,
	posix.Errno,
	os.Error,
}

Options :: struct {
	inet4: bool `args:"name=4" usage:"use ipv4"`,
	inet6: bool `args:"name=6" usage:"use ipv6"`,
	ep:    net.Host_Or_Endpoint `args:"pos=0" usage:"host:port"`,
}

flag_checker :: proc(
	model: rawptr,
	name: string,
	value: any,
	args_tag: string,
) -> (
	error: string,
) {
	port: int

	switch t in value.(net.Host_Or_Endpoint) {
	case net.Endpoint:
		port = t.port
	case net.Host:
		port = t.port
	}

	if port == 0 {
		error = "must specify port, like `192.168.1.1:22`"
	}

	return
}

write_all :: proc (h: os.Handle, buf: []byte) -> (err: Error) {
	wn_total: int

	for wn_total < len(buf) {
		wn_total += os.write(h, buf[wn_total:]) or_break
	}

	return
}

tcp_dial_ep :: proc(target: net.Host_Or_Endpoint) -> (sock: net.TCP_Socket, err: Error) {
	switch t in target {
	case net.Host:
		sock, err = net.dial_tcp(t.hostname, t.port)
	case net.Endpoint:
		sock, err = net.dial_tcp(t)
	}
	return
}


doit :: proc(opt: Options) -> (err: Error) {
	pfds: [2]posix.pollfd
	buffer := make([]byte, 16384)
	defer {
		delete(buffer)
	}

	sock := tcp_dial_ep(opt.ep) or_return
	defer {
		net.close(sock)
	}

	pfds[0].fd = 0
	pfds[0].events = {.IN}
	pfds[1].fd = posix.FD(sock)
	pfds[1].events = {.IN}

	for {
		r := posix.poll(&pfds[0], 2, -1)
		if r == -1 {
			return posix.errno()
		}

		for i := 0; r > 0 && i < 2; i += 1 {
			wn, rn: int

			if .IN not_in pfds[i].revents {
				continue
			}
			r -= 1
			rn = os.read(os.Handle(pfds[i].fd), buffer) or_return
			if rn == 0 {
				if os.Handle(pfds[i].fd) == os.stdin {
					pfds[i].events = {}
					posix.shutdown(posix.FD(sock), .WR)
					continue
				}
				return
			}

			other: = os.Handle(pfds[1].fd if i == 0 else pfds[0].fd)
			write_all(other, buffer[:rn]) or_return
		}
	}

	return
}

main :: proc() {
	opt: Options

	flags.register_flag_checker(flag_checker)
	flags.parse_or_exit(&opt, os.args)

	err := doit(opt)
	if err != nil {
		fmt.fprintf(os.stderr, "netcat: %w", err)
		os.exit(1)
	}
	/* clean up runtime allocations :/ */
	net.destroy_dns_configuration()
	delete(os.args)
}
