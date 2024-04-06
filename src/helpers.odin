package json

// TODO(perf) simd all the things
find_next_delim_or_end :: `find_next_delim_or_end :: proc(s: string, delim: rune) -> int {
	offset := 0
	for b, i in s {
		if b == delim || b == '}' {
			offset = i
			break
		}
	}
	return offset
}

`


generate_helper_procs :: proc() -> string {
	return find_next_delim_or_end
}
