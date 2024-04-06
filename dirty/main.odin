package dirty

import "core:bytes"
import "core:fmt"
import "core:intrinsics"
import "core:simd"
import "core:strconv"
import "core:strings"


@(json)
Floats :: struct {
	_f64: f64,
	_f32: f32,
	_f16: f16,
}


main :: proc() {
	str := `{"_f64":43434.555,"_f32":123.4567,"_f16":5.678}`
	fs := Floats{}
	ok := floats_from_json(&fs, str)
	fmt.println(fs, ok)
}
