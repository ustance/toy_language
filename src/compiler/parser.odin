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
	node: Node, //typeof Node
	value: Node_Value,

	pos: int,
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

	build_node = get_node({
		.BLOCK,
		temp_nodes,
		0
	});

	return build_node, false;
}

create_node :: proc(node: Node, $T: typeid) -> ^T {
	new_node := new(T);

	new_node.node = node;
	
	return new_node;
}

get_node :: proc(node: INode) -> ^INode{
	new_node := new(INode);

	new_node.node = node.node;
	new_node.pos = node.pos;
	new_node.value = node.value;

	return new_node;
}

peek_next :: proc(tokens: ^[dynamic]IToken) -> ^IToken {
	if build_pos >= build_len {
		return nil;
	} 

	return &tokens[build_pos+1];
}

build_stat :: proc(tokens: ^[dynamic]IToken) -> bool {
	tk := &tokens[build_pos];
	build_pos += 1;
	tkn: ^IToken = nil;
	#partial switch tk.token {
		case .VAR: {
			next_tkn := peek_next(tokens);
			if next_tkn == nil {
				fmt.println("EOF");
				return true;
			}
			if next_tkn.token == .SEMICOLON {
				if build_expr(tokens, 0) {
					return true;
				}

				ident := build_node;

				build_node = get_node({
					.VAR_EMPTY,
					ident,
					tk.pos,
				});
				build_pos += 1;
			} else {
				if build_stat(tokens) {
					return true;
				}

				stat := build_node;

				if stat.node == .SET {
					build_node = get_node({
						.VAR,
						stat.value,
						tk.pos,
					});
				} else {
					fmt.println("Expected a set statement");	
					return true;
				}
			}
		}
		case .RET: {
			if build_expr(tokens, 0) {
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

				if build_stat(tokens) do return true;
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
			if build_expr(tokens, 1) do return true;

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
									if build_expr(tokens, 0) {
										return true;
									}

									if tokens[build_pos].token != .SEMICOLON {
										fmt.println("missing semicolon after set");
										return true;
									} else {
										build_pos += 1;
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
			if build_expr(tokens, 0) do return true;
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
								fmt.println("Expected , ) or something");
							}
						}
					}

					if !closed {
						fmt.println("unclosed ()");
						return true;
					}

					if tokens[build_pos].token != .SEMICOLON {
						fmt.println("missing semicolon after function call");
						return true;
					} else {
						build_pos += 1;
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
				if build_ops(tokens, tk) do return true;
			}
		}
	}

	return false;
}
