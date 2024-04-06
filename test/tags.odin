//+private
package json_test

import "core:strings"
import "core:testing"

@(json = {deserialization = false}) // Only generate l_to_json (skip l_from_json)
L :: struct {
	the_enum: Enum_with_lowercase,
}

// Then enum variants should be lowercase, ThisShouldBeLowercase (de)serialize as thisshouldbelowercase.
@(json = {lowercase = true, deserialization = false})
Enum_with_lowercase :: enum {
	ThisShouldBeLowercase,
	This_Can_Also_Be_Lowercase,
}


@(test)
lowercase_test :: proc(t: ^testing.T) {
	j1 := `{"the_enum":"thisshouldbelowercase"}`
	j2 := `{"the_enum":"this_can_also_be_lowercase"}`
	sb := strings.builder_make()
	lowercase1 := L {
		the_enum = .ThisShouldBeLowercase,
	}
	lowercase2 := L {
		the_enum = .This_Can_Also_Be_Lowercase,
	}
	l_to_json(&lowercase1, &sb)
	testing.expect_value(t, strings.to_string(sb), j1)
	strings.builder_destroy(&sb)
	l_to_json(&lowercase2, &sb)
	testing.expect_value(t, strings.to_string(sb), j2)
}
