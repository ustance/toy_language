package compiler;

import "core:fmt"

import "core:strings"
import "core:os"
import "core:unicode"
import "core:unicode/utf8"
import "core:strconv"


Action :: enum {
	NUMBER,
	IDENT,
	UNOP,
	BINOP,
	STR,
	CALL,
	RET,
	DISCARD,
	SET_IDENT,
	VAR_IDENT,
	VAR_EMPTY,
}

Action_Value :: union {
	f32,
	string,
	Op,
	Action_Call,
}

Action_Call :: struct {
	name: string,
	count: int,
}

IAction :: struct {
	action: Action,
	value: Action_Value,
	pos: Line_Info,
}

get_action :: proc(act: IAction) -> ^IAction {
	a := new(IAction);

	a.action = act.action;
	a.value = act.value;
	a.pos = act.pos;

	return a;
}


actions: [dynamic]^IAction;

compile :: proc(build_node: ^INode) -> ([dynamic]^IAction, bool) {
	actions = make([dynamic]^IAction);

	if compile_expr(build_node) {
		return nil, true;
	}

	return actions, false;
}

compile_expr :: proc(q: ^INode) -> bool {
	if q == nil {
		fmt.println("expression is nil");
	}
	#partial switch q.kind {
		case .NUMBER:
			append(&actions, get_action({
				.NUMBER,
				f32(q.value.(Node_Number)),
				q.pos
			}));
		case .IDENT:
			append(&actions, get_action({
				.IDENT,
				q.value.(Node_Ident).name,
				q.pos
			}));
		case .VAR_EMPTY: 
			ident := (^INode)(q.value.(Node_Var_Empty)).value.(Node_Ident);

			append(&actions, get_action({
				.VAR_EMPTY,
				ident.name,
				q.pos
			}));

		case .VAR: 
			nodes_array := ([2]^INode)(q.value.(Node_Var));
			n1 := nodes_array[0];
			n2 := nodes_array[1];

			if compile_expr(n2) {
				return true;
			}
			_expr := n1;
			#partial switch _expr.kind {
				case .IDENT: {
					n := _expr.value.(Node_Ident).name;

					append(&actions, get_action({
						.VAR_IDENT,
						n,
						q.pos
					}));
				}
				case : {
					fmt.println("Expression cannot be set.");
					return true;
				}
			}
		case .SET:
			nodes_array := ([2]^INode)(q.value.(Node_Set));
			n1 := nodes_array[0];
			n2 := nodes_array[1];

			if compile_expr(n2) {
				fmt.println("set err");
				return true;
			}
			_expr := n1;
			#partial switch _expr.kind {
				case .IDENT: {
					n := _expr.value.(Node_Ident).name;

					append(&actions, get_action({
						.SET_IDENT,
						n,
						q.pos
					}));
				}
				case : {
					fmt.println("Expression cannot be set.");
					return true;
				}
			}
		case .UNOP: 
			op := q.value.(Node_Unop).op;
			n := q.value.(Node_Unop).node;

			if compile_expr(n) do return true;

			append(&actions, get_action({
				.UNOP,
				nil,
				q.pos
			}));
		case .BINOP:
			op := q.value.(Node_Op).op;
			a := q.value.(Node_Op).node;
			b := q.value.(Node_Op).node2;
			
			if compile_expr(a) {
				fmt.println("a");
				return true;
			}
			if compile_expr(b) { 
				fmt.println("b");
				return true;
			}

			append(&actions, get_action({
				.BINOP,
				op,
				q.pos
			}));
		case .STR: 
			append(&actions, get_action({
				.STR,
				q.value.(string),
				q.pos
			}));
		case .CALL: 
			name := q.value.(Node_Call).name;
			args := q.value.(Node_Call).args;
			argc := len(args);
			for i in 0..<argc {
				if compile_expr(args[i]) {
					fmt.println("error while compiling call arg");
					return true;
				}
			}
			append(&actions, get_action({
				.CALL,
				Action_Call{name, argc},
				q.pos
			}));
		case .BLOCK: 
			block_nodes := ([dynamic]^INode)(q.value.(Node_Block));
			for i in block_nodes {
				if compile_expr(i) do return true;
			}
		case .RET:
			n := (^INode)(q.value.(Node_Ret));
			if compile_expr(n) { 
				fmt.println("w");
				return true;
			}
			append(&actions, get_action({
				.RET,
				nil,
				q.pos
			}));
		case .DISCARD: 
			n := (^INode)(q.value.(Node_Discard));
			if compile_expr(n) { 
				fmt.println("discard");
				return true;
			}
			append(&actions, get_action({
				.DISCARD,
				nil,
				q.pos
			}));
			
	}
	return false;
}
