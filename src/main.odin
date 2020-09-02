package main;

import "core:fmt"

import "core:strings"
import "core:os"
import "core:unicode"
import "core:unicode/utf8"
import "core:strconv"

Node :: enum {
	NUMBER,
	IDENT,
	UNOP,
	BINOP,

	STR,
	CALL,
	BLOCK,

	RET,
	DISCARD,
	SET,
}

Stack_Value :: union {
	f32,
	bool,
	string,
}

Node_Value :: union {
	f32,
	string,
	int,
	^INode,
	[dynamic]^INode,
	Node_Call,
	[2]^INode,
	Node_Unop,
	Node_Op,
}

Node_Unop :: struct {
	op: Unop,
	node: ^INode,
}

Node_Op :: struct {
	op: Op,
	node: ^INode,
	node2: ^INode,
}

Node_Call :: struct {
	name: string,
	args: [dynamic]^INode,
}

INode :: struct {
	node: Node,
	value: Node_Value,

	pos: int,
}

Token :: enum {
	IDENT, //name_test
	OP, //+ - * / > >= < <=
	NUMBER,
	STR,
	UNOP, 

	FN,
	RET,
	VAR,

	CB_OPEN, //{
	CB_CLOSE, //}

	PAR_OPEN, //(
	PAR_CLOSE, //)

	COLON, // :
	SEMICOLON, // ;
	COMMA, //,

	EOF,
}

Token_Value :: union {
	string,
	f32,
	Op,
}

Unop :: enum {
	NEG,
}

Op :: enum {
	SET = -1, // =
	MUL = 0x01, // *
	FDIV = 0x02, // /
	ADD = 0x10, // +
	SUB = 0x11, // -

	EQ = 0x40, // == 
	NE = 0x41, // !=
	LT = 0x42, // <
	LE = 0x43, // <=
	GT = 0x44, // >
	GE = 0x45, // >=

	MAXP = 0x50,
}

IToken :: struct {
	token: Token,
	value: Token_Value, 

	pos: int,
}

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
	pos: int,
}

tokens: [dynamic]IToken;

pack_token :: proc(t: IToken) {
	if t.value != nil { 
		fmt.println(t.token, " with ", t.value, " at ", t.pos);
	} else {
		fmt.println(t.token, " at ", t.pos);
	}

	append(&tokens, t);
}

build_pos: int = 0;
build_len: int = 0;
build_node: ^INode;

nodes: [dynamic] ^INode = make([dynamic] ^INode);

build_tokens :: proc() -> bool {
	build_pos = 0;
	build_len = len(tokens) - 1;

	temp_nodes := make([dynamic] ^INode);
	found := 0;

	for build_pos < build_len {
		if build_stat() {
			return true;
		}
		append(&temp_nodes, build_node);
	}

	build_node = get_node({
		.BLOCK,
		temp_nodes,
		0
	});

	fmt.println(temp_nodes);
	
	return false;
}

get_node :: proc(node: INode) -> ^INode{
	new_node := new(INode);

	new_node.node = node.node;
	new_node.pos = node.pos;
	new_node.value = node.value;

	return new_node;
}

