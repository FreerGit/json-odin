package json

import "core:log"
import "core:odin/ast"
import "core:strconv"

Gen_Settings :: struct {
	name:   string,
	strict: bool,
	type:   Odin_Type,
	fields: [dynamic]Odin_Field,
}

Odin_Type :: enum {
	Struct,
	Enum,
}

Odin_Field :: struct {
	name:      string,
	type:      Data_Type,
	tag:       string,
	lowercase: bool,
}


Data_Type :: struct {
	kind:          string, // eg bool, int
	is_array:      bool,
	is_enum:       bool,
	arr_len_fixed: int,
	ptr_depth:     int, // [][]bar == 2
}

// TODO handle keys such as static, lowercase.
// if has_fv {
// 	cmp_lit, has_cmp := fv.value.derived.(^ast.Comp_Lit)
// 	if has_cmp {
// 		for elem in cmp_lit.elems {
// 			fv, ok := elem.derived.(^ast.Field_Value)
// 			assert(ok, "no field value")
// 			ident_key := fv.field.derived.(^ast.Ident) or_return
// 			ident_value := fv.value.derived.(^ast.Ident) or_return
// 			if ident_key.name == "strict" && ident_value.name == "false" {
// 				ms.strict = false
// 			}
// 			if is_enum && ident_key.name == "lowercase" && ident_value.name == "true" {
// 				for f in &ms.fields {
// 					f.lowercase = true
// 				}
// 			}
// 		}
// 	}
// }


extract_gen_settings :: proc(val: ^ast.Value_Decl) -> (ms: Gen_Settings, ok: bool) {
	type_ident, to_extract := val.names[0].derived.(^ast.Ident)
	assert(to_extract)
	for attr in val.attributes {
		for elem in attr.elems {

			fv, has_fv := elem.derived.(^ast.Field_Value)
			ident: ^ast.Ident = nil
			if has_fv {
				// TODO err handling
				ident = fv.field.derived.(^ast.Ident) or_else panic("no field")

			} else {
				// TODO err handling
				ident = elem.derived.(^ast.Ident) or_else panic("no ident")
			}


			if ident.name == "json" {

				as_struct, is_struct := val.values[0].derived.(^ast.Struct_Type)
				as_enum, is_enum := val.values[0].derived.(^ast.Enum_Type)
				ms := Gen_Settings {
					name   = type_ident.name,
					strict = true,
				}
				if is_struct {
					ms.type = .Struct
					for field in as_struct.fields.list {
						set_struct_fields(&ms, field, .Struct)
					}
				} else if is_enum {
					ms.type = .Enum
					for field in as_enum.fields {
						field_ident, has_ident := field.derived.(^ast.Ident)
						assert(has_ident)
						append_elem(
							&ms.fields,
							Odin_Field {
								name = field_ident.name,
								type = Data_Type{kind = "string", is_enum = true},
								tag = "",
							},
						)
					}
				}

				return ms, true
			}
		}
	}

	return {}, false
}

fixup_enum_types :: proc(gs: ^[dynamic]Gen_Settings) {
	gs := gs
	// Find all enums and update the ms for fields that are actually enums.
	for &setting in gs {
		if setting.type == .Enum {
			for &enum_setting in gs {
				for &field in enum_setting.fields {
					if field.type.kind == setting.name {
						field.type.is_enum = true
					}
				}
			}
		}
	}

}

extract_static_array_len :: proc(arr: ^ast.Array_Type) -> int {
	if arr.len != nil {
		len_str := arr.len.derived.(^ast.Basic_Lit).tok.text
		len_int, ok := strconv.parse_int(len_str)
		assert(ok)
		return len_int
	}
	return 0
}

set_struct_fields :: proc(ms: ^Gen_Settings, field: ^ast.Field, t: Odin_Type) {
	field_type, has_ft := field.type.derived.(^ast.Ident)
	field_info, has_info := field.names[0].derived.(^ast.Ident)
	field_array, has_array := field.type.derived.(^ast.Array_Type)

	if has_ft && has_info {
		field_enum, is_enum := field_type.derived.(^ast.Enum_Type)
		field_struct, is_struct := field_type.derived.(^ast.Struct_Type)

		data_type := Data_Type {
			kind     = field_type.name,
			is_enum  = is_enum,
			is_array = has_array,
		}
		append_elem(&ms.fields, Odin_Field{name = field_info.name, type = data_type, tag = ""})
	} else if has_array && has_info {
		// TODO handle fixed sizes
		data_type := Data_Type {
			is_array = true,
		}
		array_ident, has_ident := field_array.elem.derived.(^ast.Ident)
		array_type, is_nested := field.type.derived.(^ast.Array_Type)
		if has_ident {
			data_type.arr_len_fixed = extract_static_array_len(array_type)
			data_type.ptr_depth += 1
			data_type.kind = array_ident.name
		} else {
			for {
				// walk down the array types until indent (normal type)
				array_ident, bottom := array_type.elem.derived.(^ast.Ident)
				data_type.ptr_depth += 1
				if bottom {
					data_type.arr_len_fixed = extract_static_array_len(array_type)
					data_type.kind = array_ident.name
					break
				}
				array_type, is_nested = array_type.elem.derived.(^ast.Array_Type)
				assert(is_nested)
			}

		}

		append_elem(&ms.fields, Odin_Field{name = field_info.name, type = data_type, tag = ""})

	} else {
		panic("?")
	}
}
