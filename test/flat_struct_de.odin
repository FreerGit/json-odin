//+private
package json_test

import "core:strings"
import "core:testing"

@(json)
Integers :: struct {
	a_int: int,
	b_int: int,
}

import "core:fmt"

@(test)
simple_struct :: proc(t: ^testing.T) {
	json := `{"a_int":55,"b_int":22}`
	// sb := strings.builder_make()
	i := Integers{}
	integers_from_json(&i, json)
	testing.expect_value(t, i, Integers{55, 22})
}