build_expr :: proc(flags: int) -> bool {
	tk: ^IToken = &tokens[build_pos];
	build_pos += 1;

	#partial switch tk.token {
		case .NUMBER: {
			build_node = get_node({
				.NUMBER,
				tk.value.(f32),
				tk.pos
			});
		}
		case .STR: {
			build_node = get_node({
				.STR,
				tk.value.(string),
				tk.pos
			});
		}
		case .PAR_OPEN: {
			if build_expr(0) do return true;
			tk = &tokens[build_pos];
			build_pos += 1;

			if tk.token != .PAR_CLOSE {
				fmt.println("expected )");
				return true;
			}
		}
		case .OP: {
			op_value := tk.value.(Op);
			#partial switch op_value {
				case .ADD: {
					if build_expr(1) do return true;
				}
				case .SUB: {
					if build_expr(1) do return true;
					build_node = get_node({
						.UNOP,
						Node_Unop {.NEG, build_node},
						tk.pos,
					});
				}
				case:
					fmt.println("Not implemented OP");
					return true;
			}
		}
		case .IDENT: {
			tkn := &tokens[build_pos];

			#partial switch tkn.token {
				case .PAR_OPEN: {
					build_pos += 1;

					args := make([dynamic]^INode);
					argc := 0;
					closed := false;

					loop: for build_pos < build_len {
						tkn = &tokens[build_pos];

						#partial switch tkn.token {
							case .PAR_CLOSE: {
								build_pos += 1;
								closed = true;
								break loop;
							}
						}

						if build_expr(0) do return true;
						append(&args, build_node);
						argc += 1;

						tkn = &tokens[build_pos];
						#partial switch tkn.token {
							case .COMMA: {
								build_pos += 1;
							}
							case .PAR_CLOSE: {}
							case: {
								fmt.println("Expected , ) or something");
							}
						}
					}

					if !closed {
						fmt.println("unclosed ()");
						return true;
					}

					build_node = get_node({
						.CALL,
						Node_Call {tk.value.(string), args},
						tk.pos
					});
				}
				case: {
					build_node = get_node({
						.IDENT,
						tk.value.(string),
						tk.pos,
					});
				}
			}
		}
	}

	if (flags & 1) == 0 {
		tk = &tokens[build_pos];
		#partial switch tk.token {
			case .OP: {
				build_pos += 1;
				if build_ops(tk) do return true;
			}
		}
	}

	return false;
}

build_ops :: proc(_tk: ^IToken) -> bool {
	temp_nodes := make([dynamic]^INode);	
	append(&temp_nodes, build_node);

	ops := make([dynamic]^IToken);
	append(&ops, _tk);

	tk: ^IToken;

	for true {
		if build_expr(1) do return true;

		append(&temp_nodes, build_node);

		tk = &tokens[build_pos];

		to_break := false;

		#partial switch tk.token {
			case .OP: {
				build_pos += 1;
				append(&ops, tk);
			}
			case: to_break = true;
		}
		if to_break do break;
	}

	n := len(ops);
	pmax := 0x50 >> 4;
	pri := 0;

	for pri < pmax {
		i := 0;
		for i < n {
			tk = ops[i];
			#partial switch tk.token {
				case .OP: {
					op := tk.value.(Op);
					if (int(op) >> 4) != pri {
						i += 1;
						continue;
					}

					temp_nodes[i] = get_node({
						.BINOP,
						Node_Op {op, temp_nodes[i], temp_nodes[i + 1]},
						tk.pos
					});

					unordered_remove(&temp_nodes, i+1);
					unordered_remove(&ops, i);
					n -= 1;
					i -= 1;
				}
				case: {}
			}
			i += 1;
		}
		pri += 1;
	}

	build_node = temp_nodes[0];
	return false;
}

build_stat :: proc() -> bool {
	tk := &tokens[build_pos];
	fmt.println(tk);
	build_pos += 1;
	tkn: ^IToken = nil;
	#partial switch tk.token {
		case .RET: {
			if build_expr(0) {
				return true;
			}

			build_node = get_node({
				.RET,
				build_node,
				tk.pos,
			});
		}
		case .CB_OPEN: {
			temp_nodes := make([dynamic]^INode);
			found := 0;
			closed := false;

			for build_pos < build_len {
				tkn = &tokens[build_pos];

				#partial switch tkn.token {
					case .CB_CLOSE: {
						build_pos += 1;
						closed = true;
					}
				}

				if build_stat() do return true;
				append(&temp_nodes, build_node);
				found += 1;
			}

			if !closed do fmt.println("Unclosed {} handle pleawse");

			build_node = get_node({
				.BLOCK,
				temp_nodes,
				tk.pos
			});
		}
		case: {
			build_pos -= 1;
			if build_expr(1) do return true;

			expr := build_node;

			#partial switch build_node.node {
				case .CALL: {
					build_node = get_node({
						.DISCARD,
						build_node,
						tk.pos
					});
				}
				case: {
					tkn = &tokens[build_pos];

					#partial switch tkn.token {
						case .OP: {
							op_value := tkn.value.(Op);
							#partial switch op_value {
								case .SET: {
									build_pos += 1;
									if build_expr(0) {
										return true;
									}

									anodes := make([dynamic]^INode);
									append(&anodes, expr);
									append(&anodes, build_node);

									build_node = get_node({
										.SET,
										anodes,
										tk.pos
									});
								}
							}
						}
						case: {
							return true;
						}
					}
				}
			}
		}
	}

	return false;
}

