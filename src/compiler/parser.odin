package compiler;

import "core:fmt";

Node :: struct {
	pos: Line_Info,
	derived: any,
}

Expr :: struct {
	using expr_base: Node,
	type: typeid,
}

Stmt :: struct {
	using expr_base: Node,
}

Decl :: struct {
	using decl_base: Stmt,
}

Stmt_Return :: struct {
	using node: Stmt,
	result: ^Expr,
}

Expr_Op :: struct {
	using base: Expr,
	op: Op,
	left: ^Expr,
	right: ^Expr,
}

Expr_Call :: struct {
	using base: Expr,
	name: string,
	args: [dynamic]^Expr,
}

Stmt_Discard :: struct {
	using base: Stmt,
	call: ^Expr_Call,
}

Stmt_Assign :: struct {
	using base: Stmt,
	name: string,
	expr: ^Expr,
}

Stmt_Block :: struct {
	using base: Stmt,
	stmts: [dynamic]^Stmt,
}

Decl_Var :: struct {
	using base: Decl,
	name: string,
	type: typeid,
	expr: ^Expr,
}

Decl_Fn :: struct {
	using base: Decl,
	name: string,
	type: typeid,
	block: ^Stmt_Block,
}

Expr_Ident :: struct {
	using node: Expr,
	name: string,
}

Expr_Str :: struct {
	using node: Expr,
	content: string,
}

Expr_Numb :: struct {
	using node: Expr,
	value: f32,
}

DEBUG_PARSER :: false;
build_pos: int = 0;
build_len: int = 0;

curr_token: IToken;
prev_token: IToken;
file_statements: [dynamic] ^Node = make([dynamic] ^Node);

expr_level: int = 0; // 0 is file declaration level

expect_token :: proc(tokens: ^[dynamic] IToken, kind: Token) -> (IToken, bool){
	prev := curr_token;
	if prev.token != kind {
		e := kind;
		g := prev.token;

		message := fmt.tprint("Expected", e, "got", g);
		fmt.println(message);

		return prev, true;
	}
	advance_token(tokens);
	return prev, false;
}


advance_token :: proc(tokens: ^[dynamic] IToken) -> IToken {
	if curr_token.token != .EOF {
		prev_token = curr_token;

		build_pos += 1;
		curr_token = tokens[build_pos];

		if DEBUG_PARSER {
			fmt.println(prev_token.token, " -> ", curr_token.token);
		}
	}

	return curr_token;
}


parse_file :: proc(tokens: ^[dynamic] IToken) -> bool {
	curr_token = tokens[0];
	prev_token = tokens[0];

	build_pos = 0;
	build_len = len(tokens^) - 1;

	for curr_token.token != .EOF {
		stmt := parse_stmt(tokens);

		if stmt != nil {
			append(&file_statements, stmt);
		}
	}

	return true;
}


new_ast :: proc($T: typeid, pos: Line_Info) -> ^T {
	n := new(T);
	n.pos = pos;
	n.derived = n^;
	base: ^Node = n;
	_ = base;
	return n;
}

declarations: map[string] typeid;
determine_type_of_expr :: proc(expr: ^Expr) -> typeid {
	switch v in expr.derived {
		case Expr_Ident: {
			if v.name in declarations {
				return declarations[v.name];
			}
			return nil;
		}
		case Expr_Str: {
			return typeid_of(string);
		}
		case Expr_Numb: {
			return typeid_of(f32);
		}
		case Expr_Call: {
			return typeid_of(proc());
		}
		case Expr_Op: {
			left_type := determine_type_of_expr(v.left);
			right_type := determine_type_of_expr(v.right);

			if left_type == nil || right_type == nil {
				return nil;
			}

			if left_type != right_type {
				fmt.println("trying to op on", left_type, "and", right_type);
				return nil;
			}

			return left_type;
		}
		case: {
			fmt.println("Cannot determine type of ", expr.derived);
			return nil;
		}
	}
}

