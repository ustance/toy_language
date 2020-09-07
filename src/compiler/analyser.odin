package compiler;

import "core:fmt";


analyse :: proc(ast: ^[dynamic] ^Node) -> (err: bool) {
	for stmt in ast {
		switch v in stmt.derived {
			case Decl_Var: {
				decl_var: ^Decl_Var = auto_cast stmt;

				if v.type == nil {
					err := resolve_expr_type(decl_var.expr);
					if err do return true;
					decl_var.type = decl_var.expr.type;
				}
			}
			case: {
				fmt.println("You can't do anything in file scope. Kinda.");
				fmt.println(v);
				return true;
			}
		}
	}

	for stmt in ast {
		fmt.println(stmt.derived);
	}

	return;
}

resolve_expr_type :: proc(expr: ^Expr) -> bool {
	if expr.type != nil do return false;

	switch v in expr.derived {
		case Expr_Str, Expr_Numb:{}
		case Expr_Ident: {
			if v.name in declarations {
				expr.type = declarations[v.name];
			} else {
				fmt.println("not defined", v.name);
				return true;
			}
			expr.derived = expr^;
		}
		case Expr_Op: {
			expr_op: ^Expr_Op = auto_cast expr;
			err1 := resolve_expr_type(expr_op.left);
			if err1 do return true;
			expr_op.left.derived = expr_op.left^;
			err2 := resolve_expr_type(expr_op.right);
			if err2 do return true;
			expr_op.right.derived = expr_op.right^;

			if expr_op.left.type != expr_op.right.type {
				fmt.println("cannot op on different types");
				return true;
			}

			expr_op.type = expr_op.left.type;
			expr_op.derived = expr_op^;

			expr.derived = expr^;
		}	
		case: {
			fmt.println("cannot resolve type of", v);
			return true;
		}
	}

	return false;
}