actions: [dynamic]^IAction;

get_action :: proc(act: IAction) -> ^IAction {
	a := new(IAction);

	a.action = act.action;
	a.value = act.value;
	a.pos = act.pos;

	return a;
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

execute :: proc() {
	length := len(actions);	
	pos := 0;
	stack := make([dynamic]Stack_Value);


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
				fmt.println("Set ", name, " = ", pop(&stack));
			case .CALL:
				name := q.value.(Action_Call).name;
				count := q.value.(Action_Call).count;

				i := count;

				args := make([dynamic]Stack_Value);

				i -= 1;
				for i >= 0 {
					append(&args, pop(&stack));
					i -= 1;
				}

				fmt.println("Calling function ", name, " with ", args);

				free(&args);

			case .IDENT:
				name := q.value.(string);
				fmt.println("Trying to get a ident ", name);

				new_value: Stack_Value;
				new_value = false;
				append(&stack, new_value);

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

compile :: proc() -> bool{
	actions = make([dynamic]^IAction);

	fmt.println("\n");
	fmt.println(build_node.value);
	fmt.println("\n");
	if compile_expr(build_node) {
		return true;
	}


	return false;
}

compile_expr :: proc(q: ^INode) -> bool {
	#partial switch q.node {
		case .NUMBER:
			append(&actions, get_action({
				.NUMBER,
				q.value.(f32),
				q.pos
			}));
		case .IDENT:
			append(&actions, get_action({
				.IDENT,
				q.value.(string),
				q.pos
			}));
		case .SET:
			n1 := q.value.([dynamic]^INode)[0];
			n2 := q.value.([dynamic]^INode)[1];

			if compile_expr(n2) {
				return true;
			}
			_expr := n1;
			#partial switch _expr.node {
				case .IDENT: {
					n := _expr.value.(string);

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
			
			if compile_expr(a) do return true;
			if compile_expr(b) do return true;

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
				if compile_expr(args[i]) do return true;
			}
			append(&actions, get_action({
				.CALL,
				Action_Call{name, argc},
				q.pos
			}));
		case .BLOCK: 
			block_nodes := q.value.([dynamic]^INode);
			for i in block_nodes {
				if compile_expr(i) do return true;
			}
		case .RET:
			n := q.value.(^INode);
			if compile_expr(n) do return true;
			append(&actions, get_action({
				.RET,
				nil,
				q.pos
			}));
		case .DISCARD: 
			n := q.value.(^INode);
			if compile_expr(n) do return true;
			append(&actions, get_action({
				.DISCARD,
				nil,
				q.pos
			}));
			
	}
	return false;
}

main :: proc() {

	source_builder := strings.make_builder();

	source_data, ok := os.read_entire_file("example/basic.ct");

	if !ok {
		fmt.println("\nError reading a file!\n");
		return;
	}

	strings.write_bytes(&source_builder, source_data);

	source_string := strings.to_string(source_builder);

	fmt.println("\nbasic.ct:\n");
	fmt.println(source_string);

	tokens = make([dynamic]IToken);

	index := 0;
	for index < len(source_string) {
		start := index;
		r := utf8.rune_at_pos(source_string, index);

		index += 1;

		switch r {
			case ' ', '\r', '\n': {

			}
			case '+':
				pack_token(IToken {
					.OP,
					.ADD,
					start
				});
			case '-':
				pack_token(IToken {
					.OP,
					.SUB,
					start
				});
			case '*':
				pack_token(IToken {
					.OP,
					.MUL,
					start
				});
			case '!': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.NE,
						start
					});
				}
			case '>': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.GE,
						start
					});
				} else {
					pack_token(IToken {
						.OP,
						.GT,
						start
					});
				}
			case '<': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.LE,
						start
					});
				} else {
					pack_token(IToken {
						.OP,
						.LT,
						start
					});
				}
			case '=':
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.EQ,
						start
					});
				} else {
					pack_token(IToken {
						.OP,
						.SET,
						start
					});
				}

			case '/': {
				r = utf8.rune_at_pos(source_string, index);
				if r == '/' {
					for index < len(source_string) {
						r = utf8.rune_at_pos(source_string, index);
						if r == '\r' || r == '\n' do break;
						index += 1;
					}
				} else {
					pack_token(IToken {
						.OP,
						.FDIV,
						start
					});
				}
			}
			case '(': {
				pack_token(IToken {
					.PAR_OPEN,
					nil,
					start
				});
			}
			case ')': {
				pack_token(IToken {
					.PAR_CLOSE,
					nil,
					start
				});
			}
			case '{': {
				pack_token(IToken {
					.CB_OPEN,
					nil,
					start
				});
			}
			case '}': {
				pack_token(IToken {
					.CB_CLOSE,
					nil,
					start
				});
			}
			case ',': {
				pack_token(IToken {
					.COMMA,
					nil,
					start
				});
			}
			case ':': {
				pack_token(IToken {
					.COLON,
					nil,
					start
				});
			}
			case '\"': {
				for index < len(source_string) {
					new_r := utf8.rune_at_pos(source_string, index);

					if new_r == r {
						break;
					} 

					index += 1;
				}

				if index < len(source_string) {
					index += 1;
					pack_token(IToken {
						.STR,
						source_string[start+1:index-1],
						start
					});
				} else {
					fmt.println("Unclosed string.");
				}
			}
			case ';': {
				pack_token(IToken {
					.SEMICOLON,
					nil,
					start
				});
			}

			case: {
				if unicode.is_digit(r) {
					pre_dot := true;

					for index < len(source_string) {
						r = utf8.rune_at_pos(source_string, index);

						if r == '.' {
							if !pre_dot do break;

							pre_dot = false;
							index += 1;
						} else if unicode.is_digit(r) {
							index += 1;
						} else {
							break;
						}
					}
					float_number, ok := strconv.parse_f32(source_string[start:index]);
					if ok {
						pack_token(IToken {
							.NUMBER,
							float_number,
							start
						});
					}
				} else if r == '_'  || ((i32(r) >= i32('a') && i32(r) <= i32('z')) || (i32(r) >= i32('A') && i32(r) <= i32('Z'))){
					for index <= len(source_string) {
						r = utf8.rune_at_pos(source_string, index);

						if r == '_'  || ((i32(r) >= i32('0') && i32(r) <= i32('9')) || (i32(r) >= i32('a') && i32(r) <= i32('z')) || (i32(r) >= i32('A') && i32(r) <= i32('Z'))){
							index += 1;
						} else {
							break;
						}
					}

					word := source_string[start:index];
					switch word {
						case "fn": {
							pack_token(IToken {
								.FN,
								nil,
								start
							});
						}
						case "var": {
							pack_token(IToken {
								.VAR,
								nil,
								start
							});
						}
						case "return": {
							pack_token(IToken {
								.RET,
								nil,
								start
							});
						}
						case: {
							pack_token(IToken {
								.IDENT,
								word,
								start
							});
						}
					}
				} 			
			}
		}
	}

	pack_token(IToken {
		.EOF,
		nil,
		len(source_string) + 1
	});

	err := build_tokens();

	compile();

	execute();

}
