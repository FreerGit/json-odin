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

write_given_builder_start :: proc(sb: ^strings.Builder, builder_t: string, field_name: string, ident: int) {
	using strings
	write_indented(sb, "write_", ident)
	write_string(sb, builder_t)
	write_string(sb, "(sb, ")
}

write_field_access :: proc(sb: ^strings.Builder, type_name: string, field: Odin_Field) {
	using strings
	if field.type.is_array {
		write_string(sb, "ele")
	} else {
		write_field_access_by_name(sb, type_name, field)
	}
}

write_field_access_by_name :: proc(sb: ^strings.Builder, type_name: string, field: Odin_Field) {
	using strings
	write_string(sb, to_lower(type_name))
	write_string(sb, ".")
	write_string(sb, field.name)
}

write_field_value :: proc(sb: ^strings.Builder, field: Odin_Field, type_name: string) {
	log.debug(field)
	using strings
	switch field.type.kind {
	case "string":
		if !field.type.is_enum {
			write_given_builder_start(sb, "quoted_string", type_name, 1)
			write_field_access(sb, type_name, field)
		}
	case "cstring":
		write_given_builder_start(sb, "quoted_string", type_name, 1)
		write_string(sb, "string(")
		write_field_access(sb, type_name, field)
		write_string(sb, ")")
	case "rune":
		if field.type.is_array {
			write_string_builder_start(sb, 1)
			write_string(sb, "ele")
		} else {
			write_string_builder_start(sb, 1)
			write_string(sb, "\"\\\"\")\n")
			write_given_builder_start(sb, "rune", type_name, 1)
			write_field_access_by_name(sb, type_name, field)
			write_string(sb, ")\n")
			write_string_builder_start(sb, 1)
			write_string(sb, "\"\\\"\"")
		}
	case "bool":
		write_string_builder_start(sb, 1)
		write_field_access(sb, type_name, field)
		write_string(sb, " ? \"true\" : \"false\"")
	case "uint", "u64", "u32", "u16", "u8":
		write_given_builder_start(sb, "u64", type_name, 1)
		write_string(sb, "u64(")
		write_field_access(sb, type_name, field)
		write_string(sb, ")")
	case "int", "i64", "i32", "i16", "i8":
		write_given_builder_start(sb, "i64", type_name, 1)
		write_string(sb, "i64(")
		write_field_access(sb, type_name, field)
		write_string(sb, ")")
	case "f64", "f32", "f16":
		write_given_builder_start(sb, "f64", type_name, 1)
		write_string(sb, "f64(")
		write_field_access(sb, type_name, field)
		write_string(sb, "), 'f'")
	case:
		log.warn(field)
		log.warn("Unknown type:", field.type, "<- might be recursive, otherwise unsupported.")
		write_indented(sb, to_lower(field.type.kind), 1)
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

generate_marshal_procs :: proc(file_name: string, pkg: string, settings: []Marshal_Settings) -> string {
	using strings
	sb := builder_make()
	write_string(&sb, "package ")
	write_string(&sb, pkg)
	write_string(&sb, "\n\n")
	write_string(&sb, "// This file is auto generated through json-odin\n")
	write_string(&sb, "// For more information, visit: https://github.com/FreerGit/json-odin\n\n")
	write_string(&sb, "import \"core:strings\"\n\n")
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
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\"[\")\n")
				write_indented(&sb, "for ele, i in &", 1)
				write_field_access_by_name(&sb, setting.name, field)
				write_string(&sb, " {\n")
				write_indented(&sb, "", 1)
				write_field_value(&sb, field, setting.name)

				write_indented(&sb, "if i != len(", 2)
				write_field_access_by_name(&sb, setting.name, field)
				write_string(&sb, ")-1 {\n		")
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\",\")\n")
				write_indented(&sb, "}\n", 2)

				write_indented(&sb, "}\n", 1)
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\"]\")\n")
			} else {
				log.warn(setting.type, "now")
				if setting.type == Odin_Type.Enum {
					field.type.is_enum = true
				}
				write_field_value(&sb, field, setting.name)
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
