structure A = Absyn
structure S = Symbol
structure T = Types
structure E = Env

signature SEMANT =
sig
  val transProg : A.exp -> unit
end

structure Semant : SEMANT =
struct
  structure Translate = struct type exp = unit end
  type expty = {exp: Translate.exp, ty: T.ty}
  type venv = E.enventry S.table
  type tenv = T.ty S.table

  fun transExp (venv, tenv) =
    let
      fun trexp (A.VarExp(var)) = trvar var
        | trexp (A.NilExp) = {exp=(), ty=T.NIL}
        | trexp (A.IntExp(int)) = {exp=(), ty=T.INT}
				| trexp (A.StringExp(string,pos)) = {exp=(), ty=T.STRING}
        | trexp (A.CallExp{func,args,pos}) = check_func (func,args,pos)
        | trexp (A.OpExp{left,oper=A.PlusOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.MinusOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.TimesOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.DivideOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.EqOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.NeqOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.LtOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.GtOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.LeOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
				| trexp (A.OpExp{left,oper=A.GeOp,right,pos}) = (check_int(trexp left, pos); check_int(trexp right, pos); {exp = (), ty=T.INT})
        | trexp (A.RecordExp{fields,typ,pos}) = check_record (fields,typ,pos)
        | trexp (A.SeqExp(explist)) = check_sequence (explist)
        | trexp (A.AssignExp{var,exp,pos}) = check_assign (var,exp,pos)
        | trexp (A.IfExp{test=exp1,then'=exp2,else'=exp3,pos=pos}) = check_if (exp1,exp2,exp3,pos)
        | trexp (A.WhileExp{test=exp1,body=exp2,pos=pos}) = check_while (exp1,exp2,pos)
        | trexp (A.ForExp{var=var,escape=bool,lo=exp1,hi=exp2,body=exp3,pos=pos}) = check_for (var,exp1,exp2,exp3,pos)
        | trexp (A.BreakExp(pos)) = check_break(pos)
        (*
           LetExp
           ArrayExp
        *)

        and trvar (A.SimpleVar(id,pos)) = (case S.look(venv, id) of
                      SOME (E.VarEntry{ty}) => {exp=(), ty=actual_ty (ty,pos)}
                    | _ => (ErrorMsg.error pos ("undefined variable: " ^ S.name(id)); {exp=(), ty=T.UNIT}))
          | trvar (A.FieldVar(v,id,pos)) = trvar v (* TODO: check if id is part of record *)
          | trvar (A.SubscriptVar(v,exp,pos)) = (check_int(trexp exp,pos); trvar v) (* TODO: make sure v is an array *)

        and actual_ty (ty,pos) =
          let
            fun check_ty typ = (case typ of
                T.NAME(s, t) => (case !t of
                    NONE => (ErrorMsg.error pos ("undefined type: " ^ S.name(s)); T.UNIT)
                  | SOME t => check_ty t)
              | _ => typ)
          in
            check_ty ty
          end

        and check_func (func,args,pos) =  (case S.look(venv, func) of
            SOME (E.FunEntry{formals=tylist, result=ty}) => {exp=(), ty=T.NIL} (* TODO: check num arguments match, check that types match, check return, change return *)
          | _ => (ErrorMsg.error pos ("undefined function: " ^ S.name(func)); {exp=(), ty=T.UNIT}))

        and check_record (fields,typ,pos) = (case S.look(tenv, typ) of
            SOME t => (case actual_ty (t,pos) of
                T.RECORD(typelist,unique) => {exp=(), ty=T.NIL} (* TODO: check num arguments match, check that types match, change return *)
              | _ => (ErrorMsg.error pos ("not record type: " ^ S.name(typ)); {exp=(), ty=T.UNIT}))
          | NONE => (ErrorMsg.error pos ("undefined record: " ^ S.name(typ)); {exp=(), ty=T.UNIT}))

        and check_sequence [] = {exp=(), ty=Types.UNIT}
          | check_sequence ((exp, _)::nil) = trexp exp
          | check_sequence ((exp, _)::explist) = (trexp exp; check_sequence (explist))

        and check_assign (var,exp,pos) =
          let
            val  {exp=_,ty=tyl} = trvar var
            val  {exp=_,ty=tyr} = trexp exp
          in
            if tyl<>tyr
            then (ErrorMsg.error pos ("variable and expresion of different type"); {exp=(), ty=T.UNIT})
            else {exp=(), ty=T.UNIT}
          end

        and check_if (exp1,exp2,exp3,pos) =
          (check_int (trexp exp1,pos);
           check_unit (trexp exp2,pos);
           case exp3 of SOME exp => check_int (trexp exp,pos) | NONE => ();
           {exp=(), ty=T.UNIT})

        and check_while (exp1,exp2,pos) =
          (check_int (trexp exp1,pos);
           check_unit (trexp exp2,pos);
           {exp=(), ty=T.UNIT})

        and check_for (var,exp1,exp2,exp3,pos) =
          (check_int (trexp exp1,pos);
           check_int (trexp exp2,pos);
           check_unit (transExp(S.enter(venv,var,Env.VarEntry{ty=Types.INT}),tenv) exp3,pos);
           {exp=(), ty=T.UNIT})

        and check_break (pos) = {exp=(), ty=T.UNIT} (* TODO: check inside for or while *)

        and check_int ({exp=_,ty=T.INT},_) = ()
      	  | check_int ({exp=_,ty=_},pos) = ErrorMsg.error pos "integer argument expected"

        and check_unit ({exp=_,ty=T.UNIT},_) = ()
          | check_unit ({exp=_,ty=_},pos) = ErrorMsg.error pos "unit argument expected"
    in
      trexp
    end

  fun transProg exp =
    let
      val expty = (transExp (E.base_venv, E.base_tenv) exp)
    in
      ()
    end

end