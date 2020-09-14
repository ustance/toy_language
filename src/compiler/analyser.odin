package compiler;

import "core:fmt";

ANALYSER_DEBUG :: true;

set_to_default_value :: proc(decl: ^Decl_Var) -> bool {
	switch decl.type {
		case string:
			str_node := new_ast(Expr_Str, decl.pos);
			str_node.content = "";

			decl.expr = str_node;
		case f32:
			numb_node := new_ast(Expr_Numb, decl.pos);
			numb_node.value = 14;

			decl.expr = numb_node;
		case: {
			fmt.println("cannot set", decl.type, "to default value");
			return true;
		}
	}
	return false;
}

analyse_decl_var :: proc(decl_var: ^Decl_Var) -> bool {
	if decl_var.expr == nil && decl_var.type == nil {
		fmt.println("cannot determine type of", decl_var.name);
		return true;
	}

	if decl_var.type != nil && decl_var.expr == nil {
		set_to_default_value(decl_var);
	}

	err := resolve_expr_type(decl_var.expr);
	if err do return true;

	if decl_var.type != nil && (decl_var.type != decl_var.expr.type) {
		fmt.println("expected", decl_var.type, "got", decl_var.expr.type);
		return true;
	}

	decl_var.type = decl_var.expr.type;

	decl_var.derived = decl_var^;
	
	return false;
}

analyse :: proc(ast: ^[dynamic] ^Node) -> (err: bool) {
	for stmt in ast {
		switch v in stmt.derived {
			case Decl_Var: {
				decl_var: ^Decl_Var = auto_cast stmt;
				err := analyse_decl_var(decl_var);
				if err do return true;
			}
			case Decl_Foreign_Fn: {
				decl_foreign_fn: ^Decl_Foreign_Fn = auto_cast stmt;

				if decl_foreign_fn.scope.parent != nil {
					fmt.println("Foreign functions can only be declared at file scope");
					return true;
				}
			}
			case Decl_Fn: {
				decl_fn: ^Decl_Fn = auto_cast stmt;

				curr_pos: i32 = 0;
				for stmt in decl_fn.block.stmts {
					stmt.scope = {
						decl_fn.block,
						curr_pos,
					};
					err := analyse_stmt(stmt);
					if err do return true;

					curr_pos += 1;
				}
			}
			case: {
				fmt.println("You can't do anything in file scope. Kinda.");
				fmt.println(v);
				return true;
			}
		}
	}

	if ANALYSER_DEBUG { 
		index := 0;
		for stmt in ast {
			fmt.println(index, ": ", stmt.derived);
			switch v in stmt.derived {
				case Decl_Fn: {
					for i in 0..<len(v.block.stmts) {
						fmt.println("\t", v.block.stmts[i].derived);
					}
				}
				case:
			}
			index += 1;
		}
	}

	return;
}

analyse_expr :: proc(expr: ^Expr) -> bool {

	switch v in expr.derived {
		case Expr_Call: {
			expr_call: ^Expr_Call = auto_cast expr;
		}
	}
	
	return false;
}

analyse_stmt :: proc(stmt: ^Stmt) -> bool {

	switch v in stmt.derived {
		case Decl_Var: {
			decl_var: ^Decl_Var = auto_cast stmt;
			err := analyse_decl_var(decl_var);
			if err do return true;
		}
		case Decl_Foreign_Fn: {
			decl_foreign_fn: ^Decl_Foreign_Fn = auto_cast stmt;

			fmt.println("Foreign functions can only be declared at file scope");
			return true;
		}
		case Decl_Fn: {
			decl_fn: ^Decl_Fn = auto_cast stmt;

			fmt.println("Functions can only be declared at file scope");
			return true;
		}
		case Stmt_Discard: {
			stmt_d: ^Stmt_Discard = auto_cast stmt;
			err := analyse_expr(stmt_d.call);
			if err do return true;
		}
		case: {
			fmt.println("Can't analyse stmt");
			fmt.println(v);
			return true;
		}
	}
	
	return false;
}


resolve_expr_type :: proc(expr: ^Expr) -> bool {
	if expr.type != nil do return false;

	switch v in expr.derived {
		case Expr_Str: {
			expr.type = string;
		}
		case Expr_Numb:{
			expr.type = f32;
		}
		case Expr_Ident: {
			expr_ident: ^Expr_Ident = auto_cast expr;
			decl: ^Decl_Var = auto_cast declarations[v.name];

			if v.name in declarations {
				is_decl_visible := false;

				if decl.scope.parent == nil {
					is_decl_visible = true;
				}

				if decl.scope.parent == expr.scope.parent && decl.scope.pos < expr.scope.pos {
					is_decl_visible = true;
				}


				if !is_decl_visible {
					fmt.println("trying to access not yet defined variable", v.name);
					return true;
				}

				resolve_expr_type(decl.expr);
				expr_ident.type = decl.expr.type;

			} else {
				fmt.println("not defined", v.name);
				return true;
			}
		}
		case Expr_Op: {
			expr_op: ^Expr_Op = auto_cast expr;

			err1 := resolve_expr_type(expr_op.left);
			if err1 do return true;

			err2 := resolve_expr_type(expr_op.right);
			if err2 do return true;

			if expr_op.left.type != expr_op.right.type {
				fmt.println("cannot op on different types");
				fmt.println(expr_op.left);
				fmt.println(expr_op.right);
				return true;
			}

			expr_op.type = expr_op.left.type;
		}	
		case: {
			fmt.println("cannot resolve type of", v);
			return true;
		}
	}

	return false;
}
