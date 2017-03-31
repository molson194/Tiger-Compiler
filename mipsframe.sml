structure MipsFrame : FRAME =
struct

datatype access = InFrame of int
								| InReg of Temp.temp

type frame = {name : Temp.label, formals: access list, locals: int ref}

fun newFrame {name:Temp.label,formals:bool list} =
	let val locAlloc = ref 0
			val numRegs = ref 0
			fun transFormals (true::formals) =
				let in
						locAlloc := !locAlloc+1;
						InFrame((!locAlloc)*(~4))::transFormals(formals)
				end
				| transFormals (false::formals) =
					let in
							numRegs := !numRegs+1;
							if !numRegs<4
							then (InReg(Temp.newtemp())::transFormals(formals))
							else (locAlloc := !locAlloc+1; InFrame((!locAlloc)*(~4))::transFormals(formals))
					end
			| transFormals [] = []

	in
			{name=name,formals=transFormals(formals),locals=locAlloc}:frame
	end


fun name (a:frame) = #name a

fun formals (a:frame) = #formals a

fun allocLocal (a:frame)(true) =
	let in
			(#locals a) := !(#locals a) + 1;
			InFrame((!(#locals a))*(~4))
	end
	| allocLocal (a:frame)(false) = InReg(Temp.newtemp())

val FP = Temp.newtemp()
val RV = Temp.newtemp()
val wordsize = 32 (* bits *)

fun exp acc exp = case acc of
	InFrame(num) => Tree.MEM(Tree.BINOP(Tree.PLUS, exp, Tree.CONST(num)))
	| InReg(tmp) => Tree.TEMP(tmp)

fun externalCall (s,args) =
	Tree.CALL(Tree.NAME(Temp.namedlabel(s)), args)

type register = string

val tempMap = Temp.Map.empty

fun tempString temp =
	case Temp.Map.find(tempMap,temp) of
			SOME(register) => register
		| NONE => Temp.makestring temp

fun makeRegs (0,[]) = []
	| makeRegs (n,(name::names)) =
		let
				val r = Temp.newtemp();
		in
				Temp.Map.insert(tempMap,r,name);
				r::(makeRegs(n-1, names))
		end
	| makeRegs (n,[]) =
		let
				val r = Temp.newtemp();
		in
				Temp.Map.insert(tempMap,r,NONE);
				r::(makeRegs(n-1,[]))
		end


val specialregs = makeRegs(5,["rv":register,"fp":register,"sp":register,"ra":register,"r0":register]) (* $rv,$fp,$sp,$ra,$0 *)
val argregs = makeRegs(4,[]) (* $a0-$a3 *)
val calleesaves = makeRegs(8,[]) (* $s0-$s7 *)
val callersaves = makeRegs (10,[]) (* $t0-$t9 *)

fun procEntryExit1 (frame,body) = body

fun procEntryExit2 (frame,body) = body @ [Assem.OPER{assem="", src=specialregs @ calleesaves, dst=[],jump=SOME[]}]

fun procEntryExit3 ({name=name, formals=formals, locals=locals}:frame, body : Assem.instr list) =
		{prolog = "PROCEDURE " ^ Symbol.name name ^ "\n", body = body, epilog = "END " ^ Symbol.name name ^ "\n"}

(* TODO: BEFORE: Create label for function, $ra onto 0(sp), $s0-$s7 push to stack, move stack by 4*(locals+1ra+8s), move $a_ into registers where used
				 AFTER: jr $ra, change ra to 0(sp), return $t0-$t9 to sp, returning go to v0, move stack back *)

datatype frag = PROC of {body: Tree.stm, frame: frame}
                | STRING of Temp.label * string


end
