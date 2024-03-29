package test_dir

import "deep"

// @(json)
// License :: struct {
// 	can_drive:         bool,
// 	state:             string,
// 	days_until_expiry: uint,
// 	a:                 u16,
// 	b:                 u32,
// 	c:                 u64,
// 	d:                 i16,
// 	e:                 i32,
// 	f:                 i64,
// 	info:              []string,
// 	int_arr:           [3]int,
// 	cstr:              cstring,
// 	a_enum:            License_Type,
// }

@(json = {lowercase = true}) // lowercase is by default false
License_Type :: enum {
	Motorcycle,
	Car,
}
