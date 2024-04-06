package json


import "core:log"
import "core:strconv"
import "core:strings"


write_indented :: proc(sb: ^strings.Builder, str: string, ident: int) {
	for _ in 0 ..< ident {
		strings.write_string(sb, "	")
	}
	strings.write_string(sb, str)
}

write_string_builder_start :: proc(sb: ^strings.Builder, ident: int) {
	write_indented(sb, "write_string(sb, ", ident)
}

write_given_builder_start :: proc(sb: ^strings.Builder, builder_t: string, ident: int) {
	using strings
	write_indented(sb, "write_", ident)
	write_string(sb, builder_t)
	write_string(sb, "(sb, ")
}

write_field_access_by_name :: proc(
	sb: ^strings.Builder,
	type_name: string,
	field: Odin_Field,
	to_access: bool,
) {
	using strings
	write_string(sb, to_lower(type_name))
	if to_access {
		write_string(sb, ".")
		write_string(sb, field.name)
	}
}

write_field_value :: proc(
	sb: ^strings.Builder,
	field: Odin_Field,
	type_name: string,
	to_access: bool,
	ident: int,
) {
	using strings
	switch field.type.kind {
	case "string":
		if !field.type.is_enum {
			write_given_builder_start(sb, "quoted_string", ident)
			write_field_access_by_name(sb, type_name, field, to_access)
		}
	case "cstring":
		write_given_builder_start(sb, "quoted_string", ident)
		write_string(sb, "string(")
		write_field_access_by_name(sb, type_name, field, to_access)
		write_string(sb, ")")
	case "rune":
	// if field.type.is_array {
	// 	write_string_builder_start(sb, 1)
	// 	write_string(sb, "ele")
	// } else {
	// 	write_string_builder_start(sb, 1)
	// 	write_string(sb, "\"\\\"\")\n")
	// 	write_field_access_by_name(sb, "rune", type_name, 1)
	// 	write_field_access_by_name(sb, type_name, field)
	// 	write_string(sb, ")\n")
	// 	write_string_builder_start(sb, 1)
	// 	write_string(sb, "\"\\\"\"")
	// }
	case "bool":
		write_string_builder_start(sb, 1)
		write_field_access_by_name(sb, type_name, field, to_access)
		write_string(sb, " ? \"true\" : \"false\"")
	case "uint", "u64", "u32", "u16", "u8":
		write_given_builder_start(sb, "u64", ident)
		write_string(sb, "u64(")
		write_field_access_by_name(sb, type_name, field, to_access)
		write_string(sb, ")")
	case "int", "i64", "i32", "i16", "i8":
		write_given_builder_start(sb, "i64", ident)
		write_string(sb, "i64(")
		write_field_access_by_name(sb, type_name, field, to_access)
		write_string(sb, ")")
	case "f64", "f32", "f16":
		// TODO
		write_given_builder_start(sb, "f64", ident)
		write_string(sb, "f64(")
		write_field_access_by_name(sb, type_name, field, to_access)
		write_string(sb, "), 'f'")
	case:
		// log.warn(field)
		log.warn("Unknown type:", field.type.kind, "<- might be recursive, otherwise unsupported.")
		write_indented(sb, to_lower(field.type.kind), ident)
		if field.type.is_enum {
			write_string(sb, "_to_json(")
		} else {
			write_string(sb, "_to_json(&")
		}
		write_string(sb, to_lower(type_name))
		write_string(sb, ".")
		write_string(sb, field.name)
		write_string(sb, ", sb")
	}
	write_string(sb, ")\n")
}

import "core:fmt"

write_for_loops :: proc(sb: ^strings.Builder, name: string, field: Odin_Field, start_ident: int) {
	using strings

	builder := strings.builder_make()
	name_with_access := fmt.sbprintf(&builder, "%s.%s", name, field.name)
	prev_access_name := to_lower(clone(name_with_access))
	list_of_prev_names: [dynamic]string = {clone(prev_access_name)}
	builder_destroy(&builder)

	assert(field.type.is_array)
	write_string_builder_start(sb, 1)
	write_string(sb, "\"[\")\n")
	for depth in 0 ..< field.type.ptr_depth {
		defer builder_destroy(&builder)
		access_name := fmt.sbprintf(&builder, "%s%d", "ele_", depth)
		log.debug(field.type)
		if depth != field.type.ptr_depth - 1 || field.type.arr_len_fixed == 0 {
			write_indented(sb, "for ", start_ident + depth)
			write_string(sb, access_name)
			write_string(sb, ", i in ")
			if (depth == 0) {
				write_field_access_by_name(sb, name, field, true)
			} else {
				write_string(sb, prev_access_name)
			}

			write_string(sb, " {\n")
		}

		if start_ident + depth != field.type.ptr_depth {
			write_string_builder_start(sb, start_ident + depth + 1)
			write_string(sb, "\"[\")\n")
		}

		if (depth == field.type.ptr_depth - 1) {
			if field.type.arr_len_fixed != 0 {

				builder := strings.builder_make()
				name_with_idx_access := fmt.sbprintf(&builder, "%s[%d]", prev_access_name, 0)
				write_field_value(sb, field, name_with_idx_access, false, depth + 1)
				builder_destroy(&builder)
				write_string_builder_start(sb, depth + 1)
				write_string(sb, "\",\")\n")
				name_with_idx_access = fmt.sbprintf(&builder, "%s[%d]", prev_access_name, 1)
				write_field_value(sb, field, name_with_idx_access, false, depth + 1)

			} else {
				write_indented(sb, "", field.type.ptr_depth)
				write_field_value(sb, field, access_name, false, depth)
				write_indented(sb, "if i != len(", start_ident + depth + 1)
				write_string(sb, prev_access_name)
				write_string(sb, ") - 1 {\n")
				write_string_builder_start(sb, start_ident + depth + 2)
				write_string(sb, "\",\")\n")
				write_indented(sb, "}\n", start_ident + depth + 1)
				write_indented(sb, "}\n", start_ident + depth)
			}
		}

		append(&list_of_prev_names, clone(access_name))
		prev_access_name = clone(access_name)
	}

	for i := field.type.ptr_depth - start_ident; i >= 0; i -= 1 {
		if start_ident + i != field.type.ptr_depth {
			write_string_builder_start(sb, start_ident + i + 1)
			write_string(sb, "\"]\")\n")
			write_indented(sb, "if i != len(", start_ident + i + 1)
			write_string(sb, list_of_prev_names[i])

			write_string(sb, ") - 1 {\n")
			write_string_builder_start(sb, start_ident + i + 2)
			write_string(sb, "\",\")\n")
			write_indented(sb, "}\n", start_ident + i + 1)
			write_indented(sb, "}\n", start_ident + i)
		}
	}


	write_string_builder_start(sb, 1)
	write_string(sb, "\"]\")\n")
}

