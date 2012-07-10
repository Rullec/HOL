(* ===================================================================== *)
(* FILE          : Type.sml                                              *)
(* DESCRIPTION   : HOL types.                                            *)
(*                                                                       *)
(* AUTHOR        : (c) Konrad Slind, University of Calgary               *)
(* DATE          : August 26, 1991                                       *)
(* UPDATE        : October 94. Type signature implementation moved from  *)
(*                 symtab.sml, which is now gone.                        *)
(* Modified      : September 22, 1997, Ken Larsen  (functor removal)     *)
(*                 April 12, 1998, Konrad Slind                          *)
(*                 July, 2000, Konrad Slind                              *)
(* ===================================================================== *)

structure Type :> Type =
struct

(*
In *scratch*, type
(hol-set-executable sml-executable)
or
(hol-set-executable (concat hol-home "/bin/hol.bare"))

and type Ctrl-j.

quotation := true;
loadPath := "/usr/local/hol/hol/sigobj" :: !loadPath;
loadPath := "/usr/local/hol/hol" ^ "/src/0" :: !loadPath;

app load ["Feedback","Lib","KernelTypes","Kind","KernelSig","Lexis","Redblackmap",
          "Binarymap"];
*)

open Feedback Lib KernelTypes Rank Kind;   infix |-> ## :>=: :=:;   infixr 3 ==>;

type tyvar    = KernelTypes.tyvar;
type kind     = KernelTypes.kind;
type hol_type = KernelTypes.hol_type;
type ('a,'b)subst = ('a,'b)Lib.subst;

val ERR = mk_HOL_ERR "Type";
val WARN = HOL_WARNING "Type";

(* UNCHANGEDTY is thrown internally by functions that modify types; only seen in kernel *)
exception UNCHANGEDTY;

val pp_type_ref = ref (fn pps:HOLPP.ppstream => fn ty:hol_type => ())
val type_to_string_ref = ref (fn ty:hol_type => "<type>")
fun sprint pp x = HOLPP.pp_to_string 80 pp x
fun set_pp_type f = (pp_type_ref := f; type_to_string_ref := sprint f)
fun type_to_string ty = !type_to_string_ref ty

(*---------------------------------------------------------------------------
              Create the signature for HOL types
 ---------------------------------------------------------------------------*)

val typesig = KernelSig.new_table() : kind KernelSig.symboltable
fun prim_delete_type (k as {Thy, Tyop}) =
    ignore (KernelSig.retire_name(typesig, {Thy = Thy, Name = Tyop}))

fun prim_new_type_opr {Thy,Tyop} kd = let
in
  ignore (KernelSig.insert(typesig,{Thy=Thy,Name=Tyop},kd))
end
fun prim_new_type (r as {Thy,Tyop}) n = let
  val _ = n >= 0 orelse failwith "invalid arity"
in
  prim_new_type_opr r (mk_arity n)
end
fun del_segment s = KernelSig.del_segment(typesig, s)

fun uptodate_type (TyFv _) = true
  | uptodate_type (TyBv _) = true
  | uptodate_type (TyCon(info,_)) = KernelSig.uptodate_id info
  | uptodate_type (TyApp(opr,arg)) = uptodate_type opr andalso uptodate_type arg
  | uptodate_type (TyAbs(bv,body)) = uptodate_type body
  | uptodate_type (TyAll(bv,body)) = uptodate_type body
  | uptodate_type (TyExi(bv,body)) = uptodate_type body




(*---------------------------------------------------------------------------*
 * Builtin type operators (fun, bool, ind). These are in every HOL           *
 * signature, and it is convenient to nail them down here.                   *
 *---------------------------------------------------------------------------*)

local open KernelSig
in
val fun_tyid  = insert(typesig, {Thy = "min", Name = "fun"},  mk_arity 2:kind)
val bool_tyid = insert(typesig, {Thy = "min", Name = "bool"}, typ rho) (* rank 0 *)
val ind_tyid  = insert(typesig, {Thy = "min", Name = "ind"},  typ rho) (* rank 0 *)
val fun_tyc  = ( fun_tyid, mk_arity 2)
val bool_tyc = (bool_tyid, typ rho )
val ind_tyc  = ( ind_tyid, typ rho )
end

(*---------------------------------------------------------------------------
        Some basic values
 ---------------------------------------------------------------------------*)

val bool = TyCon bool_tyc
val ind  = TyCon ind_tyc;


fun same_tyconst (id1,_) (id2,_) = id1 = id2


(*---------------------------------------------------------------------------*
 * Computing the kind or rank of a type, assuming it is well-kinded.         *
 *---------------------------------------------------------------------------*)

local val max = Rank.max
      val suc = Rank.suc
      fun lookup 0 (kd::_)  = kd
        | lookup n (_::rst) = lookup (n-1) rst
        | lookup _ []       = raise ERR "kind_of" "lookup"
in
      fun kd_of (TyFv (_,kd)) _        = kd
        | kd_of (TyCon(_,kd)) _        = kd
        | kd_of (TyBv i) E             = lookup i E
(*      | kd_of (TyApp(opr,arg)) E     = snd (kind_dom_rng (kd_of opr E)) *)
(* or, if promotion, *)
        | kd_of (TyApp(opr,arg)) E     = let val (dom,rng) = kind_dom_rng (kd_of opr E)
                                             val argk = kd_of arg E
                                             val (kdS,rkS) = match_kind dom argk
                                             val _ = if null kdS then ()
                                                     else raise ERR "kind_of" "malformed type application"
                                             (* val rkS = [max(rank_of argk - rank_of dom, 0)] *)
                                         in Kind.inst_rank rkS rng
                                         end
        | kd_of (ty as TyAll _) E = typ (rk_of ty E) (* NOT kd_of Body (Kd::E) *)
        | kd_of (ty as TyExi _) E = typ (rk_of ty E) (* NOT kd_of Body (Kd::E) *)
        | kd_of (TyAbs((_,Kd),Body)) E = Kd ==> kd_of Body (Kd::E)
      and 
          rk_of (TyAll((_,kd),Body)) E = max (suc(rank_of kd), rk_of Body (kd::E)) (* mandatory *)
        | rk_of (TyExi((_,kd),Body)) E = max (suc(rank_of kd), rk_of Body (kd::E)) (* mandatory *)
     (* | rk_of (TyAbs((_,kd),Body)) E = max (rank_of kd,      rk_of Body (kd::E)) (* slight efficiency *) *)
        | rk_of ty E = rank_of (kd_of ty E)
fun kind_of ty = kd_of ty []
fun rank_of_type ty = rk_of ty []
end;

(* Note: these should be the same as
fun rk_of ty E = rank_of (kd_of ty E)
fun rank_of_type ty = rank_of (kind_of ty)
*)

fun rank_of_univ_dom (TyAll((_,kd),_)) = rank_of kd
  | rank_of_univ_dom _ = raise ERR "rank_of_univ_dom" "not a universal type"

fun rank_of_exist_dom (TyExi((_,kd),_)) = rank_of kd
  | rank_of_exist_dom _ = raise ERR "rank_of_exist_dom" "not an existential type"

(*---------------------------------------------------------------------------*
 * Computing the kind of a type, not assuming it is well-kinded.             *
 *---------------------------------------------------------------------------*)

local val max = Rank.max
      val suc = Rank.suc
      fun lookup 0 (kd::_)  = kd
        | lookup n (_::rst) = lookup (n-1) rst
        | lookup _ []       = raise ERR "check_kind_of" "lookup"
      fun kd_of (TyFv (_,kd)) _        = kd
        | kd_of (TyCon(_,kd)) _        = kd
        | kd_of (TyBv i) E             = lookup i E
        | kd_of (TyApp(opr,arg)) E     =
             let val (dom,rng) = kind_dom_rng (kd_of opr E)
                                 handle HOL_ERR _ =>
                     raise ERR "check_kind_of" "type is not well-kinded"
                 val kd_arg = kd_of arg E
                 (* val promote = max(rank_of kd_arg - rank_of dom, 0) *)
                 (* No automatic promotion! only at instantiation of constants *)
             in if not (dom :>=: kd_arg)
                then raise ERR "check_kind_of" "type is not well-kinded"
                else (* inst_rank promote *) rng
             end
        | kd_of (ty as TyAll _) E = typ (rk_of ty E) (* NOT kd_of Body (kd::E) *)
        | kd_of (ty as TyExi _) E = typ (rk_of ty E) (* NOT kd_of Body (kd::E) *)
        | kd_of (TyAbs((_,kd),Body)) E = kd ==> kd_of Body (kd::E)
      and 
          rk_of (TyAll((_,kd),Body)) E = max (suc(rank_of kd), rk_of Body (kd::E)) (* mandatory *)
        | rk_of (TyExi((_,kd),Body)) E = max (suc(rank_of kd), rk_of Body (kd::E)) (* mandatory *)
        | rk_of ty E = rank_of (kd_of ty E)
in
fun check_kind_of ty = kd_of ty []
fun check_rank_of ty = rk_of ty []
end;

(*---------------------------------------------------------------------------*
 * Checking that a type is well-kinded.                                      *
 * This fn should never be needed, as long as the type constructors check.   *
 *---------------------------------------------------------------------------*)

fun is_well_kinded ty = (check_kind_of ty; true) handle HOL_ERR _ => false


(*---------------------------------------------------------------------------
       Function types
 ---------------------------------------------------------------------------*)

(* mk_fun_type is for internal use only, with open types *)
(* Must instantiate the function type constant's rank
   to match the rank of its arguments. *)
