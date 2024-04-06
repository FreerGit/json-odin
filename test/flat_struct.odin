//+private
package json_test

import "core:strings"
import "core:testing"

@(json)
Integers :: struct {
	a_int:  int,
	b_i64:  i64,
	c_i32:  i32,
	d_i16:  i16,
	e_i8:   i8,
	f_uint: uint,
	g_u64:  u64,
	h_u32:  u32,
	i_u16:  u16,
	j_u8:   u8,
}


@(test)
number_struct_test :: proc(t: ^testing.T) {
	json := `{"a_int":1,"b_i64":2,"c_i32":3,"d_i16":4,"e_i8":5,"f_uint":6,"g_u64":7,"h_u32":8,"i_u16":9,"j_u8":10}`
	sb := strings.builder_make()
	i := Integers{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	integers_to_json(&i, &sb)
	testing.expect_value(t, json, strings.to_string(sb))
	i_2 := Integers{}
	integers_from_json(&i_2, json[:])
	testing.expect_value(t, i, i_2)
}