generate_file_header :: proc(file_name: string, pkg: string, settings: []Gen_Settings) -> string {
	using strings
	sb := builder_make()
	write_string(&sb, "package ")
	write_string(&sb, pkg)
	write_string(&sb, "\n\n")
	write_string(&sb, "// This file is auto generated through json-odin\n")
	write_string(&sb, "// For more information, visit: https://github.com/FreerGit/json-odin\n\n")
	write_string(&sb, "import \"core:strings\"\n\n")
	return to_string(sb)
}

generate_serialization_procs :: proc(file_name: string, pkg: string, settings: []Gen_Settings) -> string {
	using strings
	sb := builder_make()
	for setting in settings {
		write_string(&sb, to_lower(setting.name))
		write_string(&sb, "_to_json :: proc(")
		write_string(&sb, to_lower(setting.name))
		write_string(&sb, ": ")
		if setting.type == .Struct {
			write_string(&sb, "^")
		}
		write_string(&sb, setting.name)
		write_string(&sb, ", sb: ^strings.Builder) #no_bounds_check {\n")
		write_indented(&sb, "using strings\n", 1)
		if setting.type == .Enum {
			write_indented(&sb, "switch ", 1)
			write_string(&sb, to_lower(setting.name))
			write_string(&sb, " {\n")
		}
		for &field, i in setting.fields {
			switch setting.type {
			case .Enum:
				write_indented(&sb, "case .", 1)
				write_string(&sb, field.name)
				write_string(&sb, ":\n	")
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\"\\\"")
				write_string(&sb, field.lowercase ? to_lower(field.name) : field.name)
				write_string(&sb, "\\\"\"")
			case .Struct:
				write_string_builder_start(&sb, 1)
				if i == 0 {
					write_string(&sb, "\"{\\\"")
				} else {
					write_string(&sb, "\",\\\"")
				}
				write_string(&sb, field.name)
				write_string(&sb, "\\\":\"")
				write_string(&sb, ")\n")
			}

			if field.type.is_array {
				write_for_loops(&sb, setting.name, field, 1)
			} else {
				if setting.type == Odin_Type.Enum {
					field.type.is_enum = true
				}
				write_field_value(&sb, field, setting.name, true, 1)
			}
		}
		switch setting.type {
		case .Enum:
			write_indented(&sb, "}", 1)
		case .Struct:
			write_string_builder_start(&sb, 1)
			write_string(&sb, "\"}\")")
		}

		write_string(&sb, "\n}\n\n")
	}

	return strings.to_string(sb)
}


generate_deserialization_procs :: proc(file_name: string, pkg: string, settings: []Gen_Settings) -> string {
	using strings
	sb := builder_make()
	for setting in settings {
		write_string(&sb, to_lower(setting.name))
		write_string(&sb, "_from_json :: proc(")
		write_string(&sb, to_lower(setting.name))
		write_string(&sb, ": ")
		if setting.type == .Struct {
			write_string(&sb, "^")
		}
		write_string(&sb, setting.name)
		write_string(&sb, ", sb: ^strings.Builder) #no_bounds_check {\n")
		write_indented(&sb, "using strings\n", 1)
		if setting.type == .Enum {
			write_indented(&sb, "switch ", 1)
			write_string(&sb, to_lower(setting.name))
			write_string(&sb, " {\n")
		}
		for &field, i in setting.fields {
			switch setting.type {
			case .Enum:
				write_indented(&sb, "case .", 1)
				write_string(&sb, field.name)
				write_string(&sb, ":\n	")
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\"\\\"")
				write_string(&sb, field.lowercase ? to_lower(field.name) : field.name)
				write_string(&sb, "\\\"\"")
			case .Struct:
			// write_string_builder_start(&sb, 1)
			// if i == 0 {
			// 	write_string(&sb, "\"{\\\"")
			// } else {
			// 	write_string(&sb, "\",\\\"")
			// }
			// write_string(&sb, field.name)
			// write_string(&sb, "\\\":\"")
			// write_string(&sb, ")\n")
			}

			if field.type.is_array {
				// write_for_loops(&sb, setting.name, field, 1)
			} else {
				if setting.type == Odin_Type.Enum {
					field.type.is_enum = true
				}
				// write_field_value(&sb, field, setting.name, true, 1)
			}
		}
		switch setting.type {
		case .Enum:
			write_indented(&sb, "}", 1)
		case .Struct:
			write_string_builder_start(&sb, 1)
			write_string(&sb, "\"}\")")
		}

		write_string(&sb, "\n}\n\n")
	}

	return strings.to_string(sb)

}
