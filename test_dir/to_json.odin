package test_dir

import "deep"

// @(json = {strict = false})
// Employee :: struct {
// 	name: string `json:_name`,
// 	age:  int `json:Age`,
// 	occ:  []string,
// }


@(json)
License :: struct {
	can_drive:         bool,
	state:             string,
	days_until_expiry: uint,
	a:                 u16,
	b:                 u32,
	c:                 u64,
	d:                 i16,
	e:                 i32,
	f:                 i64,
	info: 			   []string,
	int_arr:	       [3]int,
	cstr:			   cstring
}
/*
Value_Decl (n_attrs:1) 
Attribute (n_elm:1) 
Field_Value 
Ident (json)
Comp_Lit (n_elms:1)
Field_Value 
Ident (strict)
Ident (false)
Ident (Employee)
Struct_Type(fields:2) 
Field_List (n_elm:2) 
Field (Tag:`json:_name`(String))
Ident (name)
Ident (string)
Field (Tag:`json:Age`(String))
Ident (age)
Ident (int)

Value_Decl (n_attrs:1) 
	Attribute (n_elm:1) 
		Ident (json)
Ident (License)
Struct_Type(fields:1) 
Field_List (n_elm:1) 
	Field 
		Ident (can_drive)
		Ident (bool)
*/
