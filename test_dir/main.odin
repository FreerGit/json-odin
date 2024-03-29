package test_dir

import "core:encoding/json"
import "core:fmt"
import "core:time"


main :: proc() {
	license := License{false, "Alabama", 55, 99, 15999999, 151515151515151, -5, -15, -999999999999, {"car", "motorcycle"}, {1,2,3}, {"hej"}}
	_ = license_to_json(&license)
	_ = license_to_json(&license)

	begin := time.tick_now()
	str := license_to_json(&license)
	end := time.tick_now()

	_, _ = json.marshal(license, {spec = .JSON})


	begin_std := time.tick_now()
	s, err := json.marshal(license, {spec = .JSON})
	end_std := time.tick_now()


	fmt.println(str, time.duration_nanoseconds(time.tick_diff(begin, end)))
	fmt.println(string(s), time.duration_nanoseconds(time.tick_diff(begin_std, end_std)))
}
