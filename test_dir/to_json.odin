package test_dir

import "deep"

@(json)
A_Struct :: struct {
	// a_enum: A_Enum,
	// deeper_struct: A_Second_Struct,
	// a_bool:   bool,
	// a_string: string,
	// a:        u16,
	// b:        u32,
	// c:        u64,
	d: f32,
	e: f64,
	f: f64,
	// char:     rune,
	// info:     []string,
	// int_arr:  [3]int,
	// cstr:     cstring,
}

// @(json)
// A_Second_Struct :: struct {
// 	that_contains_an_enum: A_Enum,
// }

@(json = {lowercase = true}) // lowercase is by default false
A_Enum :: enum {
	Motorcycle,
	Car,
}
