package dirty

import "core:intrinsics"
import "core:simd"

// TODO(perf) simd all the things
find_next_delim_or_end :: proc(s: string, delim: rune) -> int {
	offset := 0
	for b, i in s {
		if b == delim || b == '}' {
			offset = i + 1
			break
		}
	}
	return offset
}


import "core:bytes"
import "core:fmt"
main :: proc() {
	str := `{"a_int":55,"b_int":22}`
	xx := find_next_delim_or_end(str[:], ',')
	fmt.println(str[xx:])
	yy := find_next_delim_or_end(str[:], ':')
	fmt.println(str[xx + yy:])
}
