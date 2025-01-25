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

import "core:container/intrusive/list"
import "core:fmt"

Animal :: struct {
	entry:   list.Node,
	species: string,
	age:     int,
}

Frog :: struct {
	color:  string,
	animal: Animal,
}

Spider :: struct {
	using animal: Animal,
	num_legs:     int,
}

handle_animal :: proc(a: Animal) {
	fmt.printf("anemar %s has %d years\n", a.species, a.age)
}

main :: proc() {
	la, lb: list.List

	frog := Frog {
		animal = Animal{species = "frog", age = 4},
		color = "red",
	}
	spider := Spider {
		species  = "spider",
		age      = 2,
		num_legs = 8,
	}

	list.push_back(&la, &frog.animal.entry)
	list.push_back(&la, &spider.entry)

	handle_animal(frog.animal)
	handle_animal(spider)	/* almost like traits huh */
	fmt.print('\n');

	it := list.iterator_head(la, Animal, "entry")
	for a in list.iterate_next(&it) {
		handle_animal(a^)
		if a.species == "spider" {
			s := container_of(a, Spider, "animal")
			fmt.printf("spider has %d legs\n", s.num_legs)
		} else if a.species == "frog" {
			f := container_of(a, Frog, "animal")
			fmt.printf("frog has color %s\n", f.color)
		}
	}
}
