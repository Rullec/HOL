(* ===================================================================== *)
(* FILE          : Definition.sml                                        *)
(* DESCRIPTION   : Principles of type definition, constant specification *)
(*                 and constant definition. Almost the same as in hol88, *)
(*                 except that parsing status is not dealt with by the   *)
(*                 functions in this module (at this stage, the parser   *)
(*                 hasn't been compiled yet). A further difference is    *)
(*                 the principle of constant definition is not derived   *)
(*                 from constant specification, as in hol88. The         *)
(*                 principle of definition has also been changed to be   *)
(*                 simpler than that of hol88.                           *)
(*                                                                       *)
(* AUTHOR        : (c) Mike Gordon, University of Cambridge              *)
(* TRANSLATOR    : Konrad Slind, University of Calgary                   *)
(* DATE          : September 11, 1991  -- translated                     *)
(* DATE          : October 1, 2000     -- union of previous 3 modules    *)
(* ===================================================================== *)

structure Definition : RawDefinition =
struct

open Feedback Lib KernelTypes Kind Type Term

infixr --> |-> ==>;

val ERR       = mk_HOL_ERR "Definition";
val TYDEF_ERR = ERR "new_type_definition"
val DEF_ERR   = ERR "new_definition"
val SPEC_ERR  = ERR "new_specification";
val TYSPEC_ERR= ERR "new_type_specification";

val TYDEF_FORM_ERR = TYDEF_ERR "expected a theorem of the form \"?x. P x\"";
val DEF_FORM_ERR   = DEF_ERR   "expected a term of the form \"v = M\"";

val current_theory = Theory.current_theory;


(*---------------------------------------------------------------------------
      Misc. utilities. There are some local definitions of syntax
      operations, since we delay defining all the basic formula
      operations until after boolTheory is built.
 ---------------------------------------------------------------------------*)

fun dest_atom tm = (dest_var tm handle HOL_ERR _ => dest_const tm)

fun mk_exists (absrec as (Bvar,_)) =
  let val Bvar_ty = type_of Bvar
  in
    mk_comb(mk_thy_const{Name="?",Thy="bool", Ty= (Bvar_ty-->bool)-->bool},
            mk_abs absrec)
  end

fun dest_exists M =
 let val (Rator,Rand) = with_exn dest_comb M (TYDEF_ERR"dest_exists")
 in case total dest_thy_const Rator
     of SOME{Name="?",Thy="bool",...} => dest_abs Rand
      | otherwise => raise TYDEF_ERR"dest_exists"
 end

fun dest_tyexists M =
 let val (Rator,Rand) = with_exn dest_comb M (TYSPEC_ERR"dest_tyexists")
 in case total dest_thy_const Rator
     of SOME{Name="?:",Thy="bool",...} => dest_tyabs Rand
      | otherwise => raise TYSPEC_ERR"dest_tyexists"
 end

fun nstrip_exists 0 t = ([],t)
  | nstrip_exists n t =
     let val (Bvar, Body) = dest_exists t
         val (l,t'') = nstrip_exists (n-1) Body
     in (Bvar::l, t'')
     end;

fun nstrip_tyexists 0 t = ([],t)
  | nstrip_tyexists n t =
     let val (Bvar, Body) = dest_tyexists t
         val (l,t'') = nstrip_tyexists (n-1) Body
     in (Bvar::l, t'')
     end;

fun mk_eq (lhs,rhs) =
 let val ty = type_of lhs
     val eq = mk_thy_const{Name="=",Thy="min",Ty=ty-->ty-->bool}
 in list_mk_comb(eq,[lhs,rhs])
 end;

fun dest_eq M =
  let val (Rator,r) = dest_comb M
      val (eq,l) = dest_comb Rator
  in case dest_thy_const eq
      of {Name="=",Thy="min",...} => (l,r)
       | _ => raise ERR "dest_eq" "not an equality"
  end;

fun check_null_hyp th f =
  if null(Thm.hyp th) then ()
  else raise f "theorem must have no assumptions";

fun check_free_vars tm f =
  case free_vars tm
   of [] => ()
    | V  => raise f (String.concat
            ("Free variables in rhs of definition: "
             :: commafy (map (Lib.quote o fst o dest_var) V)));

fun check_free_tyvars tm f =
  case type_vars_in_term tm
   of [] => ()
    | V  => raise f (String.concat
            ("Free type variables in specification: "
             :: commafy (map (Lib.quote o fst o dest_var_type) V)));

fun check_tyvars body_tyvars ty f =
 case Lib.set_diff body_tyvars (type_vars ty)
  of [] => ()
   | extras =>
      raise f (String.concat
         ("Unbound type variable(s) in definition: "
           :: commafy (map (Lib.quote o fst o dest_var_type) extras)));

fun check_kdvars body_kdvars bound_kdvars f =
 case Lib.set_diff body_kdvars bound_kdvars
  of [] => ()
   | extras =>
      raise f (String.concat
         ("Unbound kind variable(s) in definition: "
           :: commafy (map (Lib.quote o fst o dest_var_kind) extras)));

fun bind s ty =
  (Theory.new_constant (s,ty);
   mk_thy_const {Name=s,Ty=ty,Thy=current_theory()}
  );

fun mk_def (w as TERM _, tm)    = (w, Thm.mk_defn_thm (Tag.empty_tag, tm))
  | mk_def (w as THEOREM th,tm) = (w, Thm.mk_defn_thm (Thm.tag th, tm))

val new_definition_hook = ref
    ((fn tm => ([]:term list, tm:term)),
     (fn (V:term list,th:thm) =>
       if null V then th
       else raise ERR "new_definition" "bare post-processing phase"));

val (new_specification_hook:(string list -> unit) ref) = ref
 (fn _ => raise ERR "new_specification"
            "introduced constants have not been added to the grammar")

(*---------------------------------------------------------------------------*)
(*                DEFINITION PRINCIPLES                                      *)
(*---------------------------------------------------------------------------*)

fun new_type_definition (name,thm) =
 let val (_,Body)  = with_exn dest_exists (Thm.concl thm) TYDEF_FORM_ERR
     val P         = with_exn rator Body TYDEF_FORM_ERR
     val Pty       = type_of P
     val (dom,rng) = with_exn dom_rng Pty TYDEF_FORM_ERR
     val tyvars    = Listsort.sort Type.compare (type_vars_in_term P)
     val checked   = check_null_hyp thm TYDEF_ERR
     val checked   = assert_exn null (free_vars P)
                       (TYDEF_ERR "subset predicate must be a closed term")
     val checked   = check_kdvars (kind_vars_in_term P) (kind_varsl tyvars) TYDEF_ERR
                       handle e => raise (wrap_exn "new_type_definition" "check_kdvars" e)
     val checked   = assert_exn (eq_ty bool) rng
                      (TYDEF_ERR "subset predicate has the wrong type")
     val newkd     = List.foldr (op ==>) (kind_of dom) (map kind_of tyvars)
     val   _       = Theory.new_type_opr(name, newkd)
     val newty     = mk_thy_type{Tyop=name,Thy=current_theory(),Args=tyvars}
     val repty     = newty --> dom
     val rep       = mk_primed_var("rep", repty)
     val TYDEF     = mk_thy_const{Name="TYPE_DEFINITION", Thy="bool",
                                    Ty = Pty --> (repty-->bool)}
     val (wit,def) = mk_def (THEOREM thm,
                        mk_exists(rep, list_mk_comb(TYDEF,[P,rep])))
 in
   Theory.store_type_definition (name^"_TY_DEF", name, wit, def)
 end
 handle e => raise (wrap_exn "Definition" "new_type_definition" e);


fun new_type_specification (name,tnames,th) =
 let val checked   = check_null_hyp th TYSPEC_ERR
     val checked   = check_free_vars (Thm.concl th) TYSPEC_ERR
     val checked   = check_free_tyvars (Thm.concl th) TYSPEC_ERR
     val checked   = assert_exn (op=) (length(mk_set tnames),length tnames)
                     (TYSPEC_ERR "duplicate type names in specification")
     val (tyvs,Q)  = with_exn (nstrip_tyexists (length tnames)) (Thm.concl th)
                     (TYSPEC_ERR "too few existentially quantified type variables")
     fun vOK V a   = check_kdvars V (kind_vars a) TYSPEC_ERR
     val checked   = List.app (vOK (kind_vars_in_term Q)) tyvs
     fun newty n k = (Theory.new_type_opr(n,k); mk_thy_con_type{Thy=current_theory(),Tyop=n,Kind=k})
     val kds       = map (snd o dest_var_type) tyvs
     val newtys    = map2 newty tnames kds
     val newQ      = inst (map (op |->) (zip tyvs newtys)) Q
     val (wit,def) = mk_def (THEOREM th, newQ)
 in
   Theory.store_definition (name^"_TY_SPEC", tnames, wit, def)
 end
 handle e => raise (wrap_exn "Definition" "new_type_specification" e);


fun new_definition(name,M) =
 let val (dest,post) = !new_definition_hook
     val (V,eq)      = dest M
                         handle e => raise (wrap_exn "new_definition" "dest M" e)
     val (lhs,rhs)   = with_exn dest_eq eq DEF_FORM_ERR
                         handle e => raise (wrap_exn "new_definition" "dest_eq eq" e)
     val (Name,Ty)   = with_exn dest_atom lhs DEF_FORM_ERR
                         handle e => raise (wrap_exn "new_definition" "dest_atom lhs" e)
     val checked     = check_free_vars rhs DEF_ERR
                         handle e => raise (wrap_exn "new_definition" "check_free_vars" e)
     val checked     = check_tyvars (type_vars_in_term rhs) Ty DEF_ERR
                         handle e => raise (wrap_exn "new_definition" "check_tyvars" e)
     val checked     = check_kdvars (kind_vars_in_term rhs) (kind_vars Ty) DEF_ERR
                         handle e => raise (wrap_exn "new_definition" "check_kdvars" e)
     val (wit,def)   = mk_def(TERM rhs, mk_eq(bind Name Ty, rhs))
                         handle e => raise (wrap_exn "new_definition" "mk_def" e)
 in
   Theory.store_definition (name, [Name], wit, post(V,def) handle e => (print "post\n";Raise e))
 end
 handle e => raise (wrap_exn "Definition" "new_definition" e);


fun new_specification (name, cnames, th) =
 let val checked   = check_null_hyp th SPEC_ERR
     val checked   = check_free_vars (Thm.concl th) SPEC_ERR
     val checked   = assert_exn (op=) (length(mk_set cnames),length cnames)
                     (SPEC_ERR "duplicate constant names in specification")
     val (V,body)  = with_exn (nstrip_exists (length cnames)) (Thm.concl th)
                     (SPEC_ERR "too few existentially quantified variables")
     fun vOK V v   = check_tyvars V (type_of v) SPEC_ERR
     val checked   = List.app (vOK (type_vars_in_term body)) V
     fun vOKkd V v = check_kdvars V (kind_vars (type_of v)) SPEC_ERR
     val checked   = List.app (vOKkd (kind_vars_in_term body)) V
     fun addc v s  = v |-> bind s (snd(dest_var v))
     val (wit,def) = mk_def (THEOREM th, subst (map2 addc V cnames) body)
     val final     =  Theory.store_definition (name, cnames, wit, def)
 in
    !new_specification_hook cnames   (* tell parser about the new names *)
  ; final
 end
 handle e => raise (wrap_exn "Definition" "new_specification" e);

end (* Definition *)