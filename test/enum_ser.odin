//+private
package json_test

// import "core:strings"
// import "core:testing"

// @(json)
// A :: enum {
// 	Motorcycle,
// }
// @(json)
// B :: struct {
// 	a_enum: A,
// }

// @(test)
// simple_enum :: proc(t: ^testing.T) {
// 	json := `{"a_enum":"Motorcycle"}`
// 	sb := strings.builder_make()
// 	b := B {
// 		a_enum = .Motorcycle,
// 	}
// 	b_to_json(&b, &sb)

// 	testing.expect_value(t, strings.to_string(sb), json)
// }
