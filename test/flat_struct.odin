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
integers_struct_test :: proc(t: ^testing.T) {
	json := `{"a_int":1,"b_i64":2,"c_i32":3,"d_i16":4,"e_i8":5,"f_uint":6,"g_u64":7,"h_u32":8,"i_u16":9,"j_u8":10}`
	sb := strings.builder_make()
	i := Integers{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	integers_to_json(&i, &sb)
	testing.expect_value(t, json, strings.to_string(sb))
	i_2 := Integers{}
	integers_from_json(&i_2, json[:])
	testing.expect_value(t, i, i_2)
}


@(json)
Floats :: struct {
	_f64: f64,
	_f32: f64, // Highly recommend using f64 _always_, there are multiple casts to f64 anyway. Tons of lossiness!
	_f16: f64, // Highly recommend using f64 _always_, there are multiple casts to f64 anyway. Tons of lossiness!
}

@(test)
floats_struct_test :: proc(t: ^testing.T) {
	str := `{"_f64":43434.555,"_f32":123.4567,"_f16":1.999}`
	fs := Floats{}
	floats_from_json(&fs, str)
	fs_assert := Floats{43434.555, 123.4567, 1.999}
	testing.expect_value(t, fs, fs_assert)

	str_2 := `{"_f64":434343.5555,"_f32":111111.45678,"_f16":1.9999}`
	fs = Floats{}
	floats_from_json(&fs, str_2)
	fs_assert_2 := Floats{434343.5555, 111111.45678, 1.9999}
	testing.expect_value(t, fs, fs_assert_2)

	// sb := strings.builder_make()
	// floats_to_json(&fs, &sb)
	// testing.expect_value(t, str, strings.to_string(sb))
}
