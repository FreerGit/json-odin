package test_dir

import "deep"

@(json)
A_Struct :: struct {
	a_enum:        A_Enum,
	deeper_struct: A_Second_Struct,
	info:          []int,
}

@(json)
A_Second_Struct :: struct {
	that_contains_an_enum: A_Enum,
}

@(json = {lowercase = true}) // lowercase is by default false
A_Enum :: enum {
	Motorcycle,
	Car,
}