fun mk_fun_type(X,Y) E = (* E is a environment of kinds of open bound type vars *)
  let (* val rkS = raw_match_rank rho (rk_of Y E) (match_rank rho (rk_of X E))
         val kd = Type (mk_rank rkS) *)
      val kd = Type (max(rk_of X E, rk_of Y E))
      val fun_tyc' = (fun_tyid, kd ==> kd ==> kd)
  in TyApp (TyApp (TyCon fun_tyc', X), Y)
  end;

infixr 3 -->;
fun (X --> Y) = if not (is_type_kind (kind_of X))
                  then raise ERR "-->" ("domain of --> needs kind ty, but was given kind "
                                        ^ kind_to_string (kind_of X))
                else if not (is_type_kind (kind_of Y))
                  then raise ERR "-->" ("range of --> needs kind ty, but was given kind "
                                        ^ kind_to_string (kind_of Y))
                else mk_fun_type(X,Y)[];

local
fun dom_of (TyApp(TyCon tyc, X)) =
      if same_tyconst tyc fun_tyc then X
      else raise ERR "dom_rng" "not a function type"
  | dom_of _ = raise ERR "dom_rng" "not a function type"
in
fun dom_rng (TyApp(funX, Y)) = (dom_of funX, Y)
  | dom_rng _ = raise ERR "dom_rng" "not a function type"
end;


(*-----------------------------------------------------------------------------*
 * The kind variables of a type. Tail recursive (from Ken Larsen).             *
 *-----------------------------------------------------------------------------*)

local fun kdV (TyFv(s,kd)) k         = k (Kind.kind_vars kd)
        | kdV (TyBv _) k             = k []
        | kdV (TyCon(s,kd)) k        = k (Kind.kind_vars kd)
        | kdV (TyApp(opr, arg)) k    = kdV arg (fn q1 =>
                                       kdV opr (fn q2 => k (union q2 q1)))
        | kdV (TyAll((s,kd),Body)) k = kdV Body (fn q =>
                                       k (union (Kind.kind_vars kd) q))
        | kdV (TyExi((s,kd),Body)) k = kdV Body (fn q =>
                                       k (union (Kind.kind_vars kd) q))
        | kdV (TyAbs((s,kd),Body)) k = kdV Body (fn q =>
                                       k (union (Kind.kind_vars kd) q))
      fun kdVs (t::ts) k             = kdV t (fn q1 =>
                                       kdVs ts (fn q2 => k (union q2 q1)))
        | kdVs [] k                  = k []
in
fun kind_vars ty = kdV ty Lib.I
fun kind_varsl tys = kdVs tys Lib.I
end;


(*---------------------------------------------------------------------------
                Discriminators
 ---------------------------------------------------------------------------*)

fun is_bvartype  (TyBv  _) = true | is_bvartype  _ = false;
fun is_vartype   (TyFv  _) = true | is_vartype   _ = false;
fun is_var_type  (TyFv  _) = true | is_var_type  _ = false;
fun is_con_type  (TyCon _) = true | is_con_type  _ = false;
fun is_type      (TyApp (opr,_)) = is_type opr
  | is_type      (TyCon _) = true
  | is_type      _ = false;
fun is_app_type  (TyApp _) = true
  | is_app_type  _ = false;
fun is_abs_type  (TyAbs _) = true
  | is_abs_type  _ = false;
fun is_univ_type (TyAll _) = true
  | is_univ_type _ = false;
fun is_exist_type (TyExi _) = true
  | is_exist_type _ = false;

(*---------------------------------------------------------------------------*
 * Types, as seen by the user, should satisfy exactly one of is_var_type,    *
 * is_con_type, is_app_type, is_abs_type, is_univ_type, or is_exist_type.    *
 * Legacy types will be seen as exactly one of is_vartype or is_type.        *
 *---------------------------------------------------------------------------*)


(*---------------------------------------------------------------------------*
 * Substituting kinds for kind variables of a type.                          *
 *---------------------------------------------------------------------------*)

fun prim_kind_of_tyc tyc =
  let open KernelSig
  in case peek(typesig,KernelSig.name_of_id tyc) of
        SOME (_,kd) => kd
      | NONE => raise ERR "prim_kind_of_tyc" "not a defined type constant"
  end

fun prim_kind_of {Thy,Tyop} =
  let open KernelSig
  in case peek(typesig,{Thy=Thy,Name=Tyop}) of
        SOME (_,kd) => kd
      | NONE => raise ERR "prim_kind_of" "not a defined type constant"
  end

(* Commenting out vacuum code:

local

fun strip_app_type ty =
   let fun strip (TyApp (Opr,Ty)) A = strip Opr (Ty::A)
         | strip ty A = (ty,A)
   in strip ty []
   end

fun make_app_type Opr Arg (fnstr,name) = TyApp(Opr,Arg)

fun list_make_app_type Opr Args (fnstr,name) =
    List.foldl (fn (Arg,acc) => make_app_type acc Arg (fnstr,name)) Opr Args

fun list_mk_app_type (Opr,Args) =
    list_make_app_type Opr Args ("list_mk_app_type","");

fun kinds_to_string (kd::kds) = " " ^ kind_to_string kd ^ "," ^ kinds_to_string kds
  | kinds_to_string    []     = ""

fun map_chg f [] = raise UNCHANGEDTY
  | map_chg f [ty] = [f ty]
  | map_chg f (ty::tys) =
      let val ty' = f ty (* may throw UNCHANGEDTY *)
          val tys' = map_chg f tys handle UNCHANGEDTY => tys
      in ty'::tys'
      end handle UNCHANGEDTY => (ty::map_chg f tys)

in

fun vacuum_opr E (opr,args) =
  if is_con_type opr then
    if null args then
      let
        val TyCon(tyc,kd) = opr (* kd will be replaced *)
val tyname = KernelSig.id_toString tyc
        val pkd = prim_kind_of_tyc tyc
        val _ = if pkd = kd then raise UNCHANGEDTY else ()
        val pkd_vars = Kind.kind_vars pkd
      in if null pkd_vars then raise ERR "vacuum_opr" ("no args: TyCon("^tyname^",pkd)") (* TyCon(tyc,pkd) *) (* set kind to primitive kind & rank *)
         else if null (Kind.kind_vars kd) then
            let (* match the primitive kind with the current kind *)
                val (rkS,kdS) = Kind.match_kind pkd kd
                (*val pkd_vars' = map (inst_rank rkS) pkd_vars*)
                fun orig_kdvar s = Lib.first (fn kd => #1(dest_var_kind kd) = s) pkd_vars
                fun revar kd = orig_kdvar (#1(dest_var_kind kd))
                fun revar_match {redex,residue} = {redex=revar redex, residue=residue}
                val kdS' = List.map revar_match kdS
                val kd' = Kind.inst_kind kdS' pkd
                val _ = if kd'=kd then raise UNCHANGEDTY else ()
            in raise ERR "vacuum_opr" ("no args: TyCon("^tyname^",kd')") (* TyCon(tyc,kd') *)
            end
         else raise UNCHANGEDTY (* opr *) (* unchanged when kind vars present *)
      end
      handle HOL_ERR _ => raise UNCHANGEDTY (* opr *) (* if eg, prim_kind_of fails *)
    else
      let
        val TyCon(tyc,kd) = opr (* kd will be replaced *)
val tyname = KernelSig.id_toString tyc
        val pkd = prim_kind_of_tyc tyc
        val _ = if pkd=kd then raise UNCHANGEDTY else ()
        (* val (c_rkS,c_kdS) = match_kind pkd kd *)
        val argkds = List.map (fn ty => kd_of ty E) args
        val (pargkds,reskd) = strip_arrow_kind pkd
        val pargkds0 = List.take(pargkds, length argkds)
        val (rkS,kdS) = match_kinds (List.map op |-> (zip pargkds0 argkds))
        (* val _ = assert null kdS *)
        val kd' = Kind.inst_rank_kind (kdS,rkS) pkd
        val _ = if kd'=kd then raise UNCHANGEDTY else ()
        val opr' = TyCon(tyc,kd')
      in
        raise ERR "vacuum_opr" (Int.toString(length args)^" args: TyCon("^tyname^",kd')") (* list_mk_app_type (opr', args) *)
      end
      handle e as HOL_ERR {origin_function="vacuum_opr",...} => Raise e (* if eg, prim_kind_of fails *)
           | HOL_ERR _ => list_mk_app_type (opr, args) (* if eg, prim_kind_of fails *)
  else raise ERR "vacuum_head" "head of type is not a constant type"

fun vacuum_head ty = vacuum_opr [] (strip_app_type ty) handle UNCHANGEDTY => ty

val vacuum =
  let fun vac E (ty as TyApp _) =
          let val (opr,args) = strip_app_type ty in
            let val args' = map_chg (vac E) args (* may throw UNCHANGEDTY *)
            in vacuum_opr E (opr,args')
               (* if opr is not a constant type, an exception is raised *)
               handle HOL_ERR {origin_function="vacuum_head",...} => (list_mk_app_type (vac E opr, args')
                                    handle UNCHANGEDTY => list_mk_app_type (opr, args'))
                    | UNCHANGEDTY => list_mk_app_type (opr, args')
            end
            handle UNCHANGEDTY => let
            in vacuum_opr E (opr,args)
               (* if opr is not a constant type, an exception is raised *)
               handle HOL_ERR {origin_function="vacuum_head",...} => list_mk_app_type (vac E opr, args)
            end
          end
        | vac E (opr as TyCon _) = vacuum_opr E (opr,[])
        | vac E (TyAll(Bvar as (_,kd),Body)) = TyAll(Bvar,vac (kd::E) Body)
        | vac E (TyExi(Bvar as (_,kd),Body)) = TyExi(Bvar,vac (kd::E) Body)
        | vac E (TyAbs(Bvar as (_,kd),Body)) = TyAbs(Bvar,vac (kd::E) Body)
        | vac _ ty = raise UNCHANGEDTY
  in fn ty => vac [] ty handle UNCHANGEDTY => ty
  end

end (* local *)

End of vacuum code. *)


(*---------------------------------------------------------------------------*
 * Increasing the rank of a type.                                            *
 *---------------------------------------------------------------------------*)

fun inst_rank 0 = Lib.I
  | inst_rank rkS =
  let val inst_kd = Kind.inst_rank rkS
      fun inst (TyFv (s,kd))        = TyFv (s,inst_kd kd)
        | inst (TyCon(s,kd))        = TyCon(s,inst_kd kd) (* current design DOES inst this kd's rank *)
        | inst (ty as TyBv _)       = ty
        | inst (TyApp(opr, ty))     = TyApp(inst opr,  inst ty)
        | inst (TyAll((s,kd),Body)) = TyAll((s,inst_kd kd), inst Body)
        | inst (TyExi((s,kd),Body)) = TyExi((s,inst_kd kd), inst Body)
        | inst (TyAbs((s,kd),Body)) = TyAbs((s,inst_kd kd), inst Body)
  in (* vacuum o *) inst
  end
  handle HOL_ERR{message=m,...} => raise ERR "inst_rank" m;


(*---------------------------------------------------------------------------*
 * Instantiating the kind variables of a type.                               *
 *---------------------------------------------------------------------------*)

fun inst_kind [] = Lib.I
  | inst_kind theta =
  let val subst = Kind.inst_kind theta
      fun inst (TyFv (s,kd))        = TyFv (s,subst kd)
        | inst (TyCon(s,kd))        = TyCon(s,subst kd)
        | inst (ty as TyBv _)       = ty
        | inst (TyApp(opr, arg))    = TyApp(inst opr, inst arg)
        | inst (TyAll((s,kd),Body)) = TyAll((s,subst kd), inst Body)
        | inst (TyExi((s,kd),Body)) = TyExi((s,subst kd), inst Body)
        | inst (TyAbs((s,kd),Body)) = TyAbs((s,subst kd), inst Body)
  in (* vacuum o *) inst
  end
  handle HOL_ERR{message=m,...} => raise ERR "inst_kind" m;

(*---------------------------------------------------------------------------*
 * Instantiating the rank variable and the kind variables of a type together.*
 * This is more efficient, as it makes a single traversal of the type.       *
 *---------------------------------------------------------------------------*)

fun inst_rank_kind (   [],rank) = (inst_rank rank
                                   handle HOL_ERR{message=m,...} => raise ERR "inst_rank_kind" m)
  | inst_rank_kind (theta,   0) = (inst_kind theta
                                   handle HOL_ERR{message=m,...} => raise ERR "inst_rank_kind" m)
  | inst_rank_kind (theta,rank) =
  let (*val subst = Kind.inst_kind theta*)
      val inst_kd = Kind.inst_rank_kind (theta,rank)
      fun inst (TyFv (s,kd))        = TyFv (s,inst_kd kd)
        | inst (TyCon(s,kd))        = TyCon(s,inst_kd (*subst*) kd) (* current design DOES inst this kd's rank *)
        | inst (ty as TyBv _)       = ty
        | inst (TyApp(opr, ty))     = TyApp(inst opr, inst ty)
        | inst (TyAll((s,kd),Body)) = TyAll((s,inst_kd kd), inst Body)
        | inst (TyExi((s,kd),Body)) = TyExi((s,inst_kd kd), inst Body)
        | inst (TyAbs((s,kd),Body)) = TyAbs((s,inst_kd kd), inst Body)
  in (* vacuum o *) inst
  end
  handle HOL_ERR{message=m,...} => raise ERR "inst_rank_kind" m;


(*---------------------------------------------------------------------------*
 * The free type variables in a type.  Tail recursive (from Ken Larsen).     *
 *---------------------------------------------------------------------------*)

local fun TV (v as TyFv _) A k    = k (Lib.insert v A)
        | TV (TyApp(opr,arg)) A k = TV opr A (fn q => TV arg q k)
        | TV (TyAll(_,body)) A k  = TV body A k
        | TV (TyExi(_,body)) A k  = TV body A k
        | TV (TyAbs(_,body)) A k  = TV body A k
        | TV _ A k = k A
      and TVl (ty::tys) A k       = TV ty A (fn q => TVl tys q k)
        | TVl _ A k = k A
in
fun type_vars ty = rev(TV ty [] Lib.I)
fun type_varsl L = rev(TVl L [] Lib.I)
end;

(*---------------------------------------------------------------------------*
 * All the type variables in a type.  Tail recursive (from Ken Larsen).      *
 *---------------------------------------------------------------------------*)

local fun ATV (v as TyFv _) A k    = k (Lib.insert v A)
        | ATV (TyApp(opr,arg)) A k = ATV opr A (fn q => ATV arg q k)
        | ATV (TyAll(bv,body)) A k = ATV (TyFv bv) A (fn q => ATV body q k)
        | ATV (TyExi(bv,body)) A k = ATV (TyFv bv) A (fn q => ATV body q k)
        | ATV (TyAbs(bv,body)) A k = ATV (TyFv bv) A (fn q => ATV body q k)
        | ATV _ A k = k A
      and ATVl (ty::tys) A k       = ATV ty A (fn q => ATVl tys q k)
        | ATVl _ A k = k A
in
fun all_type_vars ty = rev(ATV ty [] Lib.I)
fun all_type_varsl L = rev(ATVl L [] Lib.I)
end;

(*---------------------------------------------------------------------------*
 * The free type variables of a type, in textual order.                      *
 *---------------------------------------------------------------------------*)

fun type_vars_lr ty =
  let fun TV ((v as TyFv _)::t) A   = TV t (Lib.insert v A)
        | TV (TyApp(opr,arg)::t) A  = TV (opr::arg::t) A
        | TV (TyAll(_,body)::t) A   = TV (body::t) A
        | TV (TyExi(_,body)::t) A   = TV (body::t) A
        | TV (TyAbs(_,body)::t) A   = TV (body::t) A
        | TV (_::t) A = TV t A
        | TV [] A = rev A
  in
     TV [ty] []
  end;


(*---------------------------------------------------------------------------
     Support for efficient sets of type variables
 ---------------------------------------------------------------------------*)

(* val kind_rank_compare = Lib.pair_compare(kind_compare, Int.compare); *)

fun tyvar_compare ((s1,k1), (s2,k2)) =
       (case String.compare (s1,s2)
         of EQUAL => kind_compare (k1,k2)
          | x => x)

fun tyvar_ge ((s1,k1), (s2,k2)) =
       (s1 = s2) andalso k1 :>=: k2

val empty_tyvarset = HOLset.empty tyvar_compare
fun tyvar_eq t1 t2 = tyvar_compare(t1,t2) = EQUAL;

fun type_var_compare (TyFv u, TyFv v) = tyvar_compare (u,v)
  | type_var_compare _ = raise ERR "type_var_compare" "variables required";

fun type_var_ge (TyFv u, TyFv v) = tyvar_ge (u,v)
  | type_var_ge _ = raise ERR "type_var_ge" "variables required";

(*
fun tyvar_subtype ((s1,k1), (s2,k2)) =
       (s1 = s2) andalso (k1 = k2) andalso (rk1 <= rk2)

fun type_var_subtype (TyFv u, TyFv v) = tyvar_subtype (u,v)
  | type_var_subtype _ = raise ERR "type_var_subtype" "variables required";
*)

fun type_con_compare (TyCon(c1,k1), TyCon(c2,k2)) =
       (case KernelSig.id_compare (c1,c2)
         of EQUAL => (* kind_compare *) tycon_kind_compare (k1,k2)
          | x => x)
  | type_con_compare _ =raise ERR "type_con_compare" "constants required";

fun type_con_ge (TyCon(c1,k1), TyCon(c2,k2)) =
       (case KernelSig.id_compare (c1,c2)
         of EQUAL => k1 :=: (* :>=: *) k2
          | x => false)
  | type_con_ge _ =raise ERR "type_con_ge" "constants required";

fun prim_type_con_compare (TyCon(c1,k1), TyCon(c2,k2)) =
       (case KernelSig.id_compare (c1,c2)
         of EQUAL => kind_compare (k1,k2)
          | x => x)
  | prim_type_con_compare _ =raise ERR "prim_type_con_compare" "constants required";

(* ----------------------------------------------------------------------
    A total ordering on types that respects alpha equivalence.
    TyFv < TyBv < TyCon < TyApp < TyAll < TyExi < TyAbs
    except that when comparing types where some are type applications,
    for backwards compatibility with HOL4, the heads of the application trees
    are compared first, and then the arguments, in order.
   ---------------------------------------------------------------------- *)

fun strip_app_type ty =
   let fun strip (TyApp (Opr,Ty)) A = strip Opr (Ty::A)
         | strip ty A = (ty,A)
   in strip ty []
   end

fun compare p =
    if Portable.pointer_eq p then EQUAL else
    case p of
      (_, TyApp _)                 => app_type_compare p
    | (TyApp _, _)                 => app_type_compare p
    | (u as TyFv _, v as TyFv _)   => type_var_compare (u,v)
    | (TyFv _, _)                  => LESS
    | (TyBv _, TyFv _)             => GREATER
    | (TyBv i, TyBv j)             => Int.compare (i,j)
    | (TyBv _, _)                  => LESS
    | (TyCon _, TyFv _)            => GREATER
    | (TyCon _, TyBv _)            => GREATER
    | (u as TyCon _, v as TyCon _) => type_con_compare (u,v)
    | (TyCon _, _)                 => LESS
    | (TyAll _, TyAbs _)           => LESS
    | (TyAll _, TyExi _)           => LESS
    | (TyAll((_,k1),ty1),
       TyAll((_,k2),ty2))          =>
                                 Lib.pair_compare(kind_compare,compare)
                                                 ((k1,ty1),(k2,ty2))
    | (TyAll _, _)                 => GREATER
    | (TyExi _, TyAbs _)           => LESS
    | (TyExi((_,k1),ty1),
       TyExi((_,k2),ty2))          =>
                                 Lib.pair_compare(kind_compare,compare)
                                                 ((k1,ty1),(k2,ty2))
    | (TyExi _, _)                 => GREATER
    | (TyAbs((_,k1),ty1),
       TyAbs((_,k2),ty2))          =>
                                 Lib.pair_compare(kind_compare,compare)
                                                 ((k1,ty1),(k2,ty2))
    | (TyAbs _, _)                 => GREATER

and app_type_compare (t1,t2) =
  let val (h1,a1) = strip_app_type t1
      val (h2,a2) = strip_app_type t2
  in case compare (h1,h2)
      of EQUAL => Lib.list_compare compare (a1,a2)
       |   x   => x
  end
;

fun prim_compare p =
    if Portable.pointer_eq p then EQUAL else
    case p of
      (u as TyFv _, v as TyFv _)   => type_var_compare (u,v)
    | (TyFv _, _)                  => LESS
    | (TyBv _, TyFv _)             => GREATER
    | (TyBv i, TyBv j)             => Int.compare (i,j)
    | (TyBv _, _)                  => LESS
    | (TyCon _, TyFv _)            => GREATER
    | (TyCon _, TyBv _)            => GREATER
    | (u as TyCon _, v as TyCon _) => prim_type_con_compare (u,v)
    | (TyCon _, _)                 => LESS
    | (TyApp _, TyFv _)            => GREATER
    | (TyApp _, TyBv _)            => GREATER
    | (TyApp _, TyCon _)           => GREATER
    | (TyApp p1, TyApp p2)         => Lib.pair_compare(prim_compare,prim_compare)(p1,p2)
    | (TyApp _, _)                 => LESS
    | (TyAll _, TyAbs _)           => LESS
    | (TyAll _, TyExi _)           => LESS
    | (TyAll((_,k1),ty1),
       TyAll((_,k2),ty2))          =>
                                 Lib.pair_compare(kind_compare,prim_compare)
                                                 ((k1,ty1),(k2,ty2))
    | (TyAll _, _)                 => GREATER
    | (TyExi _, TyAbs _)           => LESS
    | (TyExi((_,k1),ty1),
       TyExi((_,k2),ty2))          =>
                                 Lib.pair_compare(kind_compare,prim_compare)
                                                 ((k1,ty1),(k2,ty2))
    | (TyExi _, _)                 => GREATER
    | (TyAbs((_,k1),ty1),
       TyAbs((_,k2),ty2))          =>
                                 Lib.pair_compare(kind_compare,prim_compare)
                                                 ((k1,ty1),(k2,ty2))
    | (TyAbs _, _)                 => GREATER
;

val empty_tyset = HOLset.empty compare
fun type_eq t1 t2 = compare(t1,t2) = EQUAL;


(*---------------------------------------------------------------------------
        Free type variables of a type. Tail recursive. Returns a set.
 ---------------------------------------------------------------------------*)

fun TVL [] A = A
  | TVL ((v as TyFv _)::rst) A   = TVL rst (HOLset.add(A,v))
  | TVL (TyApp(opr,ty)::rst) A   = TVL (opr::ty::rst) A
  | TVL (TyAll(_,Body)::rst) A   = TVL (Body::rst) A
  | TVL (TyExi(_,Body)::rst) A   = TVL (Body::rst) A
  | TVL (TyAbs(_,Body)::rst) A   = TVL (Body::rst) A
  | TVL (_::rst) A = TVL rst A

fun type_vars ty = HOLset.listItems (TVL [ty] empty_tyset)
fun type_varsl tys = HOLset.listItems (TVL tys empty_tyset);

(* ----------------------------------------------------------------------
    type_var_in ty TY : does ty occur free in TY?
   ---------------------------------------------------------------------- *)

fun type_var_in ty =
   let fun f1 (TyApp(opr,ty)) = (f2 opr) orelse (f2 ty)
         | f1 (TyAll(_,Body)) = f2 Body
         | f1 (TyExi(_,Body)) = f2 Body
         | f1 (TyAbs(_,Body)) = f2 Body
         | f1 _ = false
       and f2 t = type_eq t ty orelse f1 t
   in f2
   end;


(*---------------------------------------------------------------------------*
 *         Type variables                                                    *
 *---------------------------------------------------------------------------*)

val alpha  = TyFv ("'a", Type rho)
val beta   = TyFv ("'b", Type rho)
val gamma  = TyFv ("'c", Type rho)
val delta  = TyFv ("'d", Type rho)
val etyvar = TyFv ("'e", Type rho)
val ftyvar = TyFv ("'f", Type rho)

val varcomplain = ref true
val _ = register_btrace ("Vartype Format Complaint", varcomplain)

fun mk_var_type ("'a", Type 0) = alpha
  | mk_var_type ("'b", Type 0) = beta
  | mk_var_type ("'c", Type 0) = gamma
  | mk_var_type ("'d", Type 0) = delta
  | mk_var_type ("'e", Type 0) = etyvar
  | mk_var_type ("'f", Type 0) = ftyvar
  | mk_var_type (s, kind) =
                if Lexis.allowed_user_type_var s
                then TyFv (s, kind)
                else (if !varcomplain then
                        WARN "mk_var_type" ("non-standard syntax: " ^ s)
                      else (); TyFv (s, kind))

fun mk_vartype s = mk_var_type (s, Type rho);

fun inST s = let
  fun foldthis({Thy,Name},_,acc) = (acc orelse (Name = s))
in
  KernelSig.foldl foldthis false typesig
end

fun mk_primed_var_type (Name, Kind) =
  let val next = Lexis.tyvar_vary
      fun spin s = if inST s then spin (next s) else s
  in mk_var_type(spin Name, Kind)
  end;

fun mk_primed_vartype s = mk_primed_var_type (s, Type rho);

(*---------------------------------------------------------------------------*
 *   "gen_tyvars" are a Lisp-style "gensym" for HOL variables.               *
 *---------------------------------------------------------------------------*)

local val gen_tyvar_prefix = "%%gen_tyvar%%"
      fun num2name i = gen_tyvar_prefix^Lib.int_to_string i
      val nameStrm = Lib.mk_istream (fn x => x+1) 0 num2name
in
fun gen_var_type Kind =
       TyFv(state(next nameStrm), Kind)
fun gen_tyvar () = gen_var_type (Type rho)

fun is_gen_tyvar (TyFv(Name,_)) =
        String.isPrefix gen_tyvar_prefix Name
  | is_gen_tyvar _ = false
end;


(*---------------------------------------------------------------------------*
 * Given a type variable and a list of type variables, if the type variable  *
 * does not exist on the list, then return the type variable. Otherwise,     *
 * rename the type variable and try again. Note well that the variant uses   *
 * only the name of the variable as a basis for testing equality. Experience *
 * has shown that basing the comparison on all of the name, the arity, the   *
 * rank, and the type arguments of the variable resulted in needlessly       *
 * confusing formulas occasionally being displayed in interactive sessions.  *
 *---------------------------------------------------------------------------*)

fun gen_variant P caller =
  let fun var_name (TyFv(Name,_)) = Name
        | var_name _ = raise ERR caller "not a variable"
      fun vary vlist (TyFv(Name,Kind)) =
          let val L = map var_name vlist
              val next = Lexis.gen_variant Lexis.tyvar_vary L
              fun loop name =
                 let val s = next name
                 in if P s then loop s else s
                 end
          in trace ("Vartype Format Complaint",0) mk_var_type(loop Name, Kind)
          end
        | vary _ _ = raise ERR caller "2nd argument should be a type variable"
  in vary
  end;

val variant_type       = gen_variant inST "variant_type"
val prim_variant_type  = gen_variant (K false) "prim_variant_type";



fun dest_var_type (TyFv (s,kind)) = (s,kind)
  | dest_var_type _ = raise ERR "dest_var_type" "not a type variable";

fun dest_vartype (TyFv (s,Type 0)) = s
  | dest_vartype (TyFv (s,Type rank)) =
           raise ERR "dest_vartype" "non-zero rank - use dest_var_type"
  | dest_vartype (TyFv (s,_)) =
           raise ERR "dest_vartype" "type operator kind - use dest_var_type"
  | dest_vartype _ = raise ERR "dest_vartype" "not a type variable";

(*
dest_vartype ty10;
dest_vartype ty11;
*)


fun variant_tyvar tys tyv =
       let val ty0 = TyFv tyv
           val ty = variant_type tys ty0
        in dest_var_type ty
       end;

(*---------------------------------------------------------------------------*
 * Create a compound type, in a specific segment, and in the current theory. *
 *---------------------------------------------------------------------------*)

local
fun dest_con_type (TyCon (tyc,kd)) = (KernelSig.name_of tyc,kd)
  | dest_con_type _ = raise ERR "dest_con_type" "not a constant type";

fun namestr nm Opr = if nm <> "" then nm
                 else if is_con_type Opr then #1(dest_con_type Opr)
                 else if is_var_type Opr then #1(dest_var_type Opr)
                 else "type"
in
fun make_app_type Opr Arg (fnstr,name) =
  let val (dom,rng) = kind_dom_rng (kind_of Opr)
                      handle HOL_ERR e =>
                        raise ERR fnstr (String.concat
         ["type not well-kinded: ", namestr name Opr,
          " is not a type operator, but is applied as one:\n",
          #origin_structure e, ".", #origin_function e, ":\n", #message e])
      val kd = kind_of Arg
  in if dom :>=: kd then TyApp(Opr,Arg) else
     raise ERR fnstr (String.concat
         ["type not well-kinded: operator ", namestr name Opr, " needs kind ", kind_to_string dom,
          ", but was given kind ", kind_to_string kd])
  end
end;

fun list_make_app_type Opr Args (fnstr,name) =
    List.foldl (fn (Arg,acc) => make_app_type acc Arg (fnstr,name)) Opr Args

fun make_type tyc Args (fnstr,name) =
  (* vacuum_head *) (list_make_app_type (TyCon tyc) Args (fnstr,name));

(* fun mk_tyconst (id,kind) = (id,kind) :tyconst *)

fun argkds_string [] = "..."
  | argkds_string (arg::args) = "(" ^ kind_to_string (kind_of arg) ^ ") => " ^ argkds_string args

fun mk_thy_type {Thy,Tyop,Args} = let
  open KernelSig
  val knm = {Thy=Thy, Name = Tyop}
in
  case peek(typesig, {Thy=Thy,Name=Tyop}) of
    SOME const =>
      let val (c_id,prim_kd) = const
          val (argkds,reskd) = strip_arrow_kind prim_kd
          val argkds0 = List.take(argkds, length Args)
                        handle Subscript => raise ERR "mk_thy_type"
                               ("too many arguments to type operator "^Thy^"$"^Tyop)
          val (kdS,rkS) = match_kinds (map op |-> (zip argkds0 (map kind_of Args))) (* can fail *)
                          handle HOL_ERR e => raise ERR "mk_thy_type"
                                 ("the type operator "^Thy^"$"^Tyop^
                                  " cannot have kind "^argkds_string Args)
          val kd' = Kind.inst_rank_kind (kdS,rkS) prim_kd
          val const' = (c_id,kd')
       in
                  make_type const' Args
                            ("mk_thy_type", name_toString knm)
       end
  | NONE => raise ERR "mk_thy_type"
                      ("the type operator "^quote Tyop^
                       " has not been declared in theory "^quote Thy^".")
end

fun prim_mk_thy_con_type {Thy,Tyop} = let
  open KernelSig
in
  case peek(typesig,{Thy=Thy,Name=Tyop}) of
    SOME const => TyCon const
  | NONE => raise ERR "mk_thy_con_type"
                ("the type operator "^quote Tyop^
                 " has not been declared in theory "^quote Thy^".")
end

fun mk_thy_con_type {Thy,Tyop,Kind} = let
  open KernelSig
in
  case peek(typesig,{Thy=Thy,Name=Tyop}) of
    SOME (const as (id,kind0)) =>
           (let val (kdS,rkS) = Kind.match_kind kind0 Kind
                val Kind' = Kind.inst_rank_kind (kdS,rkS) kind0
            in TyCon (id,Kind')
            end handle HOL_ERR _ =>
                raise ERR "mk_thy_con_type"
                            ("Not a kind instance: the type operator "^id_toString id^
                             " cannot have kind "^Kind.kind_to_string Kind^"."))
  | NONE => raise ERR "mk_thy_con_type"
                ("the type operator "^quote Tyop^
                 " has not been declared in theory "^quote Thy^".")
end

fun decls nm = let
  fun foldthis({Thy,Name},_,acc) = if Name = nm then
                                     {Tyop=Name,Thy=Thy} :: acc
                                   else acc
in
  KernelSig.foldl foldthis [] typesig
end

local
  fun first_decl Tyop = let
    fun foldthis({Thy,Name},tycon,acc) =
        if Name = Tyop then tycon :: acc
        else acc
  in
    case KernelSig.foldl foldthis [] typesig of
      [] => raise ERR "mk_con_type" (Lib.quote Tyop^" has not been declared")
    | [c] => c
    | c::_ => (WARN "mk_type" "more than one possibility"; c)
  end
in

fun prim_mk_con_type Tyop = TyCon (first_decl Tyop);

fun mk_con_type (Tyop,Kind) = let
  open KernelSig
  val c = prim_mk_con_type Tyop
  val (id,Kind0) = case c of TyCon p => p
                           | _ => raise ERR "mk_con_type" "impossible"
in
  if can (Kind.match_kind Kind0) Kind
     then TyCon (id,Kind)
     else raise ERR "mk_con_type"
                  ("Not a kind instance: the type operator "^id_toString id^
                   " cannot have kind "^Kind.kind_to_string Kind^".")
end;

fun mk_app_type (Opr,Arg) = make_app_type Opr Arg ("mk_app_type","");

fun list_mk_app_type (Opr,Args) =
    list_make_app_type Opr Args ("list_mk_app_type","");

fun mk_type (Tyop,Args) =
      let val (c_id,prim_kd) = first_decl Tyop
          val (argkds,reskd) = strip_arrow_kind prim_kd
          val argkds0 = List.take(argkds, length Args)
                        handle Subscript => raise ERR "mk_type"
                               ("too many arguments to type operator "^quote Tyop)
          val (kdS,rkS) = match_kinds (map op |-> (zip argkds0 (map kind_of Args))) (* can fail *)
                          handle HOL_ERR e => raise ERR "mk_type"
                                 ("the type operator "^quote Tyop^
                                  " cannot have kind "^argkds_string Args)
          val kd' = Kind.inst_rank_kind (kdS,rkS) prim_kd
          val const' = (c_id,kd')
       in
         make_type const' Args ("mk_type",Tyop)
       end;
end

(*
prim_mk_con_type "fun";
mk_con_type ("fun", mk_arity 2);
mk_type("fun",[alpha,beta]);
mk_type("bool",[]);
mk_app_type(prim_mk_con_type "fun", prim_mk_con_type "bool");
mk_app_type(prim_mk_con_type "fun", prim_mk_con_type "fun"); (* fails *)
mk_type("fun",[foo,bar]); (* fails *)
mk_type("fun",[alpha,bar]); (* fails *)
mk_app_type(mk_app_type(prim_mk_con_type "fun", prim_mk_con_type "ind"),
            prim_mk_con_type "bool");
val ty12 =
   list_mk_app_type(prim_mk_con_type "fun",
                    [prim_mk_con_type "ind",prim_mk_con_type "bool"]);
*)

(*---------------------------------------------------------------------------*
 * Take a (TyApp(TyCon)) type apart.                                         *
 *---------------------------------------------------------------------------*)

local open KernelTypes KernelSig
fun break_ty0 f acc (TyCon c) = (c,acc)
  | break_ty0 f acc (TyApp (Opr,Arg)) = break_ty0 f (Arg::acc) Opr
  | break_ty0 f _ _ = raise ERR f "not a sequence of type applications of a \
                                  \type constant"
fun break_ty f ty = break_ty0 f [] ty
(*
fun check_kd_rk f kd =
   let val s = "; use " ^ quote (f ^ "_opr") ^ " instead."
   in if is_arity kd    then () else raise ERR f ("kind of type operator is not an arity" ^ s);
      if rank_of kd = 0 then () else raise ERR f ("rank of type operator is not zero" ^ s)
   end
*)
in
fun break_type ty = break_ty "break_type" ty;

fun dest_thy_type_opr ty =
       let val ((tyc,kd),A) = break_ty "dest_thy_type_opr" ty
       in
        {Thy=seg_of tyc,Tyop=name_of tyc,Kind=kd,Args=A}
       end;

fun dest_thy_type ty =
       let val ((tyc,kd),A) = break_ty "dest_thy_type" ty
           (* val _ = check_kd_rk "dest_thy_type" kd rk *)
       in
        {Thy=seg_of tyc,Tyop=name_of tyc,Args=A}
       end;

fun dest_type_opr ty =
       let val ((tyc,kd),A) = break_ty "dest_type_opr" ty
       in (name_of tyc, kd, A)
       end;

fun dest_type ty =
       let val ((tyc,kd),A) = break_ty "dest_type" ty
           (* val _ = check_kd_rk "dest_type" kd rk *)
       in (name_of tyc, A)
       end;
end;

fun dest_con_type (TyCon (tyc,kd)) = (KernelSig.name_of tyc,kd)
  | dest_con_type _ = raise ERR "dest_con_type" "not a constant type";

fun dest_thy_con_type (TyCon (tyc,kd)) =
      {Thy=KernelSig.seg_of tyc,Tyop=KernelSig.name_of tyc,Kind=kd}
  | dest_thy_con_type _ = raise ERR "dest_thy_con_type" "not a constant type";

fun dest_bool ty = let val {Thy,Tyop,Kind} = dest_thy_con_type ty
                   in if Tyop = "bool" andalso Thy = "min" then Kind.dest_type_kind Kind
                      else raise ERR "" ""
                   end handle HOL_ERR _ => raise ERR "dest_bool" "not a bool type"

val is_bool = can dest_bool

fun dest_app_type (TyApp (Opr,Ty)) = (Opr,Ty)
  | dest_app_type _ = raise ERR "dest_app_type" "not a type application";

(*
dest_thy_type_opr ty12;
dest_thy_type ty12;
dest_type_opr ty12;
dest_type ty12;
*)

(*---------------------------------------------------------------------------*
 * Return kind or arity of putative type operator                            *
 *---------------------------------------------------------------------------*)

fun op_kind {Thy,Tyop} =
    case KernelSig.peek(typesig,{Thy=Thy,Name=Tyop}) of
      SOME (id, kind) => SOME kind
    | NONE => NONE

fun op_arity r = case op_kind r
                  of SOME kind => (SOME (arity_of kind)
                                   handle HOL_ERR _ => NONE)
                   | NONE      => NONE

(*---------------------------------------------------------------------------*
 * Return rank of putative type operator                                     *
 *---------------------------------------------------------------------------*)

fun op_rank r = case op_kind r
                  of SOME kind => SOME (rank_of kind)
                   | NONE      => NONE

(*---------------------------------------------------------------------------
       Declared types in a theory segment
 ---------------------------------------------------------------------------*)

fun thy_types s = let
  fun xlate (knm, (id,kind)) =
        (KernelSig.name_of id, arity_of kind handle HOL_ERR _ =>
                raise ERR "thy_types" "non-arity kind in theory - use thy_type_oprs"
        )
in
  map xlate (KernelSig.listThy typesig s)
end;

fun thy_type_oprs s = let
  fun xlate (knm, (id,kind)) =
            (KernelSig.name_of id, kind)
  in map xlate (KernelSig.listThy typesig s)
  end;

(*---------------------------------------------------------------------------*
 *                  Alpha conversion                                         *
 *---------------------------------------------------------------------------*)

fun rename_btyvar s t =
    case t of
      TyAll((_, kind), Body) => TyAll((s, kind), Body)
    | TyExi((_, kind), Body) => TyExi((s, kind), Body)
    | TyAbs((_, kind), Body) => TyAbs((s, kind), Body)
    | _ => raise ERR "rename_btyvar" "not a universal type or existential type or type abstraction";


local val EQ = Portable.pointer_eq
in
fun aconv_ty t1 t2 = EQ(t1,t2) orelse
 case(t1,t2)
  of (u as TyFv _, v as TyFv _ ) => type_var_compare(u,v) = EQUAL
   | (u as TyCon _,v as TyCon _) => type_con_compare(u,v) = EQUAL
   | (TyApp(p,t1),TyApp(q,t2)) => aconv_ty p q andalso aconv_ty t1 t2
   | (TyAll((_,k1),t1),
      TyAll((_,k2),t2)) => k1 = k2 andalso aconv_ty t1 t2
   | (TyExi((_,k1),t1),
      TyExi((_,k2),t2)) => k1 = k2 andalso aconv_ty t1 t2
   | (TyAbs((_,k1),t1),
      TyAbs((_,k2),t2)) => k1 = k2 andalso aconv_ty t1 t2
   | (M,N)       => (M=N)
end;

local val EQ = Portable.pointer_eq
in
fun aconv_ge_ty t1 t2 = EQ(t1,t2) orelse
 case(t1,t2)
  of (u as TyFv _, v as TyFv _ ) => type_var_ge(u,v)
   | (u as TyCon _,v as TyCon _) => type_con_ge(u,v)
   | (TyApp(p,t1),TyApp(q,t2)) => aconv_ge_ty p q andalso aconv_ge_ty t1 t2
   | (TyAll((_,k1),t1),
      TyAll((_,k2),t2)) => k1 :>=: k2 andalso aconv_ge_ty t1 t2
   | (TyExi((_,k1),t1),
      TyExi((_,k2),t2)) => k1 :>=: k2 andalso aconv_ge_ty t1 t2
   | (TyAbs((_,k1),t1),
      TyAbs((_,k2),t2)) => k1 :>=: k2 andalso aconv_ge_ty t1 t2
   | (M,N) => (M=N)
end;

(*
local val EQ = Portable.pointer_eq
in
fun asubtype t1 t2 = EQ(t1,t2) orelse
 case(t1,t2)
  of (u as TyFv _, v as TyFv _ ) => type_var_subtype(u,v)
   | (u as TyCon _,v as TyCon _) => type_con_compare(u,v) = EQUAL
   | (TyApp(p,t1),TyApp(q,t2)) => asubtype p q andalso asubtype t1 t2
   | (TyAll((_,k1,r1),t1),
      TyAll((_,k2,r2),t2)) => k1 = k2 andalso r1 <= r2 andalso asubtype t1 t2
   | (TyExi((_,k1,r1),t1),
      TyExi((_,k2,r2),t2)) => k1 = k2 andalso r1 <= r2 andalso asubtype t1 t2
   | (TyAbs((_,k1,r1),t1),
      TyAbs((_,k2,r2),t2)) => k1 = k2 andalso r1 <= r2 andalso asubtype t1 t2
   | (M,N)       => (M=N)
end;
*)


(*---------------------------------------------------------------------------*
 * Universal types                                                           *
 *---------------------------------------------------------------------------*)

(*---------------------------------------------------------------------------
       Making universal types. list_mk_type_binder is a relatively
       efficient version for making types with many consecutive
       universal type quantifications.
  ---------------------------------------------------------------------------*)

local val FORMAT = ERR "list_mk_univ_type_binder"
   "expected first arg to be a type constant of kind ::(<kd>_1 => <kd>_2) => <kd>_3"
   fun check_opt NONE = Lib.I
     | check_opt (SOME c) = (* (fn abs => mk_app_type (c, abs)) *)
       (* or, *)
        if not(is_con_type c) then raise FORMAT
        else case total (fst o kind_dom_rng o fst o kind_dom_rng o kind_of) c
              of NONE => raise FORMAT
               | SOME kn => (fn abs =>
                   let val dom = fst(kind_dom_rng(kind_of abs))
                   in mk_app_type ( inst_kind[kn |-> dom] c, abs)
                   end)
       (**)
in
fun list_mk_univ_type_binder opt caller =
 let val f = check_opt opt
 in fn (vlist,ty)
 => if not (all is_vartype vlist) then raise ERR caller "bound variable arg not a type variable"
    else if not (is_type_kind (kind_of ty)) then raise ERR caller
                                                  "kind of body is not the base kind"
    else
  let open Redblackmap
     val varmap0 = mkDict tyvar_compare
     fun enum [] _ A = A
       | enum (TyFv h::t) i (vmap,rvs) = enum t (i-1) (insert (vmap,h,i), h::rvs)
       | enum _ _ _ = raise ERR "enum" "non-variable given as bound variable"
     val (varmap, rvlist) = enum vlist (length vlist - 1) (varmap0,[])
     fun lookup v vmap = case peek (vmap,v) of NONE => TyFv v | SOME i => TyBv i
     fun increment vmap = transform (fn x => x+1) vmap
     fun bind (TyFv v) vmap k = k (lookup v vmap)
       | bind (TyApp(opr,ty)) vmap k = bind opr vmap (fn opr' =>
                                       bind ty  vmap (fn ty'  =>
                                          k (TyApp(opr',ty'))))
       | bind (TyAll(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyAll(a,q)))
       | bind (TyExi(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyExi(a,q)))
       | bind (TyAbs(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyAbs(a,q)))
       | bind t vmap k = k t
  in
     rev_itlist (fn v => fn B => f(TyAll(v,B))) rvlist (bind ty varmap I)
  end
  handle e => raise wrap_exn "Type" "list_mk_univ_type_binder" e
 end
end;

val list_mk_univ_type = list_mk_univ_type_binder NONE "list_mk_univ_type";

fun mk_univ_type (Bvar as TyFv tyvar, Body) =
    let fun bind (TyFv v) i            = if v=tyvar then TyBv i else TyFv v
          | bind (TyApp(opr,ty)) i     = TyApp(bind opr i, bind ty i)
          | bind (TyAll(Bvar,Body)) i  = TyAll(Bvar, bind Body (i+1))
          | bind (TyExi(Bvar,Body)) i  = TyExi(Bvar, bind Body (i+1))
          | bind (TyAbs(Bvar,Body)) i  = TyAbs(Bvar, bind Body (i+1))
          | bind t _ = t
    in
      if is_type_kind (kind_of Body) then TyAll(tyvar, bind Body 0)
      else raise ERR "mk_univ_type" "kind of body is not the base kind"
    end
  | mk_univ_type _ = raise ERR "mk_univ_type" "bound variable arg not a variable";


(*---------------------------------------------------------------------------*
 * Existential types                                                           *
 *---------------------------------------------------------------------------*)

(*---------------------------------------------------------------------------
       Making existential types. list_mk_type_binder is a relatively
       efficient version for making types with many consecutive
       existential type quantifications.
  ---------------------------------------------------------------------------*)

local val FORMAT = ERR "list_mk_exist_type_binder"
   "expected first arg to be a type constant of kind ::(<kd>_1 => <kd>_2) => <kd>_3"
   fun check_opt NONE = Lib.I
     | check_opt (SOME c) = (* (fn abs => mk_app_type (c, abs)) *)
       (* or, *)
        if not(is_con_type c) then raise FORMAT
        else case total (fst o kind_dom_rng o fst o kind_dom_rng o kind_of) c
              of NONE => raise FORMAT
               | SOME kn => (fn abs =>
                   let val dom = fst(kind_dom_rng(kind_of abs))
                   in mk_app_type ( inst_kind[kn |-> dom] c, abs)
                   end)
       (**)
in
fun list_mk_exist_type_binder opt caller =
 let val f = check_opt opt
 in fn (vlist,ty)
 => if not (all is_vartype vlist) then raise ERR caller "bound variable arg not a type variable"
    else if not (is_type_kind (kind_of ty)) then raise ERR caller
                                                  "kind of body is not the base kind"
    else
  let open Redblackmap
     val varmap0 = mkDict tyvar_compare
     fun enum [] _ A = A
       | enum (TyFv h::t) i (vmap,rvs) = enum t (i-1) (insert (vmap,h,i), h::rvs)
       | enum _ _ _ = raise ERR "enum" "non-variable given as bound variable"
     val (varmap, rvlist) = enum vlist (length vlist - 1) (varmap0,[])
     fun lookup v vmap = case peek (vmap,v) of NONE => TyFv v | SOME i => TyBv i
     fun increment vmap = transform (fn x => x+1) vmap
     fun bind (TyFv v) vmap k = k (lookup v vmap)
       | bind (TyApp(opr,ty)) vmap k = bind opr vmap (fn opr' =>
                                       bind ty  vmap (fn ty'  =>
                                          k (TyApp(opr',ty'))))
       | bind (TyAll(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyAll(a,q)))
       | bind (TyExi(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyExi(a,q)))
       | bind (TyAbs(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyAbs(a,q)))
       | bind t vmap k = k t
  in
     rev_itlist (fn v => fn B => f(TyExi(v,B))) rvlist (bind ty varmap I)
  end
  handle e => raise wrap_exn "Type" "list_mk_exist_type_binder" e
 end
end;

val list_mk_exist_type = list_mk_exist_type_binder NONE "list_mk_exist_type";

fun mk_exist_type (Bvar as TyFv tyvar, Body) =
    let fun bind (TyFv v) i            = if v=tyvar then TyBv i else TyFv v
          | bind (TyApp(opr,ty)) i     = TyApp(bind opr i, bind ty i)
          | bind (TyAll(Bvar,Body)) i  = TyAll(Bvar, bind Body (i+1))
          | bind (TyExi(Bvar,Body)) i  = TyExi(Bvar, bind Body (i+1))
          | bind (TyAbs(Bvar,Body)) i  = TyAbs(Bvar, bind Body (i+1))
          | bind t _ = t
    in
      if is_type_kind (kind_of Body) then TyExi(tyvar, bind Body 0)
      else raise ERR "mk_exist_type" "kind of body is not the base kind"
    end
  | mk_exist_type _ = raise ERR "mk_exist_type" "bound variable arg not a variable";


(*---------------------------------------------------------------------------*
 * Type abstractions                                                         *
 *---------------------------------------------------------------------------*)

(*---------------------------------------------------------------------------
       Making type abstractions. list_mk_type_binder is a relatively
       efficient version for making types with many consecutive
       type abstractions.
  ---------------------------------------------------------------------------*)

local val FORMAT = ERR "list_mk_abs_type_binder"
   "expected first arg to be a type constant of kind ::(<kd>_1 => <kd>_2) => <kd>_3"
   fun check_opt NONE = Lib.I
     | check_opt (SOME c) = (* (fn abs => mk_app_type (c, abs)) *)
       (* or, *)
        if not(is_con_type c) then raise FORMAT
        else case total (fst o kind_dom_rng o fst o kind_dom_rng o kind_of) c
              of NONE => raise FORMAT
               | SOME kn => (fn abs =>
                   let val dom = fst(kind_dom_rng(kind_of abs))
                   in mk_app_type ( inst_kind[kn |-> dom] c, abs)
                   end)
       (**)
in
fun list_mk_abs_type_binder opt caller =
 let val f = check_opt opt
 in fn (vlist,ty)
 => if not (all is_vartype vlist) then raise ERR caller "bound variable arg not a type variable"
    else
  let open Redblackmap
     val varmap0 = mkDict tyvar_compare
     fun enum [] _ A = A
       | enum (TyFv h::t) i (vmap,rvs) = enum t (i-1) (insert (vmap,h,i), h::rvs)
       | enum _ _ _ = raise ERR "enum" "non-variable given as bound variable"
     val (varmap, rvlist) = enum vlist (length vlist - 1) (varmap0,[])
     fun lookup v vmap = case peek (vmap,v) of NONE => TyFv v | SOME i => TyBv i
     fun increment vmap = transform (fn x => x+1) vmap
     fun bind (TyFv v) vmap k = k (lookup v vmap)
       | bind (TyApp(opr,ty)) vmap k = bind opr vmap (fn opr' =>
                                       bind ty  vmap (fn ty'  =>
                                          k (TyApp(opr',ty'))))
       | bind (TyAll(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyAll(a,q)))
       | bind (TyExi(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyExi(a,q)))
       | bind (TyAbs(a,ty)) vmap k  = bind ty (increment vmap)
                                          (fn q => k (TyAbs(a,q)))
       | bind t vmap k = k t
  in
     rev_itlist (fn v => fn B => f(TyAbs(v,B))) rvlist (bind ty varmap I)
  end
  handle e => raise wrap_exn "Type" "list_mk_abs_type_binder" e
 end
end;

val list_mk_abs_type = list_mk_abs_type_binder NONE "list_mk_abs_type";

fun mk_abs_type (Bvar as TyFv tyvar, Body) =
    let fun bind (TyFv v) i            = if v=tyvar then TyBv i else TyFv v
          | bind (TyApp(opr,ty)) i     = TyApp(bind opr i, bind ty i)
          | bind (TyAll(Bvar,Body)) i  = TyAll(Bvar, bind Body (i+1))
          | bind (TyExi(Bvar,Body)) i  = TyExi(Bvar, bind Body (i+1))
          | bind (TyAbs(Bvar,Body)) i  = TyAbs(Bvar, bind Body (i+1))
          | bind t _ = t
    in
      TyAbs(tyvar, bind Body 0)
    end
  | mk_abs_type _ = raise ERR "mk_univ_type" "bound variable arg not a variable";


(*---------------------------------------------------------------------------
            Taking types apart

    These operations are all easy, except for taking apart multiple universal or
    existential types or type abstractions. It can happen, via beta-conversion or
    substitution, or instantiation, that a free type variable is bound by the scope.
    One of the tasks of strip_univ_type is to sort the resulting mess out.
    strip_univ_type works by first classifying all the free type variables in
    the body as being captured by the prefix bindings or not. Each capturing
    prefix type binder is then renamed until it doesn't capture. Then we go
    through the body and replace the dB indices of the prefix with the
    corresponding free type variables. These may in fact fall under another
    type binder; the renaming of that will, if necessary, get done if that
    type binder is taken apart (by a subsequent dest/strip_type_binder).
 ---------------------------------------------------------------------------*)

local fun peel f ty A =
            case f ty of
              SOME(TyAll(v,M)) => peel f M (v::A)
            | otherwise => (A,ty)
      datatype occtype = PREFIX of int | BODY
      fun array_to_revlist A =
        let val top = Array.length A - 1
            fun For i B = if i>top then B else For (i+1) (Array.sub(A,i)::B)
        in For 0 []
        end
      val vi_empty = HOLset.empty (fn ((v1,i1),(v2,i2)) => tyvar_compare(v1,v2))
      fun add_vi viset vi =
         if HOLset.member(viset,vi) then viset else HOLset.add(viset,vi)
      val AV = ref (Redblackmap.mkDict String.compare) : ((string,occtype)Redblackmap.dict) ref
      fun peekInsert (key,data) =
        let open Redblackmap
        in case peek (!AV,key)
            of SOME data' => SOME data'
             | NONE       => (AV := insert(!AV,key,data); NONE)
        end
in
fun strip_univ_binder opt =
 let val f =
         case opt of
           NONE => (fn (t as TyAll _) => SOME t
                     | other => NONE)
         | SOME c => (fn t => let val (name,args) = dest_type t
                              in if name = c
                                 then SOME (mk_type(name, args))
                                 else NONE
                              end handle HOL_ERR _ => NONE)
 in fn ty =>
   let val (prefixl,body) = peel f ty []
     val prefixlen = length prefixl
     val prefix = Array.fromList prefixl
     val vmap = curry Array.sub prefix
     val (insertAVbody,insertAVprefix,lookAV,dupls) =
        let open Redblackmap  (* AV is red-black map  of (tyvar,occtype) elems *)
            val _ = AV := mkDict String.compare
            fun insertl [] _ dupls = dupls
              | insertl (x::rst) i dupls =
                  let val n =  #1 x
                  in case peekInsert (n,PREFIX i)
                      of NONE => insertl rst (i+1) dupls
                       | SOME _ => insertl rst (i+1) ((x,i)::dupls)
                  end
            val dupls = insertl prefixl 0 []
        in ((fn s => (AV := insert (!AV,s,BODY))),         (* insertAVbody *)
            (fn (s,i) => (AV := insert (!AV,s,PREFIX i))), (* insertAVprefix *)
            (fn s => peek (!AV,s)),                        (* lookAV *)
            dupls)
        end
     fun variantAV n =
       let val next = Lexis.tyvar_vary
           fun loop s = case lookAV s of NONE => s | SOME _ => loop (next s)
       in loop n
       end
     fun CVs (TyFv(n,_)) capt k =
          (case lookAV n
            of SOME (PREFIX i) => k (add_vi capt (vmap i,i))
             | SOME BODY => k capt
             | NONE => (insertAVbody n; k capt))
       | CVs(TyApp(opr,ty)) capt k = CVs opr capt (fn c => CVs ty c k)
       | CVs(TyAll(_,M)) capt k  = CVs M capt k
       | CVs(TyExi(_,M)) capt k  = CVs M capt k
       | CVs(TyAbs(_,M)) capt k  = CVs M capt k
       | CVs t capt k = k capt
     fun unclash insert [] = ()
       | unclash insert ((v,i)::rst) =
           let val (n,kind) = (* dest_var *) v
               val n' = variantAV n
               val v' = (* mk_var *) (n',kind)
           in Array.update(prefix,i,v')
            ; insert (n',i)
            ; unclash insert rst
           end
     fun unbind (v as TyBv i) j k =
                 k (TyFv (vmap(i-j)) handle Subscript => if i>j then TyBv(i-prefixlen) (* new! *)
                                                         else v)
       | unbind (TyApp(opr,ty)) j k = unbind opr j (fn opr' =>
                                      unbind ty  j (fn ty' =>
                                        k (TyApp(opr',ty'))))
       | unbind (TyAll(v,B)) j k  = unbind B (j+1) (fn q => k(TyAll(v,q)))
       | unbind (TyExi(v,B)) j k  = unbind B (j+1) (fn q => k(TyExi(v,q)))
       | unbind (TyAbs(v,B)) j k  = unbind B (j+1) (fn q => k(TyAbs(v,q)))
       | unbind t j k = k t
 in
     unclash insertAVprefix (List.rev dupls)
   ; unclash (insertAVbody o fst) (HOLset.listItems(CVs body vi_empty I))
   ; (List.map TyFv (array_to_revlist prefix), unbind body 0 I)
 end
 end
end;

val strip_univ_type = strip_univ_binder NONE;

local exception CLASH
in
fun dest_univ_type(TyAll(Bvar as (Name,_), Body)) =
    let fun dest ((v as TyBv j), i) = if i=j then TyFv Bvar
                                      else if i<j then TyBv (j-1) (* new! *)
                                      else v
          | dest ((v as TyFv(s,_)), i) =
                 if Name=s then raise CLASH else v
          | dest (TyApp(opr, ty), i)    = TyApp(dest(opr,i), dest(ty,i))
          | dest (TyAll(Bvar,Body),i)   = TyAll(Bvar, dest(Body,i+1))
          | dest (TyExi(Bvar,Body),i)   = TyExi(Bvar, dest(Body,i+1))
          | dest (TyAbs(Bvar,Body),i)   = TyAbs(Bvar, dest(Body,i+1))
          | dest (ty,_) = ty
    in (TyFv Bvar, dest(Body,0))
       handle CLASH =>
              dest_univ_type(TyAll(variant_tyvar (type_vars Body) Bvar, Body))
    end
  | dest_univ_type _ = raise ERR "dest_univ_type" "not a universal type"
end;

fun break_univ_type(TyAll(_,Body)) = Body
  | break_univ_type _ = raise ERR "break_univ_type" "not a universal type";

(* existential types *)

local fun peel f ty A =
            case f ty of
              SOME(TyExi(v,M)) => peel f M (v::A)
            | otherwise => (A,ty)
      datatype occtype = PREFIX of int | BODY
      fun array_to_revlist A =
        let val top = Array.length A - 1
            fun For i B = if i>top then B else For (i+1) (Array.sub(A,i)::B)
        in For 0 []
        end
      val vi_empty = HOLset.empty (fn ((v1,i1),(v2,i2)) => tyvar_compare(v1,v2))
      fun add_vi viset vi =
         if HOLset.member(viset,vi) then viset else HOLset.add(viset,vi)
      val AV = ref (Redblackmap.mkDict String.compare) : ((string,occtype)Redblackmap.dict) ref
      fun peekInsert (key,data) =
        let open Redblackmap
        in case peek (!AV,key)
            of SOME data' => SOME data'
             | NONE       => (AV := insert(!AV,key,data); NONE)
        end
in
fun strip_exist_binder opt =
 let val f =
         case opt of
           NONE => (fn (t as TyExi _) => SOME t
                     | other => NONE)
         | SOME c => (fn t => let val (name,args) = dest_type t
                              in if name = c
                                 then SOME (mk_type(name, args))
                                 else NONE
                              end handle HOL_ERR _ => NONE)
 in fn ty =>
   let val (prefixl,body) = peel f ty []
     val prefixlen = length prefixl
     val prefix = Array.fromList prefixl
     val vmap = curry Array.sub prefix
     val (insertAVbody,insertAVprefix,lookAV,dupls) =
        let open Redblackmap  (* AV is red-black map  of (tyvar,occtype) elems *)
            val _ = AV := mkDict String.compare
            fun insertl [] _ dupls = dupls
              | insertl (x::rst) i dupls =
                  let val n =  #1 x
                  in case peekInsert (n,PREFIX i)
                      of NONE => insertl rst (i+1) dupls
                       | SOME _ => insertl rst (i+1) ((x,i)::dupls)
                  end
            val dupls = insertl prefixl 0 []
        in ((fn s => (AV := insert (!AV,s,BODY))),         (* insertAVbody *)
            (fn (s,i) => (AV := insert (!AV,s,PREFIX i))), (* insertAVprefix *)
            (fn s => peek (!AV,s)),                        (* lookAV *)
            dupls)
        end
     fun variantAV n =
       let val next = Lexis.tyvar_vary
           fun loop s = case lookAV s of NONE => s | SOME _ => loop (next s)
       in loop n
       end
     fun CVs (TyFv(n,_)) capt k =
          (case lookAV n
            of SOME (PREFIX i) => k (add_vi capt (vmap i,i))
             | SOME BODY => k capt
             | NONE => (insertAVbody n; k capt))
       | CVs(TyApp(opr,ty)) capt k = CVs opr capt (fn c => CVs ty c k)
       | CVs(TyAll(_,M)) capt k  = CVs M capt k
       | CVs(TyExi(_,M)) capt k  = CVs M capt k
       | CVs(TyAbs(_,M)) capt k  = CVs M capt k
       | CVs t capt k = k capt
     fun unclash insert [] = ()
       | unclash insert ((v,i)::rst) =
           let val (n,kind) = (* dest_var *) v
               val n' = variantAV n
               val v' = (* mk_var *) (n',kind)
           in Array.update(prefix,i,v')
            ; insert (n',i)
            ; unclash insert rst
           end
     fun unbind (v as TyBv i) j k =
                 k (TyFv (vmap(i-j)) handle Subscript => if i>j then TyBv(i-prefixlen) (* new! *)
                                                         else v)
       | unbind (TyApp(opr,ty)) j k = unbind opr j (fn opr' =>
                                      unbind ty  j (fn ty' =>
                                        k (TyApp(opr',ty'))))
       | unbind (TyAll(v,B)) j k  = unbind B (j+1) (fn q => k(TyAll(v,q)))
       | unbind (TyExi(v,B)) j k  = unbind B (j+1) (fn q => k(TyExi(v,q)))
       | unbind (TyAbs(v,B)) j k  = unbind B (j+1) (fn q => k(TyAbs(v,q)))
       | unbind t j k = k t
 in
     unclash insertAVprefix (List.rev dupls)
   ; unclash (insertAVbody o fst) (HOLset.listItems(CVs body vi_empty I))
   ; (List.map TyFv (array_to_revlist prefix), unbind body 0 I)
 end
 end
end;

val strip_exist_type = strip_exist_binder NONE;

local exception CLASH
in
fun dest_exist_type(TyExi(Bvar as (Name,_), Body)) =
    let fun dest ((v as TyBv j), i) = if i=j then TyFv Bvar
                                      else if i<j then TyBv (j-1) (* new! *)
                                      else v
          | dest ((v as TyFv(s,_)), i) =
                 if Name=s then raise CLASH else v
          | dest (TyApp(opr, ty), i)    = TyApp(dest(opr,i), dest(ty,i))
          | dest (TyAll(Bvar,Body),i)   = TyAll(Bvar, dest(Body,i+1))
          | dest (TyExi(Bvar,Body),i)   = TyExi(Bvar, dest(Body,i+1))
          | dest (TyAbs(Bvar,Body),i)   = TyAbs(Bvar, dest(Body,i+1))
          | dest (ty,_) = ty
    in (TyFv Bvar, dest(Body,0))
       handle CLASH =>
              dest_exist_type(TyExi(variant_tyvar (type_vars Body) Bvar, Body))
    end
  | dest_exist_type _ = raise ERR "dest_exist_type" "not an existential type"
end;

fun break_exist_type(TyExi(_,Body)) = Body
  | break_exist_type _ = raise ERR "break_exist_type" "not an existential type";


(* Now for type abstractions. *)

local fun peel f ty A =
            case f ty of
              SOME(TyAbs(v,M)) => peel f M (v::A)
            | otherwise => (A,ty)
      datatype occtype = PREFIX of int | BODY
      fun array_to_revlist A =
        let val top = Array.length A - 1
            fun For i B = if i>top then B else For (i+1) (Array.sub(A,i)::B)
        in For 0 []
        end
      val vi_empty = HOLset.empty (fn ((v1,i1),(v2,i2)) => tyvar_compare(v1,v2))
      fun add_vi viset vi =
         if HOLset.member(viset,vi) then viset else HOLset.add(viset,vi)
      val AV = ref (Redblackmap.mkDict String.compare) : ((string,occtype)Redblackmap.dict) ref
      fun peekInsert (key,data) =
        let open Redblackmap
        in case peek (!AV,key)
            of SOME data' => SOME data'
             | NONE       => (AV := insert(!AV,key,data); NONE)
        end
in
fun strip_abs_binder opt =
 let val f =
         case opt of
           NONE => (fn (t as TyAbs _) => SOME t
                     | other => NONE)
         | SOME c => (fn t => let val (name,args) = dest_type t
                              in if name = c
                                 then SOME (mk_type(name, args))
                                 else NONE
                              end handle HOL_ERR _ => NONE)
 in fn ty =>
   let val (prefixl,body) = peel f ty []
     val prefixlen = length prefixl
     val prefix = Array.fromList prefixl
     val vmap = curry Array.sub prefix
     val (insertAVbody,insertAVprefix,lookAV,dupls) =
        let open Redblackmap  (* AV is red-black map  of (tyvar,occtype) elems *)
            val _ = AV := mkDict String.compare
            fun insertl [] _ dupls = dupls
              | insertl (x::rst) i dupls =
                  let val n =  #1 x
                  in case peekInsert (n,PREFIX i)
                      of NONE => insertl rst (i+1) dupls
                       | SOME _ => insertl rst (i+1) ((x,i)::dupls)
                  end
            val dupls = insertl prefixl 0 []
        in ((fn s => (AV := insert (!AV,s,BODY))),         (* insertAVbody *)
            (fn (s,i) => (AV := insert (!AV,s,PREFIX i))), (* insertAVprefix *)
            (fn s => peek (!AV,s)),                        (* lookAV *)
            dupls)
        end
     fun variantAV n =
       let val next = Lexis.tyvar_vary
           fun loop s = case lookAV s of NONE => s | SOME _ => loop (next s)
       in loop n
       end
     fun CVs (TyFv(n,_)) capt k =
          (case lookAV n
            of SOME (PREFIX i) => k (add_vi capt (vmap i,i))
             | SOME BODY => k capt
             | NONE => (insertAVbody n; k capt))
       | CVs(TyApp(opr,ty)) capt k = CVs opr capt (fn c => CVs ty c k)
       | CVs(TyAll(_,M)) capt k  = CVs M capt k
       | CVs(TyExi(_,M)) capt k  = CVs M capt k
       | CVs(TyAbs(_,M)) capt k  = CVs M capt k
       | CVs t capt k = k capt
     fun unclash insert [] = ()
       | unclash insert ((v,i)::rst) =
           let val (n,kind) = (* dest_var *) v
               val n' = variantAV n
               val v' = (* mk_var *) (n',kind)
           in Array.update(prefix,i,v')
            ; insert (n',i)
            ; unclash insert rst
           end
     fun unbind (v as TyBv i) j k =
                 k (TyFv (vmap(i-j)) handle Subscript => if i>j then TyBv(i-prefixlen) (* new! *)
                                                         else v)
       | unbind (TyApp(opr,ty)) j k = unbind opr j (fn opr' =>
                                      unbind ty  j (fn ty' =>
                                        k (TyApp(opr',ty'))))
       | unbind (TyAll(v,B)) j k  = unbind B (j+1) (fn q => k(TyAll(v,q)))
       | unbind (TyExi(v,B)) j k  = unbind B (j+1) (fn q => k(TyExi(v,q)))
       | unbind (TyAbs(v,B)) j k  = unbind B (j+1) (fn q => k(TyAbs(v,q)))
       | unbind t j k = k t
 in
     unclash insertAVprefix (List.rev dupls)
   ; unclash (insertAVbody o fst) (HOLset.listItems(CVs body vi_empty I))
   ; (List.map TyFv (array_to_revlist prefix), unbind body 0 I)
 end
 end
end;

val strip_abs_type = strip_abs_binder NONE;

local exception CLASH
in
fun dest_abs_type(TyAbs(Bvar as (Name,_), Body)) =
    let fun dest ((v as TyBv j), i) = if i=j then TyFv Bvar
                                      else if i<j then TyBv (j-1) (* new! *)
                                      else v
          | dest ((v as TyFv(s,_)), i) =
                 if Name=s then raise CLASH else v
          | dest (TyApp(opr, ty), i)    = TyApp(dest(opr,i), dest(ty,i))
          | dest (TyAll(Bvar,Body),i)   = TyAll(Bvar, dest(Body,i+1))
          | dest (TyExi(Bvar,Body),i)   = TyExi(Bvar, dest(Body,i+1))
          | dest (TyAbs(Bvar,Body),i)   = TyAbs(Bvar, dest(Body,i+1))
          | dest (ty,_) = ty
    in (TyFv Bvar, dest(Body,0))
       handle CLASH =>
              dest_abs_type(TyAbs(variant_tyvar (type_vars Body) Bvar, Body))
    end
  | dest_abs_type _ = raise ERR "dest_abs_type" "not a type abstraction"
end;

fun break_abs_type(TyAbs(_,Body)) = Body
  | break_abs_type _ = raise ERR "break_abs_type" "not a type abstraction";


(*---------------------------------------------------------------------------
    Does there exist a free type variable v in a type such that P(v) holds.
    Returns false if there are no free type variables in the type.
 ---------------------------------------------------------------------------*)

fun exists_tyvar P =
 let fun occ (w as TyFv _) = P w
       | occ (TyApp(Opr,Arg)) = occ Opr orelse occ Arg
       | occ (TyAll(_,ty)) = occ ty
       | occ (TyExi(_,ty)) = occ ty
       | occ (TyAbs(_,ty)) = occ ty
       | occ ty = false
 in occ end;

(*---------------------------------------------------------------------------
     Does a type variable occur free in a type
 ---------------------------------------------------------------------------*)

fun type_var_in v =
  if is_vartype v then exists_tyvar (type_eq v)
                  else raise ERR "type_var_occurs" "not a type variable"

(*
fun subst_rank [] = []
  | subst_rank ({redex,residue} :: s) =
      raw_match_rank false (rank_of_type redex) (rank_of_type residue) (subst_rank s)

fun inst_rank_subst r [] = []
  | inst_rank_subst r ({redex,residue} :: s) =
      {redex=inst_rank r redex, residue=residue} :: inst_rank_subst r s
*)

local
  open Binarymap
  val emptysubst:(hol_type,hol_type)Binarymap.dict = Binarymap.mkDict compare
  (* It is a precondition for pure_type_subst that the substitution theta
     must not require any reconciliation of kinds or ranks before using.
     addb should check this if possible. *)
  fun addb [] A = A
    | addb ({redex,residue}::t) (A,b) =
        let val redex_kd   = kind_of redex      handle HOL_ERR _ => raise Match
            val residue_kd = kind_of residue    handle HOL_ERR _ => raise Match
            val redex_rk   = rank_of redex_kd   handle HOL_ERR _ => raise Match
            val residue_rk = rank_of residue_kd handle HOL_ERR _ => raise Match
        in
        if not (redex_kd :>=: residue_kd)
        then raise ERR "pure_type_subst"
          ("kind of residue is not contained in kind of redex, or does not respect rank"
           ^ "\n" ^ type_to_string redex ^ "  |->\n" ^ type_to_string residue)
        else addb t (insert(A,redex,residue),
                     not (is_abs_type residue)
                       andalso (redex_rk = residue_rk) andalso b)
        end
        handle Match =>
           (* if "kind_of" fails because of open bound variables,
              assume the kind check was done earlier and proceed. *)
             addb t (insert(A,redex,residue),
                     false)

  fun lift i j (TyBv k) = if k >= j then TyBv (i+k) else TyBv k
    | lift i j (v as TyFv _) = v
    | lift i j (c as TyCon _) = c
    | lift i j (TyApp(Opr,Arg)) = TyApp(lift i j Opr, lift i j Arg)
    | lift i j (TyAll(Bvar,Body)) = TyAll(Bvar, lift i (j+1) Body)
    | lift i j (TyExi(Bvar,Body)) = TyExi(Bvar, lift i (j+1) Body)
    | lift i j (TyAbs(Bvar,Body)) = TyAbs(Bvar, lift i (j+1) Body)
(*
  fun lift1 i j (TyBv k) = if k >= j then if i = 0 then raise UNCHANGEDTY else TyBv (i+k)
                                     else raise UNCHANGEDTY
    | lift1 i j (v as TyFv _) = raise UNCHANGEDTY
    | lift1 i j (c as TyCon _) = raise UNCHANGEDTY
    | lift1 i j (TyApp(Opr,Arg)) =
        let in
          let val Opr' = lift1 i j Opr
          in TyApp(Opr', lift1 i j Arg)
             handle UNCHANGEDTY => TyApp(Opr',Arg)
          end handle UNCHANGEDTY => TyApp(Opr, lift1 i j Arg)
        end
    | lift1 i j (TyAll(Bvar,Body)) = TyAll(Bvar, lift1 i (j+1) Body)
    | lift1 i j (TyExi(Bvar,Body)) = TyExi(Bvar, lift1 i (j+1) Body)
    | lift1 i j (TyAbs(Bvar,Body)) = TyAbs(Bvar, lift1 i (j+1) Body)
  fun lift i j ty = lift1 i j ty handle UNCHANGEDTY => ty
*)
in
(* pure_type_subst properly ignores redexes which are not variables,
   but does not throw an error if any are included. *)
(* NOTE: pure_type_subst must only be called with beta-reduced redexes. *)
fun pure_type_subst [] = I
  | pure_type_subst theta =
    let val (fmap,b) = addb theta (emptysubst,true)
        fun vsubs i (v as TyFv _) =
               (case peek(fmap,v) of NONE => v
                                   | SOME y => lift i 0 y)
          | vsubs i (TyApp(opr,ty)) = TyApp(vsubs i opr, vsubs i ty)
          | vsubs i (TyAll(Bvar,Body)) = TyAll(Bvar,vsubs (i+1) Body)
          | vsubs i (TyExi(Bvar,Body)) = TyExi(Bvar,vsubs (i+1) Body)
          | vsubs i (TyAbs(Bvar,Body)) = TyAbs(Bvar,vsubs (i+1) Body)
          | vsubs i t = t
    in
      if b then vsubs 0 else (* vacuum o *) vsubs 0
    end

fun inst_rk_kd_ty ([],kdS,rkS)    = (inst_rank_kind (kdS,rkS)
                                     handle HOL_ERR{message=m,...} => raise ERR "inst_rk_kd_ty" m)
  | inst_rk_kd_ty (theta,[],0)    = (pure_type_subst theta
                                     handle HOL_ERR{message=m,...} => raise ERR "inst_rk_kd_ty" m)
  | inst_rk_kd_ty (theta,kdS,rkS) =
    let val kd_inst = Kind.inst_rank_kind (kdS,rkS)
        val (fmap,b) = addb theta (emptysubst,true)
        fun vsubs i (v as TyFv(s,kd)) =
              let val v' = TyFv(s,kd_inst kd) in
                case peek(fmap,v') of NONE => v'
                                    | SOME y => lift i 0 y
              end
          | vsubs i (TyCon(s,kd)) = TyCon(s,kd_inst kd)
          | vsubs i (TyApp(opr,ty)) = TyApp(vsubs i opr, vsubs i ty)
          | vsubs i (TyAll((s,kd),Body)) = TyAll((s,kd_inst kd), vsubs (i+1) Body)
          | vsubs i (TyExi((s,kd),Body)) = TyExi((s,kd_inst kd), vsubs (i+1) Body)
          | vsubs i (TyAbs((s,kd),Body)) = TyAbs((s,kd_inst kd), vsubs (i+1) Body)
          | vsubs i t = t
    in
      (* vacuum o *) vsubs 0
    end
    handle HOL_ERR{message=m,...} => raise ERR "inst_rk_kd_ty" m

(* full_type_subst substitutes type expressions for type expressions.
   Unlike pure_type_subst, the redexes do not have to be type variables.
   This function cannot be used inside terms, lest type-checking be violated. *)

fun full_type_subst theta =
    let val (fmap,b) = addb theta (emptysubst,true)
        fun subs i ty =
          case peek(fmap,ty)
           of SOME residue => lift i 0 residue
            | NONE =>
              (case ty
                of TyApp(opr,ty) => TyApp(subs i opr, subs i ty)
                 | TyAll(Bvar,Body) => TyAll(Bvar,subs (i+1) Body)
                 | TyExi(Bvar,Body) => TyExi(Bvar,subs (i+1) Body)
                 | TyAbs(Bvar,Body) => TyAbs(Bvar,subs (i+1) Body)
                 | _ => ty)
(*
        fun subs ty =
          case peek(fmap,ty)
           of SOME residue => residue
            | NONE =>
              (case ty
                of TyApp(opr,ty) => TyApp(subs opr, subs ty)
                 | TyAll(Bvar,Body) => TyAll(Bvar, subs Body)
                 | TyExi(Bvar,Body) => TyExi(Bvar, subs Body)
                 | TyAbs(Bvar,Body) => TyAbs(Bvar, subs Body)
                 | _ => ty)
*)
    in subs 0
    end
end;

(*---------------------------------------------------------------------------*
 * Is a type polymorphic, or contain a universal type or type abstraction?   *
 *---------------------------------------------------------------------------*)

fun polymorphic (TyCon (_,Kd))    = Kind.polymorphic Kd
  | polymorphic (TyFv _)          = true
  | polymorphic (TyBv _)          = true
  | polymorphic (TyApp (Opr,Arg)) = polymorphic Opr orelse polymorphic Arg
  | polymorphic (TyAll (_,Body))  = true (* alt: polymorphic Body *)
  | polymorphic (TyExi (_,Body))  = true (* alt: polymorphic Body *)
  | polymorphic (TyAbs (_,Body))  = true (* alt: polymorphic Body *)

fun universal (TyAll _)         = true
  | universal (TyApp (Opr,Arg)) = universal Opr orelse universal Arg
  | universal (TyAbs (_,Body))  = universal Body
  | universal (TyExi (_,Body))  = universal Body
  | universal _                 = false

fun existential (TyExi _)         = true
  | existential (TyApp (Opr,Arg)) = existential Opr orelse existential Arg
  | existential (TyAbs (_,Body))  = existential Body
  | existential (TyAll (_,Body))  = existential Body
  | existential _                 = false

fun abstraction (TyAbs _)         = true
  | abstraction (TyApp (Opr,Arg)) = abstraction Opr orelse abstraction Arg
  | abstraction (TyAll (_,Body))  = abstraction Body
  | abstraction (TyExi (_,Body))  = abstraction Body
  | abstraction _                 = false

fun is_omega (TyAbs _)         = true
  | is_omega (TyAll _)         = true
  | is_omega (TyExi _)         = true
  | is_omega (TyApp (Opr,Arg)) = is_omega Opr orelse is_omega Arg
  | is_omega (TyBv _)          = true
  | is_omega (TyFv (_,k))      = not (k = Kind.typ rho)
  | is_omega (TyCon(_,k))      = not (Kind.is_arity k)


(* ---------------------------------------------------------------------*)
(* Beta conversion section, including conversionals for depth search    *)
(* ---------------------------------------------------------------------*)

fun beta_conv_ty (TyApp(M as TyAbs _, N))
       = let val (btyv,body) = dest_abs_type M
         in pure_type_subst [btyv |-> N] body
         end
  | beta_conv_ty _ = raise ERR "beta_conv_ty" "not a type beta redex"

local
  fun pop (ty as TyBv i, k) =
       if i=k then raise ERR "eta_conv_ty" "not a type eta redex"
       else if i>k then TyBv (i-1) else ty
    | pop (TyApp(Opr, Arg ), k) = TyApp(pop(Opr,k), pop(Arg,k))
    | pop (TyAbs(Bvar,Body), k) = TyAbs(Bvar, pop(Body, k+1))
    | pop (TyAll(Bvar,Body), k) = TyAll(Bvar, pop(Body, k+1))
    | pop (TyExi(Bvar,Body), k) = TyExi(Bvar, pop(Body, k+1))
    | pop (ty,k) = ty
in
fun eta_conv_Ety E (ty as TyAbs (tyv, TyApp(M, TyBv 0)))
       = let val a = TyFv tyv
             val (_,kd) = tyv
(*
             val M' = fst (dest_app_type (beta_conv_ty (TyApp(ty, a))))
                      handle HOL_ERR _ => raise ERR "eta_conv_ty" "not a type eta redex"
         in if not (fst (kind_dom_rng (kind_of M)) = kind_of a)
               orelse mem a (type_vars M') then raise ERR "eta_conv_ty" "not a type eta redex"
            else M'
*)
         in if not (fst (kind_dom_rng (kd_of M (kd::E))) = kd)
                   (* kd_of may fail if M contains "free" bound variables not in E *)
                   handle HOL_ERR{message = "lookup", ...} =>
                          raise ERR "eta_conv_ty" "not a type eta redex"
               then raise ERR "eta_conv_ty" "not a type eta redex"
            else pop(M,0)
         end
  | eta_conv_Ety _ _ = raise ERR "eta_conv_Ety" "not a type eta redex"
end

val eta_conv_ty = eta_conv_Ety []

fun qconv_ty c ty = c ty handle UNCHANGEDTY => ty

fun qconv_Ety c E ty = c E ty handle UNCHANGEDTY => ty

fun ifnotvarcon_ty c (TyFv  _) = raise UNCHANGEDTY
  | ifnotvarcon_ty c (TyCon _) = raise UNCHANGEDTY
  | ifnotvarcon_ty c ty = c ty

fun ifnotvarcon_Ety c E (TyFv  _) = raise UNCHANGEDTY
  | ifnotvarcon_Ety c E (TyCon _) = raise UNCHANGEDTY
  | ifnotvarcon_Ety c E ty = c E ty

(* ---------------------------------------------------------------------*)
(* rand_conv_ty conv ``:t2 t1`` applies conv to t2                      *)
(* ---------------------------------------------------------------------*)

fun rand_conv_ty conv (TyApp(Rator,Rand)) = let
  val Newrand = conv Rand
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "rand_conv_ty" message
      else
        raise ERR "rand_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyApp(Rator, Newrand)
end
  | rand_conv_ty _ _ = raise ERR "rand_conv_ty" "not a type app"

fun rand_conv_Ety conv E (TyApp(Rator,Rand)) = let
  val Newrand = conv E Rand
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "rand_conv_ty" message
      else
        raise ERR "rand_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyApp(Rator, Newrand)
end
  | rand_conv_Ety _ _ _ = raise ERR "rand_conv_Ety" "not a type app"

(* ---------------------------------------------------------------------*)
(* rator_conv_ty conv ``:t2 t1`` applies conv to t1                     *)
(* ---------------------------------------------------------------------*)

fun rator_conv_ty conv (TyApp(Rator,Rand)) = let
  val Newrator = conv Rator
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "rator_conv_ty" message
      else
        raise ERR "rator_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyApp(Newrator, Rand)
end
  | rator_conv_ty _ _ = raise ERR "rator_conv_ty" "not a type app"

(* ---------------------------------------------------------------------*)
(* app_conv_ty conv ``:t2 t1`` applies conv to t1 and to t2             *)
(* ---------------------------------------------------------------------*)

fun app_conv_ty conv (TyApp(Rator, Rand)) = let in
  let
    val Rator' = conv Rator
  in
    TyApp(Rator', conv Rand) handle UNCHANGEDTY => TyApp(Rator', Rand)
  end handle UNCHANGEDTY => TyApp(Rator, conv Rand)
  end
  | app_conv_ty _ _ = raise ERR "app_conv_ty" "Not a type app"

fun app_conv_Ety conv E (TyApp(Rator, Rand)) = let in
  let
    val Rator' = conv E Rator
  in
    TyApp(Rator', conv E Rand) handle UNCHANGEDTY => TyApp(Rator', Rand)
  end handle UNCHANGEDTY => TyApp(Rator, conv E Rand)
  end
  | app_conv_Ety _ _ _ = raise ERR "app_conv_Ety" "Not a type app"

(* ----------------------------------------------------------------------
    abs_conv_ty conv ``: \'a. t['a]`` applies conv to t['a]
   ---------------------------------------------------------------------- *)

fun abs_conv_Ety conv E (TyAbs(Bvar,Body)) = let
  val (_,kd) = Bvar
  val E' = kd :: E
  val Newbody = conv E' Body
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "abs_conv_ty" message
      else
        raise ERR "abs_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyAbs(Bvar, Newbody)
end
  | abs_conv_Ety _ _ _ = raise ERR "abs_conv_ty" "not a type abstraction"

fun abs_conv_ty conv (TyAbs(Bvar,Body)) = let
  val Newbody = conv Body
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "abs_conv_ty" message
      else
        raise ERR "abs_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyAbs(Bvar, Newbody)
end
  | abs_conv_ty _ _ = raise ERR "abs_conv_ty" "not a type abstraction"

(* fun abs_conv_ty conv = abs_conv_Ety (fn _ => conv) [] *)

(* ----------------------------------------------------------------------
    univ_conv_ty conv ``: !'a. t['a]`` applies conv to t['a]
   ---------------------------------------------------------------------- *)

fun univ_conv_Ety conv E (TyAll(Bvar,Body)) = let
  val (_,kd) = Bvar
  val E' = kd :: E
  val Newbody = conv E' Body
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "univ_conv_ty" message
      else
        raise ERR "univ_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyAll(Bvar, Newbody)
end
  | univ_conv_Ety _ _ _ = raise ERR "univ_conv_ty" "not a universal type"

fun univ_conv_ty conv (TyAll(Bvar,Body)) = let
  val Newbody = conv Body
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "univ_conv_ty" message
      else
        raise ERR "univ_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyAll(Bvar, Newbody)
end
  | univ_conv_ty _ _ = raise ERR "univ_conv_ty" "not a universal type"

(* ----------------------------------------------------------------------
    exist_conv_ty conv ``: ?'a. t['a]`` applies conv to t['a]
   ---------------------------------------------------------------------- *)

fun exist_conv_Ety conv E (TyExi(Bvar,Body)) = let
  val (_,kd) = Bvar
  val E' = kd :: E
  val Newbody = conv E' Body
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "exist_conv_ty" message
      else
        raise ERR "exist_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyExi(Bvar, Newbody)
end
  | exist_conv_Ety _ _ _ = raise ERR "exist_conv_Ety" "not an existential type"

fun exist_conv_ty conv (TyExi(Bvar,Body)) = let
  val Newbody = conv Body
(*
    handle HOL_ERR {origin_function, message, origin_structure} =>
      if Lib.mem origin_function
           ["rand_conv_ty", "rator_conv_ty", "abs_conv_ty", "univ_conv_ty", "exist_conv_ty"]
         andalso origin_structure = "Type"
      then
        raise ERR "exist_conv_ty" message
      else
        raise ERR "exist_conv_ty" (origin_function ^ ": " ^ message)
*)
in
  TyExi(Bvar, Newbody)
end
  | exist_conv_ty _ _ = raise ERR "exist_conv_ty" "not an existential type"

(*---------------------------------------------------------------------------
 * Conversion that always fails;  identity element for orelse_ty.
 *---------------------------------------------------------------------------*)

fun no_conv_ty _ = raise ERR "no_conv_ty" "";

(* ----------------------------------------------------------------------
    Conversion that always succeeds, but does nothing.
    Indicates this by raising the UNCHANGEDTY exception.
   ---------------------------------------------------------------------- *)

fun all_conv_ty _ = raise UNCHANGEDTY;

fun all_conv_Ety _ _ = raise UNCHANGEDTY;

(* ----------------------------------------------------------------------
    Apply two conversions in succession;  fail if either does.  Handle
    UNCHANGED appropriately.
   ---------------------------------------------------------------------- *)

infix then_ty orelse_ty then_Ety orelse_Ety;

fun (conv1 then_ty conv2) ty = let
  val ty1 = conv1 ty
in
  conv2 ty1 handle UNCHANGEDTY => ty1
end handle UNCHANGEDTY => conv2 ty

fun (conv1 then_Ety conv2) E ty = let
  val ty1 = conv1 E ty
in
  conv2 E ty1 handle UNCHANGEDTY => ty1
end handle UNCHANGEDTY => conv2 E ty

(* ----------------------------------------------------------------------
    Apply conv1;  if it raises a HOL_ERR then apply conv2. Note that
    interrupts and other exceptions (including UNCHANGEDTY) will sail on
    through.
   ---------------------------------------------------------------------- *)

fun (conv1 orelse_ty conv2) ty = conv1 ty handle HOL_ERR _ => conv2 ty;

fun (conv1 orelse_Ety conv2) E ty = conv1 E ty handle HOL_ERR _ => conv2 E ty;


(*---------------------------------------------------------------------------*
 * Perform the first successful conversion of those in the list.             *
 *---------------------------------------------------------------------------*)

fun first_conv_ty [] ty = no_conv_ty ty
  | first_conv_ty (a::rst) ty = a ty handle HOL_ERR _ => first_conv_ty rst ty;

fun first_conv_Ety [] _ ty = no_conv_ty ty
  | first_conv_Ety (a::rst) E ty = a E ty handle HOL_ERR _ => first_conv_Ety rst E ty;

(*---------------------------------------------------------------------------
 * Perform every conversion in the list.
 *---------------------------------------------------------------------------*)

fun every_conv_ty convl ty =
   itlist (curry (op then_ty)) convl all_conv_ty ty
   handle HOL_ERR _ => raise ERR "every_conv_ty" "";

fun every_conv_Ety convl E ty =
   itlist (curry (op then_ty)) (map (fn c => c E) convl) all_conv_ty ty
   handle HOL_ERR _ => raise ERR "every_conv_Ety" "";


(*---------------------------------------------------------------------------
 * Cause the conversion to fail if it does not change its input.
 *---------------------------------------------------------------------------*)

fun changed_conv_ty conv ty =
   let val ty1 = conv ty
           handle UNCHANGEDTY => raise ERR "changed_conv_ty" "Input type unchanged"
   in if aconv_ty ty ty1 then raise ERR "changed_conv_ty" "Input type unchanged"
      else ty1
   end;

fun changed_conv_Ety conv E ty =
   let val ty1 = conv E ty
           handle UNCHANGEDTY => raise ERR "changed_conv_Ety" "Input type unchanged"
   in if aconv_ty ty ty1 then raise ERR "changed_conv_Ety" "Input type unchanged"
      else ty1
   end;

(* ----------------------------------------------------------------------
    Cause a failure if the conversion causes the UNCHANGED exception to
    be raised.  Doesn't "waste time" doing an equality check.  Mnemonic:
    "quick changed_conv".
   ---------------------------------------------------------------------- *)

fun qchanged_conv_ty conv ty =
    conv ty
    handle UNCHANGEDTY => raise ERR "qchanged_conv_ty" "Input type unchanged"

fun qchanged_conv_Ety conv E ty =
    conv E ty
    handle UNCHANGEDTY => raise ERR "qchanged_conv_Ety" "Input type unchanged"

(*---------------------------------------------------------------------------
 * Apply a conversion zero or more times.
 *---------------------------------------------------------------------------*)

fun repeat_ty conv ty =
    ((qchanged_conv_ty conv then_ty (repeat_ty conv)) orelse_ty all_conv_ty) ty;

fun repeat_Ety conv E ty =
    ((qchanged_conv_Ety conv then_Ety (repeat_Ety conv)) orelse_Ety all_conv_Ety) E ty;

fun try_conv_ty conv = conv orelse_ty all_conv_ty;

fun try_conv_Ety conv = conv orelse_Ety all_conv_Ety;

fun sub_conv_ty conv =
    try_conv_ty (app_conv_ty conv orelse_ty abs_conv_ty conv
                 orelse_ty univ_conv_ty conv orelse_ty exist_conv_ty conv)

fun sub_conv_Ety conv =
    try_conv_Ety (app_conv_Ety conv orelse_Ety abs_conv_Ety conv
                  orelse_Ety univ_conv_Ety conv orelse_Ety exist_conv_Ety conv)

fun head_betan_ty (TyApp(M as TyAbs _, N))
       = let val (btyv,body) = dest_abs_type M
         in qconv_ty head_betan_ty (pure_type_subst [btyv |-> N] body)
         end
  | head_betan_ty (ty as TyApp(ty1 as TyApp _, ty2))
       = let val ty' = TyApp(head_betan_ty ty1,ty2) (* may throw UNCHANGEDTY *)
         in try_conv_ty (beta_conv_ty then_ty qconv_ty head_betan_ty) ty' (* cannot throw UNCHANGEDTY *)
         end
  | head_betan_ty _ = raise UNCHANGEDTY

(* fun head_betan_ty = (try_conv_ty (rator_conv_ty head_betan_ty)
                           then_ty try_conv_ty (beta_conv_ty
                                                then_ty head_betan_ty)) ty *)

fun head_beta_etan_ty (TyApp(M as TyAbs _, N))
       = let val (btyv,body) = dest_abs_type M
         in qconv_ty head_beta_etan_ty (pure_type_subst [btyv |-> N] body)
         end
  | head_beta_etan_ty (ty as TyApp(ty1 as TyApp _, ty2))
       = let val ty' = TyApp(head_beta_etan_ty ty1,ty2) (* may throw UNCHANGEDTY *)
         in qconv_ty (try_conv_ty (beta_conv_ty then_ty head_beta_etan_ty)) ty' (* cannot throw UNCHANGEDTY *)
         end
  | head_beta_etan_ty (ty as TyAbs (tyv, body))
       = (abs_conv_ty head_beta_etan_ty then_ty
          try_conv_ty (abs_conv_ty (rand_conv_ty head_beta_etan_ty) then_ty
                       eta_conv_ty then_ty head_beta_etan_ty)) ty
  | head_beta_etan_ty _ = raise UNCHANGEDTY

fun beta_conv_Ety E = beta_conv_ty

fun head_beta_etan_Ety E (TyApp(M as TyAbs _, N))
       = let val (btyv,body) = dest_abs_type M
         in qconv_Ety head_beta_etan_Ety E (pure_type_subst [btyv |-> N] body)
         end
  | head_beta_etan_Ety E (ty as TyApp(ty1 as TyApp _, ty2))
       = let val ty' = TyApp(head_beta_etan_Ety E ty1,ty2) (* may throw UNCHANGEDTY *)
         in qconv_Ety (try_conv_Ety (beta_conv_Ety then_Ety head_beta_etan_Ety)) E ty' (* cannot throw UNCHANGEDTY *)
         end
  | head_beta_etan_Ety E (ty as TyAbs (tyv, body))
       = (abs_conv_Ety head_beta_etan_Ety then_Ety
          try_conv_Ety (abs_conv_Ety (rand_conv_Ety head_beta_etan_Ety) then_Ety
                        eta_conv_Ety then_Ety head_beta_etan_Ety)) E ty
  | head_beta_etan_Ety _ _ = raise UNCHANGEDTY

(* ----------------------------------------------------------------------
    traversal conversionals.

    depth_conv_ty c
      bottom-up, recurse over sub-terms, and then repeatedly apply c at
      top-level.

    redepth_conv_ty c
      bottom-up. recurse over sub-terms, apply c at top, and if this
      succeeds, repeat from start.

    top_depth_conv_ty c
      top-down. Repeatdly apply c at top-level, then descend.  If descending
      doesn't change anything then stop.  If there was a change then
      come back to top and try c once more at top-level.  If this succeeds
      repeat.

    top_sweep_conv_ty c
      top-down.  Like top_depth_conv_ty but only makes one pass over the term,
      never coming back to the top level once descent starts.

    once_depth_conv_ty c
      top-down (confusingly).  Descends term looking for position at
      which c works.  Does this "in parallel", so c may be applied multiple
      times at highest possible positions in distinct sub-terms.

   ---------------------------------------------------------------------- *)

fun depth_conv_ty conv ty =
    (sub_conv_ty (depth_conv_ty conv) then_ty repeat_ty conv) ty

fun depth_conv_Ety conv E ty =
    (sub_conv_Ety (depth_conv_Ety conv) then_Ety repeat_Ety conv) E ty

fun redepth_conv_ty conv ty =
    (sub_conv_ty (redepth_conv_ty conv) then_ty
     try_conv_ty (conv then_ty redepth_conv_ty conv)) ty

fun redepth_conv_Ety conv E ty =
    (sub_conv_Ety (redepth_conv_Ety conv) then_Ety
     try_conv_Ety (conv then_Ety redepth_conv_Ety conv)) E ty

fun top_depth_conv_ty conv ty =
    (repeat_ty conv then_ty
     try_conv_ty (changed_conv_ty (sub_conv_ty (top_depth_conv_ty conv)) then_ty
                  try_conv_ty (conv then_ty top_depth_conv_ty conv))) ty

fun top_depth_conv_Ety conv E ty =
    (repeat_Ety conv then_Ety
     try_conv_Ety (changed_conv_Ety (sub_conv_Ety (top_depth_conv_Ety conv)) then_Ety
                   try_conv_Ety (conv then_Ety top_depth_conv_Ety conv))) E ty

fun once_depth_conv_ty conv ty =
    try_conv_ty (conv orelse_ty sub_conv_ty (once_depth_conv_ty conv)) ty

fun once_depth_conv_Ety conv E ty =
    try_conv_Ety (conv orelse_Ety sub_conv_Ety (once_depth_conv_Ety conv)) E ty

fun top_sweep_conv_ty conv ty =
    (repeat_ty conv then_ty sub_conv_ty (top_sweep_conv_ty conv)) ty

fun top_sweep_conv_Ety conv E ty =
    (repeat_Ety conv then_Ety sub_conv_Ety (top_sweep_conv_Ety conv)) E ty

val deep_beta_ty = (* vacuum o *) qconv_ty (ifnotvarcon_ty (top_depth_conv_ty beta_conv_ty))

val deep_eta_ty = (* vacuum o *) qconv_ty (ifnotvarcon_ty (top_depth_conv_ty eta_conv_ty))

val deep_eta_Ety = (* vacuum o *) qconv_Ety (ifnotvarcon_Ety (top_depth_conv_Ety eta_conv_Ety))
val deep_eta_ty = deep_eta_Ety []

val deep_beta_eta_ty = (* vacuum o *) qconv_ty (ifnotvarcon_ty (top_depth_conv_ty (beta_conv_ty orelse_ty eta_conv_ty)))

val deep_beta_eta_Ety = (* vacuum o *) qconv_Ety (ifnotvarcon_Ety (top_depth_conv_Ety (beta_conv_Ety orelse_Ety eta_conv_Ety)))
val deep_beta_eta_ty = deep_beta_eta_Ety []

fun strip_app_beta_eta_type ty = strip_app_type (deep_beta_eta_ty ty)

(*  head_beta1_ty reduces the head beta redex; fails if one does not exist. *)
fun head_beta1_ty ty = (rator_conv_ty head_beta1_ty orelse_ty beta_conv_ty) ty

(*  head_beta_ty repeatedly reduces any head beta redexes; never fails *)
(*  result has at its top level its actual shape *)
(* val head_beta_ty = qconv_ty (repeat_ty head_beta1_ty) *)
val head_beta_ty = qconv_ty head_betan_ty
val head_beta_eta_ty = qconv_ty head_beta_etan_ty
val head_beta_eta_Ety = qconv_Ety head_beta_etan_Ety


local val EQ = Portable.pointer_eq
in
fun abconv_ty t1 t2  = EQ(t1,t2) orelse
                   (*  aconv_ty (deep_beta_ty t1) (deep_beta_ty t2)  *)
                       abconv1_ty (head_beta_ty t1) (head_beta_ty t2)
and abconv1_ty t1 t2 =
     case(t1,t2)
      of (u as TyFv _, v as TyFv _ ) => type_var_compare(u,v) = EQUAL
       | (u as TyCon _,v as TyCon _) => type_con_compare(u,v) = EQUAL
       | (TyApp(p,t1),TyApp(q,t2)) => abconv1_ty p q andalso abconv_ty t1 t2
       | (TyAll((_,k1),t1),
          TyAll((_,k2),t2)) => k1 = k2 andalso abconv_ty t1 t2
       | (TyExi((_,k1),t1),
          TyExi((_,k2),t2)) => k1 = k2 andalso abconv_ty t1 t2
       | (TyAbs((_,k1),t1),
          TyAbs((_,k2),t2)) => k1 = k2 andalso abconv_ty t1 t2
       | (M,N) => (M=N)

fun abeconv_ty t1 t2 = EQ(t1,t2) orelse
                  (*   aconv_ty (deep_beta_eta_ty t1) (deep_beta_eta_ty t2)  *)
                       abeconv1_ty (head_beta_eta_ty t1) (head_beta_eta_ty t2)
and abeconv1_ty t1 t2 =
     case(t1,t2)
      of (u as TyFv _, v as TyFv _ ) => type_var_compare(u,v) = EQUAL
       | (u as TyCon _,v as TyCon _) => type_con_compare(u,v) = EQUAL
       | (TyApp(p,t1),TyApp(q,t2)) => abeconv1_ty p q andalso abeconv_ty t1 t2
       | (TyAll((_,k1),t1),
          TyAll((_,k2),t2)) => k1 = k2 andalso abeconv_ty t1 t2
       | (TyExi((_,k1),t1),
          TyExi((_,k2),t2)) => k1 = k2 andalso abeconv_ty t1 t2
       | (TyAbs((_,k1),t1),
          TyAbs((_,k2),t2)) => k1 = k2 andalso abeconv1_ty t1 t2
       | (M,N) => (M=N)

fun abeconv_Ety E t1 t2 = EQ(t1,t2) orelse
                  (*   aconv_ty (deep_beta_eta_ty t1) (deep_beta_eta_ty t2)  *)
                       abeconv1_Ety E (head_beta_eta_Ety E t1) (head_beta_eta_Ety E t2)
and abeconv1_Ety E t1 t2 =
     case(t1,t2)
      of (u as TyFv _, v as TyFv _ ) => type_var_compare(u,v) = EQUAL
       | (u as TyCon _,v as TyCon _) => type_con_compare(u,v) = EQUAL
       | (TyApp(p,t1),TyApp(q,t2)) => abeconv1_Ety E p q andalso abeconv_Ety E t1 t2
       | (TyAll((_,k1),t1),
          TyAll((_,k2),t2)) => k1 = k2 andalso abeconv_Ety (k1::E) t1 t2
       | (TyExi((_,k1),t1),
          TyExi((_,k2),t2)) => k1 = k2 andalso abeconv_Ety (k1::E) t1 t2
       | (TyAbs((_,k1),t1),
          TyAbs((_,k2),t2)) => k1 = k2 andalso abeconv1_Ety (k1::E) t1 t2
       | (M,N) => (M=N)

val abeconv_ty = abeconv_Ety []

fun ge_ty t1 t2 = EQ(t1,t2) orelse
                  (*   aconv_ge_ty (deep_beta_eta_ty t1) (deep_beta_eta_ty t2)  *)
                       ge1_ty (head_beta_eta_ty t1) (head_beta_eta_ty t2)
and ge1_ty t1 t2 =
     case(t1,t2)
      of (u as TyFv _, v as TyFv _ ) => type_var_ge(u,v)
       | (u as TyCon _,v as TyCon _) => type_con_ge(u,v)
       | (TyApp(p,t1),TyApp(q,t2)) => ge1_ty p q andalso ge_ty t1 t2
       | (TyAll((_,k1),t1),
          TyAll((_,k2),t2)) => k1 = k2 andalso ge_ty t1 t2
       (* TyAll((_,k2),t2)) => k1 :>=: k2 andalso ge_ty t1 t2 *)
       | (TyExi((_,k1),t1),
          TyExi((_,k2),t2)) => k1 = k2 andalso ge_ty t1 t2
       (* TyExi((_,k2),t2)) => k1 :>=: k2 andalso ge_ty t1 t2 *)
       | (TyAbs((_,k1),t1),
          TyAbs((_,k2),t2)) => k1 = k2 andalso ge1_ty t1 t2
       (* TyAbs((_,k2),t2)) => k1 :>=: k2 andalso ge1_ty t1 t2 *)
       | (M,N) => (M=N)

fun ge_Ety E t1 t2 = EQ(t1,t2) orelse
                  (*   aconv_ge_ty (deep_beta_eta_ty t1) (deep_beta_eta_ty t2)  *)
                       ge1_Ety E (head_beta_eta_Ety E t1) (head_beta_eta_Ety E t2)
and ge1_Ety E t1 t2 =
     case(t1,t2)
      of (u as TyFv _, v as TyFv _ ) => type_var_ge(u,v)
       | (u as TyCon _,v as TyCon _) => type_con_ge(u,v)
       | (TyApp(p,t1),TyApp(q,t2)) => ge1_Ety E p q andalso ge_Ety E t1 t2
       | (TyAll((_,k1),t1),
          TyAll((_,k2),t2)) => k1 = k2 andalso ge_Ety (k1::E) t1 t2
       (* TyAll((_,k2),t2)) => k1 :>=: k2 andalso ge_Ety E t1 t2 *)
       | (TyExi((_,k1),t1),
          TyExi((_,k2),t2)) => k1 = k2 andalso ge_Ety (k1::E) t1 t2
       (* TyExi((_,k2),t2)) => k1 :>=: k2 andalso ge_Ety E t1 t2 *)
       | (TyAbs((_,k1),t1),
          TyAbs((_,k2),t2)) => k1 = k2 andalso ge1_Ety (k1::E) t1 t2
       (* TyAbs((_,k2),t2)) => k1 :>=: k2 andalso ge1_Ety E t1 t2 *)
       | (M,N) => (M=N)

val ge_ty = ge_Ety []

end

val eq_ty = abeconv_ty

(* fun subtype t1 t2 = asubtype (deep_beta_eta_ty t1) (deep_beta_eta_ty t2) *)

local
fun align_types0 [] = (([],[]),(0,false))
  | align_types0 ({redex,residue} :: s) =
      Kind.raw_match_kind (kind_of redex) (kind_of residue) (align_types0 s)
in
fun align_types theta = let
        val ((kdS,_),(rkS,_)) = Kind.norm_subst (align_types0 theta)
        val inst_fn = inst_rank_kind (kdS,rkS)
        fun inst_redex [] = []
          | inst_redex ({redex,residue} :: s) = let
                val redex' = inst_fn redex
              in
                if eq_ty redex' residue then inst_redex s
                else (redex' |-> residue) :: inst_redex s
              end
      in
        (if rkS=0 andalso null kdS then theta else inst_redex theta, kdS, rkS)
      end
      handle e as HOL_ERR _ => raise ERR "align_types" "alignment failed"
end

(* type_subst aligns the ranks and kinds of its substitution *)
fun type_subst theta =
  let val Theta = align_types theta
  in inst_rk_kd_ty Theta
  end
  handle e as HOL_ERR _ => raise (wrap_exn "Type" "type_subst" e)

fun ty_sub theta ty = let val ty' = pure_type_subst theta ty
                      in if type_eq ty ty' then SAME
                                           else DIFF ty'
                      end;


(*---------------------------------------------------------------------------
   Full propagation of substitutions. (unnecessary if no type substitutions)
 ---------------------------------------------------------------------------*)

local
  fun tyvars_sigma_norm (s,ty) =
    case ty of
      TyFv _ => ty
    | TyBv i =>
        (case Subst.exp_rel(s,i) of
           (0, SOME v)   => tyvars_sigma_norm (Subst.id, v)
         | (lams,SOME v) => tyvars_sigma_norm (Subst.shift(lams,Subst.id),v)
         | (lams,NONE)   => TyBv lams)
    | TyApp(Opr,Ty) => TyApp(tyvars_sigma_norm(s, Opr),
                             tyvars_sigma_norm(s, Ty ))
    | TyAll(Btyvar,Body) => TyAll(Btyvar, tyvars_sigma_norm (Subst.lift(1,s),
                                                             Body))
    | TyExi(Btyvar,Body) => TyExi(Btyvar, tyvars_sigma_norm (Subst.lift(1,s),
                                                             Body))
    | TyAbs(Btyvar,Body) => TyAbs(Btyvar, tyvars_sigma_norm (Subst.lift(1,s),
                                                             Body))
    | _ => ty  (* i.e., a const *)
in
fun norm_clos ty = tyvars_sigma_norm(Subst.id,ty)
end

(*---------------------------------------------------------------------------*
 *  Raw syntax prettyprinter for types.                                      *
 *---------------------------------------------------------------------------*)

val dot     = "."
val dollar  = "$"
val percent = "%";

fun pp_raw_type pps ty =
 let open Portable
     val {add_string,add_break,begin_block,end_block,...} = with_ppstream pps
     fun fetch 0 (v :: _) = v
       | fetch n (_ :: vs) = fetch (n-1) vs
       | fetch _ _ = raise ERR "pp_raw_type" "fetch failed"
     val pp_kind = Kind.pp_kind pps
     fun pp_kind_p kind =
          ( if kind = typ rho then ()
            else (add_string ":"; pp_kind kind) )
(*
     fun pp_kind_rank (kind,rank) =
          ( if kind = typ rho then ()
            else (add_string ":"; pp_kind kind);
            if rank = 0 then ()
            else add_string ("/"^Lib.int_to_string rank) )
*)
     fun pp e (TyAbs(Btyvar,Body)) =
          ( add_string "(\\";
            pp e (TyFv Btyvar); add_string dot; add_break(1,0);
            pp (TyFv Btyvar :: e) Body; add_string ")" )
      | pp e (TyAll(Btyvar,Body)) =
          ( add_string "(!";
            pp e (TyFv Btyvar); add_string dot; add_break(1,0);
            pp (TyFv Btyvar :: e) Body; add_string ")" )
      | pp e (TyExi(Btyvar,Body)) =
          ( add_string "(?";
            pp e (TyFv Btyvar); add_string dot; add_break(1,0);
            pp (TyFv Btyvar :: e) Body; add_string ")" )
      | pp e (TyApp(Rator as TyApp(TyCon(id,_),Rand1),Rand2)) =
          if KernelSig.name_of id = "fun"
          then
          ( add_string "("; pp e Rand1;
            add_string " ->"; add_break(1,0);
            pp e Rand2; add_string ")" )
          else
          ( add_string "("; pp e Rand2; add_break(1,0);
                            pp e Rator; add_string ")")
      | pp e (ty as TyApp(Rator,Rand)) =
          let val (c,args) = strip_app_type ty
          in if length args = 1 then
          ( add_string "("; pp e Rand; add_break(1,0);
                            pp e Rator; add_string ")")
             else
          ( add_string "(("; pps e args; add_string ")";
            add_break(1,0); pp e c; add_string ")" )
          end
      | pp e (TyBv i) = (pp e (fetch i e)
                         handle HOL_ERR _ => add_string (dollar^Lib.int_to_string i)) (* this line only for debugging *)
                        (* add_string (dollar^Lib.int_to_string i) *)
      | pp e (TyFv (name,kind)) =
         ( add_string name;
           pp_kind_p kind )
      | pp e (TyCon (id,kind)) =
         ( add_string ( (* seg_of id^dollar^ *) KernelSig.name_of id);
           pp_kind_p kind )
    and pps e [] = ()
      | pps e [ty] = pp e ty
      | pps e (ty :: tys) = (pp e ty; add_string ",";
                           add_break(0,0); pps e tys)
 in
   begin_block INCONSISTENT 0;
   add_string "`:";
   pp [] (norm_clos ty);
   add_string "`";
   end_block()
 end;

(*---------------------------------------------------------------------------*)
(* Send the results of prettyprinting to a string                            *)
(*---------------------------------------------------------------------------*)

fun sprint pp x = HOLPP.pp_to_string 80 pp x

val type_to_string = sprint pp_raw_type;

(*
val _ = installPP Kind.pp_kind;
val _ = installPP pp_raw_type;
*)

fun inst_to_string inst = "[" ^ inst_to_string0 inst ^ "]"
and inst_to_string0 [] = ""
  | inst_to_string0 [x] = inst_to_string1 x
  | inst_to_string0 (x::xs) = inst_to_string1 x ^ ",\n " ^ inst_to_string0 xs
and inst_to_string1 {redex,residue} = type_to_string redex ^ " |-> " ^ type_to_string residue;


(*---------------------------------------------------------------------------
       Higher order matching (from jrh via Michael Norrish - June 2001)
       Adapted to HOL-Omega types by PVH - July 18, 2008
 ---------------------------------------------------------------------------*)

local
  fun MERR s = raise ERR "raw_match_type error" s
  val trace_complex_matching = ref 0
  val _ = Feedback.register_trace ("Type.trace_complex_matching",
                                   trace_complex_matching, 1)
  exception NOT_FOUND
  val eq_ty = abeconv_ty (* beta- and eta-reduction NOT ASSUMMED before entering these functions *)
  fun find_residue red [] = raise NOT_FOUND
    | find_residue red ({redex,residue}::rest) = if red = redex then residue
                                                    else find_residue red rest
  fun find_residue_ty red [] = raise NOT_FOUND
    | find_residue_ty red ({redex,residue}::rest) = if eq_ty red redex then residue
                                                    else find_residue_ty red rest
  fun in_dom x [] = false
    | in_dom x ({redex,residue}::rest) = (x = redex) orelse in_dom x rest
  fun safe_insert_ty (n as {redex,residue}) l = let
    val z = find_residue(*_ty*) redex l
  in
    if residue = z then l
    else raise ERR "safe_insert_ty" "match"
  end handle NOT_FOUND => n::l
  (* Assumming all redexes are type variables, they may be compared by equality *)
  fun safe_insert_tya (n as {redex,residue}) l = let
    val z = find_residue(*_ty*) redex l
  in
    if eq_ty residue z then l
    else raise ERR "safe_insert_tya" "match"
  end handle NOT_FOUND => n::l
(*
  val mk_dummy_ty = let
    val name = dest_vartype(gen_tyvar())
  in fn kd => with_flag (varcomplain,false) mk_var_type(name, kd)
  end
*)
  fun mk_fresh_dummy_ty () = let
    val name = dest_vartype(gen_tyvar())
  in fn kd => with_flag (varcomplain,false) mk_var_type(name, kd)
  end
  val mk_dummy_ty = mk_fresh_dummy_ty ()
(**)
  val dummy_name = fst(dest_var_type (mk_dummy_ty (typ 0)))
  fun is_dummy_ty ty = (*is_gen_tyvar ty andalso*) not (fst(dest_var_type ty) = dummy_name)
(**)
  val mk_con_dummy_ty = mk_fresh_dummy_ty ()
  val con_dummy_name = fst(dest_var_type (mk_con_dummy_ty (typ 0)))
  fun is_con_dummy_ty ty = (fst(dest_var_type ty) = con_dummy_name)
  fun var_cmp (x as TyFv(xs,xkd)) (TyFv(ys,ykd)) =
      (xs = ys) andalso (if is_con_dummy_ty x then xkd :=: ykd
                         else if xs=dummy_name then ykd :>=: xkd
                         else xkd = ykd)
    | var_cmp anything other = false

  fun rator_type ty = fst (dest_app_type ty)
  fun kindE [] = ([],[])
    | kindE ({redex,residue}::s) =
        let val (E1,E2) = kindE s
        in (kind_of redex::E1, kind_of residue::E2)
        end


(*
  fun type_pmatch lconsts env pat ob sofar
      = type_pmatch_1 lconsts env (head_beta_ty pat) (head_beta_ty ob) sofar
                               handle e => raise (wrap_exn "Type" ("type_pmatch:"
^"\n"^ type_to_string pat ^ "\n |-> " ^ type_to_string ob ^ "\n"
) e)

  and type_pmatch_1 lconsts env (TyBv i) (TyBv j) sofar
      = if i=j then sofar
        else MERR "bound type variable mismatch"
    | type_pmatch_1 lconsts env (TyBv _) _ sofar
      = MERR "bound type variable mismatch"
    | type_pmatch_1 lconsts env _ (TyBv _) sofar
      = MERR "bound type variable mismatch"
    | type_pmatch_1 lconsts env vty cty (sofar as (insts,homs)) =
    if is_var_type vty then let
        val cty' = find_residue(*_ty*) vty env
      in
        if (*eq_ty*)(*aconv_ty*) cty' = cty then sofar else MERR "type variable mismatch"
      end handle NOT_FOUND =>
                 if HOLset.member(lconsts, vty) then
                   if cty = vty then sofar
                   else MERR "can't instantiate local constant type"
                 else ((safe_insert_tya (vty |-> cty) insts, homs)
                               handle e => raise (wrap_exn "Type" ("type_pmatch_1.is_var_type"
^"\n"^ type_to_string vty ^ " |-> " ^ type_to_string cty ^ "\n" ^ inst_to_string insts ^ "\n"
) e))
               | HOL_ERR _ => MERR "free type variable mismatch"
    else if is_con_type vty then let
        val {Thy = vthy, Tyop = vname, Kind = vkd} = dest_thy_con_type vty
        val {Thy = cthy, Tyop = cname, Kind = ckd} = dest_thy_con_type cty
                handle HOL_ERR _ => MERR "type constant mismatched with non-constant"
      in
        if vname = cname andalso vthy = cthy then
          if ckd = vkd then sofar
          else let val mk_dummy_ty = mk_con_dummy_ty
               in
               (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
                               handle e => raise (wrap_exn "Type" "type_pmatch_1.is_con_type" e)
               end
        else MERR "type constant mismatch"
      end
    else if is_abs_type vty then let
        val (vv,vbod) = dest_abs_type vty
        val (cv,cbod) = dest_abs_type cty
                handle HOL_ERR _ => MERR "abstraction type mismatched with non-abstraction type"
        val (_, vkd) = dest_var_type vv
        val (_, ckd) = dest_var_type cv
        val sofar' = (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
                               handle e => raise (wrap_exn "Type" "type_pmatch_1.is_abs_type" e)
      in
        type_pmatch lconsts ((vv |-> cv)::env) vbod cbod sofar'
      end
    else if is_univ_type vty then let
        val (vv,vbod) = dest_univ_type vty
        val (cv,cbod) = dest_univ_type cty
                handle HOL_ERR _ => MERR "universal type mismatched with non-universal type"
        val (_, vkd) = dest_var_type vv
        val (_, ckd) = dest_var_type cv
        val sofar' = (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
                               handle e => raise (wrap_exn "Type" "type_pmatch_1.is_univ_type" e)
      in
        type_pmatch lconsts ((vv |-> cv)::env) vbod cbod sofar'
      end
    else if is_exist_type vty then let
        val (vv,vbod) = dest_exist_type vty
        val (cv,cbod) = dest_exist_type cty
                handle HOL_ERR _ => MERR "existential type mismatched with non-existential type"
        val (_, vkd) = dest_var_type vv
        val (_, ckd) = dest_var_type cv
        val sofar' = (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
                               handle e => raise (wrap_exn "Type" "type_pmatch_1.is_exist_type" e)
      in
        type_pmatch lconsts ((vv |-> cv)::env) vbod cbod sofar'
      end
    else (* is_app_type *) let
        val vhop = repeat rator_type vty
      in
        if is_var_type vhop andalso not (HOLset.member(lconsts, vhop)) andalso
           not (in_dom vhop env)
        then let (* kind_of can fail if given an open type with free bound variables, as cty might be *)
            val (vE,cE) = kindE env
            val vkd = kd_of vty vE
            val ckd = kd_of cty cE
            val insts' = if vkd = ckd then insts
                         else safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts
                               handle e => raise (wrap_exn "Type" "type_pmatch_1.is_app_type" e)
          in
            (insts', (env,cty,vty)::homs)
          end
        else let
            val (lv,rv) = dest_app_type vty
            val (lc,rc) = dest_app_type cty
                handle HOL_ERR _ => MERR "application type mismatched with non-application type"
            val sofar' = type_pmatch_1 lconsts env lv lc sofar (* lv,lc are head-beta-reduced *)
          in
            type_pmatch lconsts env rv rc sofar'
          end
      end
*)

  fun type_pmatch lconsts env pat ob sofar
      = type_pmatch_1 lconsts env (head_beta_eta_ty pat) (head_beta_eta_ty ob) sofar

  and type_pmatch_1 lconsts env (vty as TyFv(_,kd)) cty (sofar as (insts,homs))
      = (let
           val cty' = find_residue vty env
         in
           if cty' = cty then sofar else MERR "free type variable mismatch"
         end handle NOT_FOUND =>
                 if HOLset.member(lconsts, vty) then
                   if cty = vty then sofar
                   else MERR "can't instantiate local constant type"
                 else (safe_insert_tya (vty |-> cty) insts, homs)
               | HOL_ERR _ => MERR "free type variable mismatch")
    | type_pmatch_1 lconsts env (vty as TyCon(vc,vkd)) cty (sofar as (insts,homs))
      = (case cty of
            TyCon(cc,ckd) =>
              if vc = cc then
                if ckd = vkd then sofar
                else let val mk_dummy_ty = mk_con_dummy_ty
                     in (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
                     end
              else MERR "type constant mismatch"
          | _ => MERR "type constant mismatched with non-constant")
    | type_pmatch_1 lconsts env (vty as TyApp(lv,rv)) cty (sofar as (insts,homs))
      = let
          val vhop = repeat rator_type lv
        in
          if is_var_type vhop andalso not (HOLset.member(lconsts, vhop)) andalso
             not (in_dom vhop env)
          then
            let (* kind_of can fail if given an open type with free bound variables, as cty might be *)
              val (vE,cE) = kindE env
              val vkd = kd_of vty vE
              val ckd = kd_of cty cE
              val insts' = if vkd = ckd then insts
                           else safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts
            in
              (insts', (env,cty,vty)::homs)
            end
          else
            case cty of
               TyApp(lc,rc) =>
                 let
                   val sofar' = type_pmatch_1 lconsts env lv lc sofar (* lv,lc are head-beta-eta-reduced *)
                 in
                   type_pmatch lconsts env rv rc sofar'
                 end
             | _ => MERR "application type mismatched with non-application type"
        end
    | type_pmatch_1 lconsts env (TyBv i) cty sofar
      = (case cty of
            (TyBv j) => if i=j then sofar
                        else MERR "bound type variable mismatch"
          | _ => MERR "bound type variable mismatch")
    | type_pmatch_1 lconsts env (vty as TyAbs((_,vkd),_)) cty (insts,homs)
      = (case cty of
           TyAbs((_,ckd),_) =>
             let
               val (vv,vbody) = dest_abs_type vty
               val (cv,cbody) = dest_abs_type cty
               val sofar' = (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
             in
               type_pmatch_1 lconsts ((vv |-> cv)::env) vbody cbody sofar' (* bodies are head-beta-eta reduced *)
             end
         | _ => MERR "abstraction type mismatched with non-abstraction type")
    | type_pmatch_1 lconsts env (vty as TyAll((_,vkd),_)) cty (insts,homs)
      = (case cty of
           TyAll((_,ckd),_) =>
             let
               val (vv,vbody) = dest_univ_type vty
               val (cv,cbody) = dest_univ_type cty
               val sofar' = (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
             in
               type_pmatch lconsts ((vv |-> cv)::env) vbody cbody sofar'
             end
         | _ => MERR "universal type mismatched with non-universal type")
    | type_pmatch_1 lconsts env (vty as TyExi((_,vkd),_)) cty (insts,homs)
      = (case cty of
           TyExi((_,ckd),_) =>
             let
               val (vv,vbody) = dest_exist_type vty
               val (cv,cbody) = dest_exist_type cty
               val sofar' = (safe_insert_tya (mk_dummy_ty vkd |-> mk_dummy_ty ckd) insts, homs)
             in
               type_pmatch lconsts ((vv |-> cv)::env) vbody cbody sofar'
             end
         | _ => MERR "existential type mismatched with non-existential type")



fun get_rank_kind_insts avoids (env:(hol_type,hol_type)subst) L ((kdS,Id),rk) =
    let val (vE,cE) = kindE env
    in
      itlist (fn {redex,residue} =>
                 prim_match_kind (is_con_dummy_ty redex)
                                 (kd_of redex   vE)
                                 (kd_of residue cE))
             L ((kdS,union avoids Id),rk)
    end

fun separate_insts_ty lift rk kdavoids kdS env
         (insts :{redex : hol_type, residue : hol_type} list) = let
  val (realinsts, patterns) = partition (is_var_type o #redex) insts
  val betacounts =
      if patterns = [] then []
      else
        itlist (fn {redex = p,...} =>
                   fn sof => let
                        val (hop,args) = strip_app_type p
                      in
                        safe_insert_ty (hop |-> length args) sof
                      end handle _ =>
                                 (HOL_WARNING "" ""
                                  "Inconsistent patterning in h.o. type match";
                                  sof))
        patterns []
  val rk_kd_ins as (kdins,rkin as (rkS',_)) = get_rank_kind_insts kdavoids env realinsts (kdS,rk)
  val kdins' as (kdS',_) = fst (Kind.norm_subst rk_kd_ins)
  val inst_rk_kd = Kind.inst_rank_kind (kdS',rkS')
in
  (betacounts,
   mapfilter (fn {redex = x, residue = t} => let
                   val x' = let val (xs,xkd) = dest_var_type x
                            in with_flag (varcomplain,false)
                              mk_var_type(xs, inst_rk_kd xkd)
                            end
                 in
                   if var_cmp t x' (* orelse ge_ty x' t (*not t = x'*) *) then raise ERR "separate_insts_ty" ""
                             else {redex = if lift then x' else x, residue = t}
             end) realinsts,
   if lift then kdins' else kdins,
   rkin)
end


fun kdenv_in_dom x (env, idlist) = mem x idlist orelse in_dom x env
fun kdenv_find_residue x (env, idlist) = if mem x idlist then x
                                         else find_residue x env
fun kdenv_safe_insert (t as {redex,residue}) (E as (env, idlist)) = let
  val existing = kdenv_find_residue redex E
in
  if existing = residue then E else raise ERR "kdenv_safe_insert" "Kind bindings clash"
end handle NOT_FOUND => if redex = residue then (env, redex::idlist)
                        else (t::env, idlist)


fun all_abconv [] [] = true
  | all_abconv [] _ = false
  | all_abconv _ [] = false
  | all_abconv (h1::t1) (h2::t2) = eq_ty h1 h2 andalso all_abconv t1 t2

fun freeze_operators vhops insts =
  List.foldr (fn (ty,insts) => safe_insert_tya (ty |-> ty) insts) insts vhops

fun map_redexes f =
  map (fn {redex,residue} => f redex |-> residue)
fun subst_redexes theta = map_redexes (pure_type_subst theta)
fun map_insts f =
  map (fn {redex,residue} => f redex |-> f residue)
fun swap_subst theta =
  map (fn {redex,residue} => residue |-> redex) theta

fun split_insts vhops insts =
  partition (fn {redex, residue} =>
             op_mem eq_ty (fst (strip_app_type redex)) vhops) insts

fun print_insts str insts =
  (print (str ^ " insts:\n");
   print_insts0 insts)
and
    print_insts0 [] = ()
  | print_insts0 (inst::insts) = (print_inst inst; print_insts0 insts)
and
    print_inst {redex,residue} =
             print ("   " ^ type_to_string redex ^
                    " |-> " ^ type_to_string residue ^ "\n") ;

fun distinct (x::xs) = not (Lib.mem x xs) andalso distinct xs
  | distinct [] = true;


fun type_homatch kdavoids lconsts rkin kdins (insts, []) = insts
  | type_homatch kdavoids lconsts rkin kdins (insts, homs) = let
  (* local constants of kinds and types never change *)
  val (var_homs,nvar_homs) = partition (fn (env,cty,vty) => is_var_type vty) homs
  fun args_are_fixed (env,cty,vty) = let
       val (vhop, vargs) = strip_app_type vty
       val afvs = type_varsl vargs
    in all (fn a => can (find_residue(*_ty*) a) env orelse can (find_residue(*_ty*) a) insts
                    orelse HOLset.member(lconsts, a)) afvs
    end
  val (fixed_homs,basic_homs) = partition args_are_fixed nvar_homs
  fun args_are_distinct_vars (env,cty,vty) = let
       val (vhop, vargs) = strip_app_type vty
       fun distinct (x::xs) = not (mem x xs) andalso distinct xs
         | distinct _ = true
    in all is_var_type vargs andalso distinct vargs
    end
  val (distv_homs,real_homs) = partition args_are_distinct_vars fixed_homs
  val ordered_homs = var_homs @ distv_homs @ real_homs @ basic_homs
  val (kdins',_) = Kind.norm_subst(kdins,rkin)
  val inst_fn = inst_rank_kind (fst kdins', fst rkin)
  fun fix_con_dummy_ty (i as {redex,residue}) =
    if is_con_dummy_ty redex
      (* then equalize the ranks of the "floating" constant instances *)
      then let val redex' = inst_fn redex
               val inc = Int.max(rank_of_type redex' - rank_of_type residue, 0)
           in redex |-> inst_rank inc residue
           end
      else i
  fun homatch rkin kdins (insts, homs) =
  if homs = [] then insts
  else let
      val (env,cty,vty) = hd homs
    in
      if is_var_type vty then
        if eq_ty cty vty then homatch rkin kdins (insts, tl homs)
        else let
            val vkd = kind_of vty (* kd_of vty (map (kind_of o #redex  ) env) *)
            val ckd = kd_of cty (map (kind_of o #residue) env)
            val (kdins',newrkin)  = raw_match_kind vkd ckd (kdins,rkin)
            val newkdins = kdenv_safe_insert (vkd |-> ckd) kdins'
            val newinsts = safe_insert_tya (vty |-> cty) insts (* (vty |-> cty)::insts *)
          in
            homatch newrkin newkdins (newinsts, tl homs)
          end
      else (* vty not a type var *) let
          val (vhop, vargs) = strip_app_type vty (* vhop should be a type operator variable *)
          val afvs = type_varsl vargs
          val (kdins',_) = Kind.norm_subst(kdins,rkin)
          val inst_fn = inst_rank_kind (fst kdins', fst rkin)
          (*exp*) val schem_fvs = Lib.subtract afvs (map #redex (env @ insts))
          val schem_fvs' = map inst_fn schem_fvs
        in
          (let
             val _ = null schem_fvs
                       orelse all (C mem (type_vars cty)) schem_fvs'
                       orelse raise ERR "type_homatch" "not schematic"
             val tyins =
                 map (fn a =>
                         (inst_fn a |->
                                  (find_residue a env
                                   handle _ =>
                                          find_residue a insts
                                   handle _ =>
                                          if HOLset.member(lconsts, a)
                                          then a
                                          else inst_fn a))) afvs (* experiment: schematic type vars *)
                                       (* else raise ERR "type_homatch" "not bound"))) afvs *) (* normal *)
             val pats0 = map inst_fn vargs
             val pats = map (pure_type_subst tyins) pats0
             val vhop' = inst_fn vhop
             (* val icty = list_mk_app_type(vhop', pats) *)
             val ni = let
               val (chop,cargs) = strip_app_type cty
             in
               if all_abconv cargs pats then
                 if eq_ty chop vhop then insts
                 else safe_insert_tya (vhop |-> chop) insts
               else let
                   val kdEnv = map (kind_of o #redex) env
                   val ginsts = map (fn p => (p |->
                                                (if is_var_type p then p
                                                 else gen_var_type(kd_of p kdEnv))))
                                    pats
                   val cty' = full_type_subst ginsts cty
                   val gvs = map #residue ginsts
                   val absty = list_mk_abs_type(gvs,cty')
                   (*exp*) val _ = null (intersect schem_fvs' (type_vars absty))
                                   orelse raise ERR "type_homatch" "schematic type var in ho binding"
                   val vinsts = safe_insert_tya (vhop |-> absty) insts
                   val vinsts = List.foldl (fn ((v,v'),ins) => safe_insert_tya (v |-> v') ins)
                                           vinsts (Lib.zip schem_fvs schem_fvs')
                   (* val icpair = (list_mk_app_type(vhop',gvs) |-> cty') *)
                 in
                   (* safe_insert_tya icpair *) vinsts
                   (* icpair::vinsts *)
                 end
             end
           in
             homatch rkin kdins (ni,tl homs)
           end) handle HOL_ERR _ => (
                       let
                         val chop = find_residue(*_ty*) vhop insts (* may raise NOT_FOUND *)
                         val _ = if eq_ty vhop chop then raise NOT_FOUND else ()
                         val vty1 = deep_beta_eta_ty (pure_type_subst (map_redexes inst_fn (env@insts)) (inst_fn vty))
                                        handle HOL_ERR _ => vty
                       in
                         if eq_ty vty1 cty then
                           (* drop this hom as subsumed by current insts *)
                           homatch rkin kdins (insts,tl homs)
                         else let
                           val _ = if !trace_complex_matching = 0 then () else
                                     (print ("Complex match " ^ type_to_string vty ^ "\n" ^
                                             "           to " ^ type_to_string cty ^ "\n"))
                           fun types_to_string (ty::tys) = " " ^ type_to_string ty ^ types_to_string tys
                             | types_to_string    []     = ""
                           val lconstsl = HOLset.listItems lconsts
                           val fixed = map #redex env @ lconstsl
                           val vfixed = vhop :: fixed
                           val pat_tyvars = subtract (type_vars vty) vfixed
                           val vfixed1 = map inst_fn vfixed
                           val freeze_tyvars = subtract (type_vars chop) (map #residue env @ lconstsl)
                           val all_pvars = Lib.U [pat_tyvars, fixed,
                                                  filter is_var_type (map #redex insts)]
                           val all_pvars1 = map inst_fn all_pvars
                           val all_tvars = Lib.U [freeze_tyvars, type_vars cty, map #residue env,
                                                  type_varsl (map #residue insts)]
                           val all_vars = union all_pvars1 all_tvars
                           fun new_tyvar (v,vs) = (if mem v freeze_tyvars
                                                      then variant_type (vs @ all_vars) v
                                                           (* gen_var_type(kind_of v,rank_of v) *)
                                                      else v) :: vs
                           val mod_pvars = intersect (subtract all_pvars1 vfixed1) freeze_tyvars
                           val mod_pvars' = foldr new_tyvar [] mod_pvars
                           (* now there are no tyvars in both all_pvars1 and freeze_tyvars *)
                           val theta = map (op |->) (zip mod_pvars mod_pvars')
                           val vhop' = inst_fn vhop
                           val vty'  = inst_fn vty
                           val vty1' = deep_beta_eta_ty (pure_type_subst ((vhop' |-> chop)::theta) vty')
                                         handle HOL_ERR _ =>
                                            (if !trace_complex_matching = 0 then () else
                                                (print ("Formation of new pattern failed: " ^
                                                 type_to_string vty' ^ " [" ^ type_to_string chop ^
                                                 " / " ^ type_to_string vhop' ^ "]\n"));
                                             raise NOT_FOUND)
                           val (vhop_str,_) = dest_var_type vhop
                           val _ = if !trace_complex_matching = 0 then () else
                                     (print ("  Expanding type operator " ^ vhop_str
                                             ^ " |-> " ^ type_to_string chop ^ "\n");
                                      print ("     Matching " ^ type_to_string vty1' ^ "\n" ^
                                             "           to " ^ type_to_string cty   ^ "\n");
                                      print ("  freezing:" ^ types_to_string freeze_tyvars ^ "\n");
                                      print ("  pattern: " ^ types_to_string pat_tyvars  ^ "\n");
                                      print ("  modifying pat tyvars:" ^ types_to_string mod_pvars  ^ "\n");
                                      if mod_pvars = mod_pvars' then () else
                                      print ("            renamed as:" ^ types_to_string mod_pvars' ^ "\n");
                                      if map #redex env = map #residue env then () else
                                      print_insts "environment" env)
                           val (f_insts0,nf_insts0) = split_insts freeze_tyvars insts
                           val nf_insts1 = map_redexes (fn ty => if is_var_type ty then inst_fn ty
                                                                 else ty)
                                                       nf_insts0
                           val nf_insts2 = subst_redexes theta nf_insts1
                           val _ = if !trace_complex_matching = 0 then () else
                                     (print_insts "all original" insts;
                                      print_insts "pre-freeze" f_insts0;
                                      print_insts "instantiated" nf_insts1;
                                      if mod_pvars = mod_pvars' then () else
                                      print_insts "renamed" nf_insts2)
                           val env' = map_redexes inst_fn env
                           val insts' = freeze_operators freeze_tyvars nf_insts2
                                        handle HOL_ERR _ =>
                                          (* conflicts with existing inst? should never happen *)
                                          (if !trace_complex_matching = 0 then () else
                                             print "  Freezing operators failed.\n";
                                           raise NOT_FOUND)
                           val _ = if !trace_complex_matching = 0 then () else
                                     (print_insts "subproblem" insts')
                         in let
                           val pinsts_homs' =
                             type_pmatch lconsts env' vty1' cty (insts', [] (* note NOT tl homs! *))
                           val (kdins',rkin') =
                             get_rank_kind_insts kdavoids env'
                                        (fst pinsts_homs')
                                        (([], []), (0, false))
                           val new_insts = homatch rkin' kdins' pinsts_homs'
                           (* new_insts is the answer from the subproblem *)
                           val (_,nf_insts3) = split_insts freeze_tyvars new_insts
                           val nf_insts4 = subst_redexes (swap_subst theta) nf_insts3
                           val inv_inst = zip all_pvars1 all_pvars
                           fun lookup v = assoc v inv_inst handle _ => v
                           val nf_insts5 = map_redexes lookup nf_insts4
                           val insts' = f_insts0 @ nf_insts5
                           val _ = if !trace_complex_matching = 0 then () else
                                     (print ("Expanding type operator " ^ vhop_str ^ " succeeded!\n");
                                      print_insts "subproblem yielded" new_insts;
                                      print_insts "non-frozen new" nf_insts3;
                                      if mod_pvars = mod_pvars' then () else
                                      print_insts "un-renamed new" nf_insts4;
                                      print_insts "un-instantiated" nf_insts5;
                                      print_insts "final result" insts';
                                      print "\n")
                         in
                           homatch rkin' kdins' (insts', tl homs)
                         end
                         handle e => (if !trace_complex_matching = 0 then () else
                                        (print "Subproblem failed.\n";
                                         print ("Expanding type operator " ^ vhop_str ^ " failed:" ^
                                                Feedback.exn_to_string e ^ "\n"));
                                      raise NOT_FOUND)
                         end
                       end
                handle NOT_FOUND => let
                         val (lc,rc) = dest_app_type cty
                         val (lv,rv) = dest_app_type vty
                         val pinsts_homs' =
                             type_pmatch lconsts env rv rc
                                         (insts, (env,lc,lv)::(tl homs))
                         val (kdins',rkin') =
                             get_rank_kind_insts kdavoids env
                                            (fst pinsts_homs')
                                            (([], []), (0, false))
                       in
                         homatch rkin' kdins' pinsts_homs'
                       end)
        end
    end
in
  homatch rkin kdins (map fix_con_dummy_ty insts, ordered_homs)
end

in

val type_pmatch = type_pmatch
val get_rank_kind_insts = get_rank_kind_insts
val type_homatch = type_homatch
val separate_insts_ty = separate_insts_ty

fun ho_match_type1 lift kdavoids lconsts vty cty insts_homs rk_kd_insts_ids = let
  val pinsts_homs = type_pmatch lconsts [] vty cty insts_homs
  val (kdins,rkin) = get_rank_kind_insts kdavoids [] (fst pinsts_homs) rk_kd_insts_ids
  val insts = type_homatch kdavoids lconsts rkin kdins pinsts_homs
in
  separate_insts_ty lift rkin kdavoids kdins [] insts
end

fun ho_match_type0 lift rkfixed kdavoids lconsts vty cty = let
  val (bcs, tyins, kdins, rkin) = ho_match_type1 lift kdavoids lconsts vty cty ([], []) (([], []), (0,rkfixed))
in
  (tyins, fst kdins, fst rkin)
end handle e => raise (wrap_exn "HolKernel" "ho_match_type" e)

(* Note this checks with ge_ty for greater than or equal (of ranks), not eq_ty *)
fun check_achieves_target Theta vty cty = 
  if ge_ty (inst_rk_kd_ty Theta vty) cty then ()
   else raise ERR "ho_match_type" "higher-order type matching failed to achieve target type"

fun ho_match_type rkfixed kdavoids lconsts vty cty = let
(*
  val vty' = deep_beta_eta_ty vty
  val cty' = deep_beta_eta_ty cty
*)
  val (tyins, kdins, rkin) = ho_match_type0 true rkfixed kdavoids lconsts vty cty
  val _ = check_achieves_target (tyins, kdins, rkin) vty cty
in (tyins, kdins, rkin)
end

end (* local *)

(* We redefine the main type matching functions here to use higher order matching. *)

fun prim_kind_match_type pat ob ((tyS,tyId), (kdS,kdId), rkS) =
    let val tyfixed = HOLset.addList(empty_tyset, tyId)
        val (_,tyS',(kdS',kdId'),rkS') = ho_match_type1 false kdId tyfixed pat ob (tyS,[]) ((kdS,kdId),rkS)
     in ((tyS',tyId), (kdS',kdId'), rkS')
    end;


(*--------------------------------------------------------------------------------
    Matching (first order) of types, including sets of type variables to avoid binding.
    Does not attempt to match kinds or ranks, only checks they are equal.
    The general algorithm is higher order matching of types, modulo alpha-beta-eta conversion.
    This is used as a first try for matching, since faster than higher order matching.
    Throws HIGHER_ORDER if a more complex type is found in the pattern type.
 --------------------------------------------------------------------------------*)

exception HIGHER_ORDER
local
  fun MERR s = raise ERR "raw_match_type error" s
(*
  fun free (TyBv i) n         = i<n
    | free (TyApp(Opr,Arg)) n = free Opr n andalso free Arg n
    | free (TyAll(_,Body)) n  = free Body (n+1)
    | free (TyExi(_,Body)) n  = free Body (n+1)
    | free (TyAbs(_,Body)) n  = free Body (n+1)
    | free _ _                = true
  fun bound_by_scope scoped M = if scoped then not (free M 0) else false
*)
(* for "ids" a HOLset: *)
  fun lookup x ids =
   let fun look [] = if HOLset.member(ids,x) then SOME x else NONE
         | look ({redex,residue}::t) = if x=redex then SOME residue else look t
   in look end
(* for "ids" a list:
  fun lookup x ids =
   let fun look [] = if Lib.mem x ids then SOME x else NONE
         | look ({redex,residue}::t) = if x=redex then SOME residue else look t
   in look end
*)
  val kdmatch = Kind.raw_match_kind
(*
  fun tymatch pat ob ((lctys,env,insts_homs),kdS,rkS) =
        let val insts_homs' = type_pmatch lctys env pat ob insts_homs
            val (rkS',kdS') = get_rank_kind_insts [] env (fst insts_homs') (rkS,kdS)
        in ((lctys,env,insts_homs'),kdS',rkS')
        end
  fun add_env mp (lctys,env,insts_homs) = (lctys,mp::env,insts_homs)
  fun drop_env ((lctys,env,insts_homs),kdS,rkS) = ((lctys,tl env,insts_homs),kdS,rkS)
  fun tasks (ty1::tys1) (ty2::tys2) s rst = (ty1,ty2,s)::tasks tys1 tys2 s rst
    | tasks [] [] s rst = rst
    | tasks _ _ _ _ = MERR "different arities of type operators"
*)
in
fun RM [] [] theta = theta
  | RM (pat::pats) (ob::obs) theta =
      RM0 (head_beta_eta_ty pat::pats) (head_beta_eta_ty ob::obs) theta
  | RM all others _       = MERR "different constructors"
(* RM0 can only be called with non-null type lists,
   the first elements of which are head-beta-eta reduced. *)
and RM0 ((TyApp (opr1,arg1))::ps) ((TyApp (opr2,arg2))::obs) tyS
      = let
        in case opr1 of
              TyFv _ => raise HIGHER_ORDER
            | TyBv _ => raise HIGHER_ORDER
            | _ => RM0 (opr1::arg1::ps) (opr2::arg2::obs) tyS
        end
  | RM0 ((TyCon(c1,kd1))::ps) ((TyCon(c2,kd2))::obs) (tyS (*,kdS,rkS*) )
      = RM ps obs
        (if c1 = c2 then
           let (* val (rkS',kdS') = kdmatch kd1 kd2 (rkS,kdS) *)
               val _ = if kd1=kd2 then () else raise HIGHER_ORDER
           in (tyS (*, kdS, rkS*) (* kdS', rkS' *) )
           end
         else
           let val n1 = KernelSig.id_toString c1
               val n2 = KernelSig.id_toString c2
           in MERR ("attempt to match different type constants: "
                    ^n1^" against "^n2)
           end
        )
  | RM0 ((v as TyFv(name,Kd))::ps) (ty::obs) ((S1 as ((tyS,tyId))) (*,kdS,rkS*) )
     = let (*val (rkS',kdS') = kdmatch Kd (kind_of ty) (rkS,kdS)*)
           val _ = if Kd=kind_of ty handle HOL_ERR _ => raise HIGHER_ORDER
                   then () else raise HIGHER_ORDER
            in
               RM ps obs
               ((case lookup v tyId tyS
                  of NONE => if v=ty then (* (tyS,v::tyId) *) (tyS,HOLset.add(tyId,v))
                                     else ((v |-> ty)::tyS,tyId)
                   | SOME ty' => if eq_ty ty' ty then S1
                                 else MERR ("double bind on type variable "^name))
                (*,kdS,rkS*) (*, kdS',rkS' *) )
            end
  | RM0 ((TyBv i)::ps) ((TyBv j)::obs) S
      = if i=j then RM ps obs S
               else MERR "Bound variable depth"
  | RM0 ((TyAll _)::_) _ _ = raise HIGHER_ORDER
  | RM0 ((TyExi _)::_) _ _ = raise HIGHER_ORDER
  | RM0 ((TyAbs _)::_) _ _ = raise HIGHER_ORDER
  | RM0 all others _       = MERR "different constructors"
end


(*

fun raw_match_type pat ob (tyS,tyfixed) =
    let val tyfixed_set = HOLset.addList(empty_tyset, tyfixed)
        val (tyS',Id) =
              RM [(pat,ob,false)] (tyS,tyfixed_set)
        val Id' = HOLset.listItems Id
     in (tyS',Id')
    end;

fun match_type_restr fixed pat ob  = fst (raw_match_type pat ob ([],fixed))
fun match_type_in_context pat ob S = fst (raw_match_type pat ob (S,[]))

fun match_type pat ob = fst (raw_match_type pat ob ([],[]))

*)

fun norm_type_subst 0 [] = I
  | norm_type_subst rkS kdS =
  let val instfn = inst_rank_kind (kdS,rkS)
      fun norm [] = []
        | norm ({redex,residue}::rest) =
            {redex=instfn redex,residue=residue}::norm rest
      val normId = map instfn
  in norm ## normId
  end

fun raw_kind_match_type pat ob ((tyS,tyId), (kdS,kdId), (rkS,rkfixed)) =
    let val tyfixed = HOLset.addList(empty_tyset, tyId)
    in (* works fast for traditional HOL types; throws HIGHER_ORDER for others *)
      let val _ = if null kdS andalso rkS=0 then () else raise HIGHER_ORDER
          (* val (tyS',tyId') = RM [pat] [ob] (tyS,tyId) *)
          val (tyS',tyfixed') = RM [pat] [ob] (tyS,tyfixed)
          val tyId' = HOLset.listItems tyfixed'
      in ((tyS',tyId'), (kdS,kdId), (rkS,rkfixed))
      end
    handle HIGHER_ORDER => (* correct but slow: *)
      let
          val (_,tyS',(kdS',kdId'),(rkS',_)) =
                  ho_match_type1 true kdId tyfixed pat ob (tyS,[]) ((kdS,kdId),(rkS,rkfixed))
          val _ = check_achieves_target (tyS', kdS', rkS') pat ob
          val pat_vars' = map (inst_rank_kind (kdS',rkS')) (type_vars pat)
          val tyId' = Lib.subtract (Lib.union pat_vars' tyId) (map #redex tyS')
      in ((tyS',tyId'), (kdS',kdId'), (rkS',rkfixed))
      end
    end;

(* pure higher-order type matching: correct but slow:
fun raw_kind_match_type pat ob ((tyS,tyId), (kdS,kdId), rkS) =
    let val tyfixed = HOLset.addList(empty_tyset, tyId)
        val (_,tyS',(kdS',kdId'),rkS') =
                  ho_match_type1 true kdId tyfixed pat ob (tyS,[]) ((rkS,rkfixed),(kdS,kdId))
        val _ = check_achieves_target (tyS', kdS', rkS') pat ob
        val pat_vars' = map (inst_rank_kind (kdS',rkS')) (type_vars pat)
        val tyId' = Lib.subtract (Lib.union pat_vars' tyId) (map #redex tyS')
    in ((tyS',tyId'), (kdS',kdId'), (rkS',rkfixed))
    end;
*)

fun clean_subst ((tyS,_),(kdS,_),(rkS,_)) =
 let fun del A [] = A
       | del A ({redex,residue}::rst) =
         del (if eq_ty residue redex then A else (redex |-> residue)::A) rst
 in (del [] tyS,kdS,rkS)
 end

fun kind_match_type pat ob =
      clean_subst (raw_kind_match_type pat ob (([],[]), ([],[]), (0,false)))

fun kind_match_types theta =
 let fun match ({redex,residue},matches) = raw_kind_match_type redex residue matches
 in clean_subst (List.foldr match (([],[]), ([],[]), (0,false)) theta)
 end

fun raw_match_type pat ob (tyS,tyId) =
    let val ((tyS',tyId'),(kdS',kdId'),(rkS',_)) =
              raw_kind_match_type pat ob ((tyS,tyId),([],[]),(0,false))
    in if null kdS' andalso null kdId' andalso rkS' = 0 then (tyS',tyId')
       else raise ERR "raw_match_type"
                  "kind and/or rank variable matches: use raw_kind_match_type instead"
    end;

fun match_type_restr fixed pat ob  = fst (raw_match_type pat ob ([],fixed))
fun match_type_in_context pat ob S = fst (raw_match_type pat ob (S,[]))

fun match_type pat ob = fst (raw_match_type pat ob ([],[]))


(*---------------------------------------------------------------------------
   Redefine the comparison relations
   to involve beta reduction for external use.
 ---------------------------------------------------------------------------*)

val raw_dom_rng = dom_rng
val dom_rng = fn ty => raw_dom_rng ty handle HOL_ERR _ => raw_dom_rng (head_beta_eta_ty ty)

val raw_compare = compare
val compare = fn (t1,t2) => compare(deep_beta_eta_ty t1, deep_beta_eta_ty t2)
val raw_empty_tyset = empty_tyset
val empty_tyset = HOLset.empty compare
val raw_type_eq = type_eq
fun type_eq t1 t2 = compare(t1,t2) = EQUAL;


(*---------------------------------------------------------------------------*
 *       Does a type contain unbound "bound variables" (Bv's)?               *
 *---------------------------------------------------------------------------*)

local fun unb (v as TyBv i,k)    = k <= i
        | unb (TyApp(opr,arg),k) = unb(opr,k) orelse unb(arg,k)
        | unb (TyAll(bv,Body),k) = unb(Body,k+1)
        | unb (TyExi(bv,Body),k) = unb(Body,k+1)
        | unb (TyAbs(bv,Body),k) = unb(Body,k+1)
        | unb (_,_) = false (* e.g., free type variables, constants *)
in
fun unbound_ty ty = unb(ty,0)
end;

fun size acc tylist =
    case tylist of
      [] => acc
    | [] :: tys => size acc tys
    | (ty::tys1) :: tys2 => let
      in
        case ty of
          TyApp(opr, arg) => size acc ((opr :: arg :: tys1) :: tys2)
        | TyAll(_, body)  => size (1 + acc) ((body :: tys1) :: tys2)
        | TyExi(_, body)  => size (1 + acc) ((body :: tys1) :: tys2)
        | TyAbs(_, body)  => size (1 + acc) ((body :: tys1) :: tys2)
        | _               => size (1 + acc) (tys1 :: tys2)
      end

fun type_size ty = size 0 [[ty]]

end (* Type *)
