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
import "core:strconv"
import "core:sys/posix"

Error :: union #shared_nil {
	net.Network_Error,
	net.Parse_Endpoint_Error,
	posix.Errno,
	os.Error,
}

Options :: struct {
	inet4:  bool `args:"name=4" usage:"use ipv4"`,
	inet6:  bool `args:"name=6" usage:"use ipv6"`,
	listen: bool `args:"name=l" usage:"listen"`,
	pos0:   string `args:"pos=0" usage:"host or port"`,
	pos1:   string `args:"pos=1" usage:"port if host"`,
}

write_all :: proc(h: os.Handle, buf: []byte) -> (err: Error) {
	wn_total: int

	for wn_total < len(buf) {
		wn_total += os.write(h, buf[wn_total:]) or_break
	}

	return
}

conn_loop :: proc(sock: net.TCP_Socket) -> (err: Error) {
	pfds: [2]posix.pollfd
	buffer := make([]byte, 16384)
	defer {
		delete(buffer)
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

			other := os.Handle(pfds[1].fd if i == 0 else pfds[0].fd)
			write_all(other, buffer[:rn]) or_return
		}
	}

	return
}

parse_host_port :: proc(opt: Options) -> (ep: net.Endpoint, err: Error) {
	ok: bool

	portpos := opt.listen && opt.pos1 == "" ? opt.pos0 : opt.pos1
	ep.port, ok = strconv.parse_int(portpos, 10)

	if !ok || ep.port <= 0 || ep.port > 65535 {
		err = net.Network_Error(.Bad_Port)
		return
	}

	if opt.listen && opt.pos1 == "" {
		ep.address = opt.inet6 ? net.IP6_Any : net.IP4_Any
		return
	}

	host_or_ep := net.parse_hostname_or_endpoint(opt.pos0) or_return
	switch t in host_or_ep {
	case net.Endpoint:
		ep.address = t.address
	case net.Host:
		ep4, ep6 := net.resolve(t.hostname) or_return
		ep.address = opt.inet6 ? ep6.address : ep4.address
		if ep.address == nil && !opt.inet6 && !opt.inet4 {
			ep.address = ep6.address
		}
		if ep.address == nil {
			err = net.Network_Error(.Invalid_Hostname_Error)
			return
		}
	}

	return
}

peer_sock :: proc(opt: Options, ep: net.Endpoint) -> (sock: net.TCP_Socket, err: Error) {
	if !opt.listen {
		return net.dial_tcp(ep)
	}

	listen_fd := net.listen_tcp(ep, 1) or_return
	defer {
		net.close(listen_fd)
	}

	sock, _, err = net.accept_tcp(listen_fd)

	return
}

main_ :: proc() -> (err: Error) {
	opt: Options

	flags.parse_or_exit(&opt, os.args)
	if opt.inet4 && opt.inet6 {
		opt.inet4 = false
		opt.inet6 = false
	}

	ep := parse_host_port(opt) or_return
	sock := peer_sock(opt, ep) or_return
	defer {
		net.close(sock)
	}
	return conn_loop(sock)
}

main :: proc() {
	err := main_()
	if err != nil {
		fmt.fprintf(os.stderr, "netcat: %w\n", err)
		os.exit(1)
	}
	/* clean up runtime allocations :/ */
	net.destroy_dns_configuration()
	delete(os.args)
}