parse_stmt :: proc(tokens: ^[dynamic] IToken) -> ^Stmt {
	#partial switch curr_token.token {
		case .FN: {
			fn_token := curr_token;
			tk := advance_token(tokens);

			ident, _ := expect_token(tokens, .IDENT);

			expect_token(tokens, .PAR_OPEN);
			expect_token(tokens, .PAR_CLOSE);
			
			block_stmt := parse_stmt(tokens);

			ds := new_ast(Decl_Fn, fn_token.pos);
			ds.name = ident.value.(string);
			ds.type = nil;
			ds.block = auto_cast block_stmt;

			fmt.println(ident.value.(string));
		}
		case .CB_OPEN: {
			cb_token := curr_token;
			tk := advance_token(tokens);

			nodes: [dynamic]^Stmt;

			closed := true;

			loop: for {
				if tk.token == .CB_CLOSE {
					advance_token(tokens);
					break loop;
				}

				stmt := parse_stmt(tokens);
				if stmt == nil {
					return nil;
				}
				append(&nodes, stmt);

				tk = curr_token;
				fmt.println(tk);

				if tk.token == .CB_CLOSE {
					advance_token(tokens);
					break loop;
				} else if tk.token == .EOF {
					closed = false;
					break loop;
				}
			}

			if !closed {
				fmt.println("block not closed");
				return nil;
			}

			fmt.println(nodes);

			bs := new_ast(Stmt_Block, cb_token.pos);
			bs.stmts = nodes;

			return bs;

		}
		case .VAR: {
			var_token := curr_token;
			advance_token(tokens);

			ident, _ := expect_token(tokens, .IDENT);

			right_expr: ^Expr;
			type_of_expr: typeid;

			#partial switch curr_token.token {
				case .COLON: {
					advance_token(tokens);
					
					tk, _ := expect_token(tokens, .TYPE);
					type_of_expr = tk.value.(typeid);
				}
			}

			#partial switch curr_token.token {
				case .OP: {
					advance_token(tokens);

					right_expr = parse_expr(tokens, 0);

					denoted_type := type_of_expr;
					type_of_expr = right_expr.type;

					if denoted_type != nil {
						if denoted_type != type_of_expr {
							fmt.println("Expected expr of type", denoted_type, ", got", type_of_expr);
							return nil;
						}
					}
				}
				case: {
					if type_of_expr == nil {
						fmt.println("Cannot determine the type of variable without a type annotation or = expression.");
						return nil;
					}
				}
			}
			expect_token(tokens, .SEMICOLON);

			vs := new_ast(Decl_Var, var_token.pos);
			vs.name = ident.value.(string);
			vs.type = type_of_expr;

			if right_expr == nil {
				//default values	
				switch type_of_expr {
					case string: {
						default_str := new_ast(Expr_Str, curr_token.pos);
						default_str.content = "";

						vs.expr = default_str;
					}
					case f32: {
						default_float := new_ast(Expr_Numb, curr_token.pos);
						default_float.value = 0;

						vs.expr = default_float;
					}
					case: {
						fmt.println("Cannot set default value of type", type_of_expr);
						return nil;
					}
				}
			} else {
				vs.expr = right_expr;
			}

			declarations[vs.name] = vs.type;

			return vs;
		}
		case .RET: {
			return_token := curr_token;
			tok := advance_token(tokens);

			expr := parse_expr(tokens, 0);

			expect_token(tokens, .SEMICOLON);

			rs := new_ast(Stmt_Return, return_token.pos);
			rs.result = expr;

			return rs;
		}
		case: {
			tk := curr_token;
			next_tk, _ := peek_token(tokens, 1);

			expr := parse_expr(tokens, 1);

			switch v in expr.derived {
				case Expr_Call: {
					expect_token(tokens, .SEMICOLON);

					ds := new_ast(Stmt_Discard, tk.pos);
					ds.call = auto_cast expr;

					return ds;
				}
				case: {
					#partial switch next_tk.token {
						case .OP: {
							op_value := curr_token.value.(Op);

							#partial switch op_value {
								case .SET: {
									advance_token(tokens);

									right_expr := parse_expr(tokens, 0);

									expect_token(tokens, .SEMICOLON);

									set_stmt := new_ast(Stmt_Assign, tk.pos);
									set_stmt.name = (^Expr_Ident)(expr).name;
									set_stmt.expr = right_expr;

									free(expr);

									return set_stmt;
								}
							}							
						}
					}
				}
			}
		}
	}

	return nil;
}

