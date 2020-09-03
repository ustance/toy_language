package vm;

import "../compiler";
import "core:fmt"

import "core:strings"
import "core:os"
import "core:unicode"
import "core:unicode/utf8"
import "core:strconv"

IToken :: compiler.IToken;
Token :: compiler.Token;
Token_Value :: compiler.Token_Value;
Op :: compiler.Op;
Node :: compiler.Node;
Unop :: compiler.Unop;
Node_Value :: compiler.Node_Value;
Node_Unop :: compiler.Node_Unop;
Node_Op :: compiler.Node_Op;
Node_Call :: compiler.Node_Call;
INode :: compiler.INode;
Action :: compiler.Action;
Action_Value :: compiler.Action_Value;
Action_Call :: compiler.Action_Call;
IAction :: compiler.IAction;

basic_variables: map[string] Stack_Value;
basic_funcs: map[string] proc();

stack := make([dynamic]Stack_Value);

Stack_Value :: union {
	f32,
	bool,
	string,
}


binop_types :: proc(a: Stack_Value, b: Stack_Value, op: Op) -> Stack_Value {
	#partial switch f1 in a {
		case f32: {
			#partial switch f2 in b {
				case f32: {
					#partial switch op {
						case .ADD: return f1 + f2;
						case .SUB: return f1 - f2;
						case .MUL: return f1 * f2;
						case .FDIV: return f1 / f2;
						case .EQ:  return f1 == f2;
						case .NE: return f1 != f2;
						case .LT: return f1 < f2;
						case .LE: return f1 <= f2;
						case .GT: return f1 > f2;
						case .GE: return f1 >= f2;
					}
				}
			}
		}
	}

	return 0;
}

execute :: proc(actions: [dynamic]^IAction) {
	length := len(actions);	
	pos := 0;
	basic_variables := make(map[string]Stack_Value);
	basic_funcs := make(map[string] proc(argc: int));

	basic_funcs["print"] = proc(argc: int) {
		args := make([dynamic]Stack_Value);
		i := argc;
		i -= 1;
		for i >= 0 {
			append(&args, pop(&stack));
			i -= 1;
		}

		for arg in args {
			fmt.println(arg);
		}

		delete(args);
	};


	for pos < length {
		q := actions[pos];
		pos += 1;

		switch q.action {
			case .NUMBER: 
				append(&stack, q.value.(f32));
			case .UNOP: 
				poped_value := pop(&stack).(f32);
				append(&stack, -poped_value);
			case .BINOP:
				b := pop(&stack);
				a := pop(&stack);
				op := q.value.(Op);

				new_value := binop_types(a, b, op);

				append(&stack, new_value);
			case .SET_IDENT:
				name := q.value.(string);
				value := pop(&stack);
				//fmt.println("Set ", name, " = ", pop(&stack));
				basic_variables[name] = value;
			case .CALL:
				name := q.value.(Action_Call).name;
				count := q.value.(Action_Call).count;

				/* i := count; */

				/* args := make([dynamic]Stack_Value); */

				/* i -= 1; */
				/* for i >= 0 { */
				/* 	append(&args, pop(&stack)); */
				/* 	i -= 1; */
				/* } */

				/* fmt.println("Calling function ", name, " with ", args); */
				basic_funcs[name](count);

			case .IDENT:
				name := q.value.(string);

				new_value: Stack_Value;
				new_value = false;
				if basic_variables[name] != nil {
					append(&stack, basic_variables[name]);
				} else {
					append(&stack, new_value);
				}

			case .STR:
				str := q.value.(string);
				append(&stack, str);
			case .RET:
				pos = length;
			case .DISCARD:
				pop(&stack);
		}
	}
	
}

