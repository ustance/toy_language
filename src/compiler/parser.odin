package compiler;

import "core:fmt";

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
	VAR,
	VAR_EMPTY,
}
Unop :: enum {
	NEG,
}

Node_Value :: union {
	Node_Number,
	Node_Str,
	Node_Ident,
	Node_Unop,
	Node_Op,
	Node_Call,
	Node_Block,
	Node_Set,
	Node_Var,
	Node_Var_Empty,
	Node_Ret,
	Node_Discard,
}


Node_Discard :: distinct ^INode;
Node_Ret     :: distinct ^INode;
Node_Number  :: distinct f32;
Node_Ident   :: struct {
	name: string,
}
Node_Unop :: struct {
	op: Unop,
	node: ^INode,
}
Node_Op   :: struct {
	op: Op,
	node: ^INode,
	node2: ^INode,
}
Node_Str  :: string;
Node_Call :: struct {
	name: string,
	args: [dynamic]^INode,
}
Node_Block	   :: distinct [dynamic]^INode;
Node_Set       :: distinct [2]^INode;
Node_Var       :: distinct [2]^INode;
Node_Var_Empty :: distinct ^INode;

INode :: struct {
	kind: Node, 
	value: Node_Value,
	pos: Line_Info,
}

build_pos: int = 0;
build_len: int = 0;
build_node: ^INode;

build_tokens :: proc(tokens: ^[dynamic] IToken) -> (^INode, bool) {
	build_pos = 0;
	build_len = len(tokens^) - 1;

	temp_nodes := make([dynamic] ^INode);
	found := 0;

	for build_pos < build_len {
		if build_stat(tokens) {
			return nil, true;
		}
		append(&temp_nodes, build_node);
	}

	block_node: Node_Block;
	block_node = (Node_Block)(temp_nodes);

	build_node = get_node({
		.BLOCK,
		block_node,
		{0,0}
	});

	return build_node, false;
}

get_node :: proc(node: INode) -> ^INode{
	new_node := new(INode);

	new_node.kind = node.kind;
	new_node.pos = node.pos;
	new_node.value = node.value;

	return new_node;
}

peek :: proc(tokens: ^[dynamic]IToken, f: int) -> ^IToken {
	if build_pos+f > build_len {
		return nil;
	}

	return &tokens[build_pos+f];
}

parser_error :: proc(msg: string, pos: Line_Info, args: ..any) -> bool {
	message := fmt.tprint("Parser Error[", pos.line, "]: ", msg);

	fmt.println(message);

	return true;
}

build_stat :: proc(tokens: ^[dynamic]IToken) -> bool {
	tk := &tokens[build_pos];
	build_pos += 1;
	tkn: ^IToken = nil;
	#partial switch tk.token {
		case .VAR: {
			
			next_tkn := peek(tokens, 0);

			#partial switch next_tkn.token {
				case .EOF: {
					return parser_error("unexpected EOF", next_tkn.pos);
				}

				case .IDENT: {
					after_ident := peek(tokens, 1);

					#partial switch after_ident.token {
						case .SEMICOLON: {
							if build_expr(tokens, 0) {
								return true;
							}

							ident: Node_Var_Empty;
							ident = (Node_Var_Empty) (build_node);

							build_node = get_node({
								.VAR_EMPTY,
								ident,
								tk.pos,
							});
							build_pos += 1;
						}
						case .OP: {
							if build_stat(tokens) {
								return true;
							}

							if build_node.kind == .SET {
								stat: Node_Var;
								stat = (Node_Var)(([2]^INode)(build_node.value.(Node_Set)));

								build_node = get_node({
									.VAR,
									stat,
									tk.pos,
								});
							} else {
								return parser_error("Expected a set statement", tkn.pos);
							}
						}
						case: {
							return parser_error("Expected a set statement", tkn.pos);
						}
					}
				}

				case: {
					return parser_error("error in var statement", next_tkn.pos);
				}
			}

		}
		case .RET: {
			if build_expr(tokens, 0) {
				return true;
			}

			ret_node: Node_Ret;
			ret_node = (Node_Ret)(build_node);

			build_node = get_node({
				.RET,
				ret_node,
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

				if build_stat(tokens) do return true;
				append(&temp_nodes, build_node);
				found += 1;
			}

			if !closed do return parser_error("Unclosed {}", tkn.pos);

			block_nodes: Node_Block;
			block_nodes = (Node_Block)(temp_nodes);

			build_node = get_node({
				.BLOCK,
				block_nodes,
				tk.pos
			});
		}
		case: {
			build_pos -= 1;
			if build_expr(tokens, 1) do return true;

			expr := build_node;

			#partial switch build_node.kind {
				case .CALL: {
					discard_node: Node_Discard;
					discard_node = (Node_Discard)(build_node);

					if tokens[build_pos].token != .SEMICOLON {
						return parser_error("Missing semicolon after call", tkn.pos);
					}

					build_pos += 1;

					build_node = get_node({
						.DISCARD,
						discard_node,
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
									if build_expr(tokens, 0) {
										return parser_error("building set expressiong", tkn.pos);
									}

									next_tkn := peek(tokens, 0);
									if next_tkn.token != .SEMICOLON {
										return parser_error("missing ;", next_tkn.pos);
									}

									build_pos += 1;

									anodes: Node_Set = {
										expr,
										build_node
									};

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

build_ops :: proc(tokens: ^[dynamic]IToken, _tk: ^IToken) -> bool {
	temp_nodes := make([dynamic]^INode);	
	append(&temp_nodes, build_node);

	ops := make([dynamic]^IToken);
	append(&ops, _tk);

	tk: ^IToken;

	for true {
		if build_expr(tokens, 1) do return true;

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

build_expr :: proc(tokens: ^[dynamic]IToken, flags: int) -> bool {
	tk: ^IToken = &tokens[build_pos];
	build_pos += 1;

	#partial switch tk.token {
		case .SEMICOLON: {
			parser_error("Unexpected semicolon", tk.pos);
		}
		case .NUMBER: {
			number_node: Node_Number;
			number_node = (Node_Number)(tk.value.(f32));
			build_node = get_node({
				.NUMBER,
				number_node,
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
			if build_expr(tokens, 0) do return true;
			tk = &tokens[build_pos];
			build_pos += 1;

			if tk.token != .PAR_CLOSE {
				return parser_error("expected )", tk.pos);
			}
		}
		case .OP: {
			op_value := tk.value.(Op);
			#partial switch op_value {
				case .ADD: {
					if build_expr(tokens, 1) do return true;
				}
				case .SUB: {
					if build_expr(tokens, 1) do return true;
					build_node = get_node({
						.UNOP,
						Node_Unop {.NEG, build_node},
						tk.pos,
					});
				}
				case:
					return parser_error("Not implemented OP", tk.pos);
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

						if build_expr(tokens, 0) do return true;
						append(&args, build_node);
						argc += 1;

						tkn = &tokens[build_pos];
						#partial switch tkn.token {
							case .COMMA: {
								build_pos += 1;
							}
							case .PAR_CLOSE: {}
							case: {
								return parser_error("Expected , ) or something", tkn.pos);
							}
						}
					}

					if !closed {
						return parser_error("unclosed ()", tkn.pos);
					}

					build_node = get_node({
						.CALL,
						Node_Call {tk.value.(string), args},
						tk.pos
					});
				}
				case: {

					ident_node: Node_Ident;
					ident_node = {
						tk.value.(string)
					};
					build_node = get_node({
						.IDENT,
						ident_node,
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
				if build_ops(tokens, tk) do return true;
			}
		}
	}

	return false;
}
