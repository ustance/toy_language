package compiler;

import "core:fmt"

import "core:strings"
import "core:os"
import "core:unicode"
import "core:unicode/utf8"
import "core:strconv"

Interpretor_Value :: struct {
	value: Interpretor_Value_Type,
	type: typeid,
}

Interpretor_Value_Type :: union {
	f32,
	string,
}

Func_Type :: proc(args: ^[dynamic]Interpretor_Value) -> Interpretor_Value;

Interop :: struct {
	variables: map[string] Interpretor_Value,
	funcs: map[string] Func_Type,
	result: Interpretor_Value,
}

interpret :: proc(stmts: ^[dynamic] ^Node) {

	interop: Interop;
	interop.variables = make(map[string] Interpretor_Value);
	interop.funcs = make(map[string] Func_Type);

	interop.funcs["trace"] = proc(args: ^[dynamic]Interpretor_Value) -> Interpretor_Value {
		argc := len(args);
		for i in 0..<argc {
			fmt.print(args[i].value);
			fmt.print(": ", args[i].type);
		}
		fmt.println();
		return {nil, nil};
	};

	fmt.println("---------");
	for stmt in stmts {
		interop.result = interpret_expr(&interop, stmt);
	}
	fmt.println("---------");
}

op_add :: proc(_a: Interpretor_Value, _b: Interpretor_Value) -> Interpretor_Value {
	a := _a.value;
	b := _b.value;
	switch v in a{
		case f32: {
			return {a.(f32) + b.(f32), typeid_of(f32)};
		}
		case string: {
			add_builder := strings.make_builder();

			strings.write_string(&add_builder, a.(string));
			strings.write_string(&add_builder, b.(string));

			result := strings.to_string(add_builder);

			strings.destroy_builder(&add_builder);

			return {result, typeid_of(string)};
		}
	}

	return {nil, nil};
}

interpret_expr :: proc(interop: ^Interop, node: ^Node) -> Interpretor_Value {
	using interop;
	switch v in node.derived {
		case Expr_Op: {
			op := v.op;
			left := interpret_expr(interop, v.left);
			right := interpret_expr(interop, v.right);

			#partial switch op {
				case .ADD: {
					return op_add(left, right);
				}
			}
		}
		case Decl_Var: {
			variables[v.name] = interpret_expr(interop, v.expr);
		}
		case Stmt_Assign: {
			variables[v.name] = interpret_expr(interop, v.expr);
		}
		case Expr_Numb: {
			return {v.value, typeid_of(f32)};
		}
		case Expr_Str: {
			return {v.content, typeid_of(string)};
		}
		case Expr_Ident: {
			return variables[v.name];
		}
		case Expr_Call: {
			args: [dynamic] Interpretor_Value;
			for a in v.args {
				append(&args, interpret_expr(interop, a));
			}
			return_value := funcs[v.name](&args);
			delete(args);
			return return_value;
		}
		case Stmt_Discard: {
			call := v.call;
			interpret_expr(interop, call);
		}
		case: fmt.println(node.derived);
	}

	return {nil, nil};
}