peek_token :: proc(tokens: ^[dynamic]IToken, f: int) -> (IToken, bool) {
	if build_pos+f > build_len {
		return {}, true;
	}

	return tokens[build_pos+f], false;
}


parse_expr :: proc(tokens: ^[dynamic] IToken, no_ops: int) -> (build_expr: ^Expr) {
	tk := curr_token;
	advance_token(tokens);

	#partial switch tk.token {
		case .STR: {
			str := tk.value.(string);

			str_node := new_ast(Expr_Str, tk.pos);
			str_node.content = str;

			build_expr = str_node;

		}
		case .NUMBER: {
			numb := tk.value.(f32);

			numb_node := new_ast(Expr_Numb, tk.pos);
			numb_node.value = numb;

			build_expr = numb_node;
		}
		case .OP: {
			op_value := tk.value.(Op);
			#partial switch op_value {
				case .ADD: {
					build_expr = parse_expr(tokens, 1);
				}
				case .SUB: {
					expr := parse_expr(tokens, 1);

					build_expr = expr;
				}
				case: {
					fmt.println("not implemented op");
					return nil;
				}
			}
		}
		case .IDENT: {
			ident_name := tk.value.(string);
			
			#partial switch curr_token.token {
				case .PAR_OPEN: {
					args := make([dynamic]^Expr);
					argc := 0;
					closed := false;

					advance_token(tokens);

					loop: for build_pos < build_len {
						#partial switch curr_token.token {
							case .PAR_CLOSE: {
								advance_token(tokens);
								closed = true;
								break loop;
							}
						}

						arg_expr := parse_expr(tokens, 0);
						append(&args, arg_expr);
						argc += 1;

						#partial switch curr_token.token {
							case .COMMA: {
								advance_token(tokens);
							}
							case .PAR_CLOSE: {}
							case: {
								return nil;
							}
						}
					}

					if !closed {
						return nil;
					}

					call_node := new_ast(Expr_Call, tk.pos);
					call_node.name = ident_name;
					call_node.args = args;

					build_expr = call_node;
				}
				case: {
					ie := new_ast(Expr_Ident, tk.pos);
					ie.name = ident_name;
					if ie.name in declarations {
						ie.type = declarations[ie.name];
					} 

					build_expr = ie;
				}
			}

		}
	}

	if (no_ops & 1) == 0 {
		if curr_token.token == .OP {
			_tk := curr_token;
			advance_token(tokens);

			op_expr := parse_ops(tokens, build_expr, _tk);

			build_expr = op_expr;
		}
	}

	type_of_build_expr := determine_type_of_expr(build_expr);
	build_expr.type = type_of_build_expr;

	return;
}

parse_ops :: proc(tokens: ^[dynamic]IToken, _expr: ^Expr, _tk: IToken) -> ^Expr {
	temp_exprs := make([dynamic]^Expr);
	append(&temp_exprs, _expr); //HERE:

	ops := make([dynamic]IToken);
	append(&ops, _tk);

	tk: IToken;

	for true {
		expr := parse_expr(tokens, 1);
		append(&temp_exprs, expr);

		to_break := false;

		tk = curr_token;

		#partial switch tk.token {
			case .OP: {
				advance_token(tokens);
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

					new_expr := new_ast(Expr_Op, tk.pos);
					new_expr.op = op;
					new_expr.left = temp_exprs[i];
					new_expr.right = temp_exprs[i+1];

					temp_exprs[i] = new_expr;

					unordered_remove(&temp_exprs, i+1);
					unordered_remove(&ops, i);
					n -= 1;
					i -= 1;
				}
				case:{}
			}
			i += 1;
		}
		pri += 1;
	}

	result := temp_exprs[0];

	delete(temp_exprs);
	delete(ops);

	return result;
}
