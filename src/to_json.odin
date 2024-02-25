package json

import "deep"

@(json = {strict = false})
Employee :: struct {
	name: string `json:_name`,
	age:  int `json:Age`,
}

// Value_Decl (n_attrs:1) 
// Attribute (n_elm:1) 
// Ident (json)
// Ident (Employee)
// Struct_Type(fields:2) 
// Field_List (n_elm:2) 
// Field 
// Ident (name)
// Ident (string)
// Field 
// Ident (age)
// Ident (int)
