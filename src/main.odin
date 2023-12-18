package parser

import "core:log"
import "core:reflect"
import "core:time"

Obj :: struct {
	num:  int,
	name: string,
	occ:  []string,
}

print_types :: proc(t: $T) {
	log.debug(t)
    // log.debug())
    t1 := time.now()
    strs := reflect.struct_field_names(type_of(t))
    t2 := time.now()
    log.debug(time.duration_nanoseconds(time.diff(t1,t2)))
}

main :: proc() {
	context.logger = log.create_console_logger()

    some_dude := Obj {
        num = 5,
        name = "kalle",
        occ = {"painter", "coder"}
    }

	log.debug("hello")
    print_types(some_dude)

}
