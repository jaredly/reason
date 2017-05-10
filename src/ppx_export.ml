open Migrate_parsetree
open Ast_404

open Parsetree
open Asttypes
open Ast_mapper
open Ast_helper

(* let%export ... *)
let extract_value value_bindings tail acc current_signatures current_structures  str = (
  let value_descriptions = List.map
    (fun value_binding ->
      match value_binding with
      | { pvb_pat = {ppat_desc = Ppat_var loc; _}; pvb_expr = {pexp_desc = Pexp_constant const; _}; pvb_attributes; pvb_loc } ->
        (* let%export a = 2 -- unannotated export of a constant *)
        let const_type =
          match const with
          | Pconst_integer _ -> "int"
          | Pconst_char _ -> "char"
          | Pconst_string _ -> "string"
          | Pconst_float _ -> "float"
        in
        let value = Val.mk
          ~attrs:pvb_attributes
          loc
          (Typ.constr (Location.mkloc (Longident.Lident const_type) (Location.symbol_gloc ())) [])
        in Sig.mk (Psig_value value)
      | { pvb_pat = {ppat_desc = Ppat_var loc; _}; pvb_expr = { pexp_desc = Pexp_constraint (_, const)}; pvb_attributes; pvb_loc} -> (
        (* let%export a:int = 2 -- an annotated value export *)
          let (const_type, c) =
            match const.ptyp_desc with
            | Ptyp_constr (loc, ct) -> (loc.txt, ct)
            | _ -> print_string "1. Give a proper error that a constraint is expected"; assert false
        in
        let value = Val.mk
          ~attrs:pvb_attributes
          loc
          (Typ.constr (Location.mkloc const_type (Location.symbol_gloc ())) c)
        in Sig.mk (Psig_value value)
        )
      | { pvb_pat = {ppat_desc = Ppat_var loc; _}; pvb_expr = { pexp_desc = Pexp_fun _ as arrow }; pvb_attributes; pvb_loc} -> (
        (* let%export a (b:int) (c:char) : string = "boe" -- function export *)
        let rec process_arguments func =
          match func with
          | Pexp_fun (arg_label, eo, {ppat_desc = Ppat_constraint (_, ct)}, exp) ->
            Typ.arrow
              arg_label
              ct
              (process_arguments exp.pexp_desc)
          (* An unlabeled () unit argument *)
          | Pexp_fun (arg_label, eo, {ppat_desc = Ppat_construct (({txt = Longident.Lident "()"; _}), None)}, exp) ->
            Typ.arrow
              arg_label
              (Typ.constr (Location.mkloc (Longident.Lident "unit") (Location.symbol_gloc ())) [])
              (process_arguments exp.pexp_desc)
          | Pexp_constraint (_, ct) ->
            let (const_type, c) =
              match ct.ptyp_desc with
              | Ptyp_constr (loc, ct) -> (loc.txt, ct)
              | _ -> print_string "2. Give a proper error that a constraint is expected"; assert false
            in
            (Typ.constr (Location.mkloc const_type (Location.symbol_gloc ())) c)
          | _ -> print_string "Function exports must be fully constrained"; assert false
        in
        let arr = process_arguments arrow
        in
        let value = Val.mk
          ~attrs:pvb_attributes
          loc
          arr
        in Sig.mk (Psig_value value)
        )
      | _ -> print_string "Unsupported usage of export"; assert false
    ) value_bindings
    in
    acc tail (current_signatures @ value_descriptions) (current_structures  @ str)
)

let rec extract str : signature_item list * structure_item list = (
  let rec acc str current_signatures current_structures = (
    match str with
      (* -- easy ones -- *)
      | {pstr_desc = Pstr_type (r, t)} :: tail ->
        acc tail (current_signatures @ [Sig.mk (Psig_type (r, t))]) (current_structures @ str)
      | {pstr_desc = Pstr_typext te} :: tail ->
        acc tail (current_signatures @ [Sig.mk (Psig_typext te)]) (current_structures @ str)
      | {pstr_desc = Pstr_exception e} :: tail ->
        acc tail (current_signatures @ [Sig.mk (Psig_exception e)]) (current_structures @ str)
      | {pstr_desc = Pstr_module {pmb_name; pmb_loc; pmb_expr = {pmod_desc = Pmod_constraint (_, {pmty_desc = Pmty_ident loc}) }}} :: tail ->
        (* a simple module `module X: Type = Y` *)
        let loc2 = { txt = loc.txt; loc = pmb_loc } in
        acc tail (current_signatures @ [Sig.module_ (Md.mk pmb_name (Mty.ident loc2))]) (current_structures @ str)
        (*acc tail (current_signatures @ [Sig.modtype (Mtd.mk loc)]) (current_structures @ str)*)
      | {pstr_desc = Pstr_modtype mt} :: tail ->
        (* a module type *)
        acc tail (current_signatures @ [Sig.mk (Psig_modtype mt)]) (current_structures @ str)
      | {pstr_desc = Pstr_class_type e} :: tail ->
        acc tail (current_signatures @ [Sig.mk (Psig_class_type e)]) (current_structures @ str)
      | {pstr_desc = Pstr_attribute a} :: tail ->
        acc tail (current_signatures @ [Sig.mk (Psig_attribute a)]) (current_structures  @ str)
      | {pstr_desc = Pstr_extension (e, a)} :: tail ->
        acc tail (current_signatures @ [Sig.mk (Psig_extension (e, a))]) (current_structures  @ str)

      (* -- hard ones -- *)
      | {pstr_desc = Pstr_value (rec_flag, value_bindings)} :: tail ->
        extract_value value_bindings tail acc current_signatures current_structures str
      | {pstr_desc = Pstr_module {pmb_name; pmb_expr = {pmod_desc = Pmod_structure str; pmod_attributes; pmod_loc}}} :: tail ->
        (* a complex module with a signature *)
        let (s, s2) = process str [] [] in
        let module_expr = Mod.structure s2 ~loc:pmod_loc ~attrs:pmod_attributes in
        let module_ =
          Str.module_
            (Mb.mk pmb_name module_expr)
        in
        let sigModule_ =
          Sig.module_
            (Md.mk pmb_name (Mty.signature s))
        in
        (* let _ = {ex with pmb_expr = a} in *)
        acc tail (current_signatures @ [sigModule_]) (current_structures @ [module_])
      | {pstr_desc = Pstr_module {pmb_expr = {pmod_desc = Pmod_functor _ }}} :: tail ->
        (* a functor! *)
        assert false
      | {pstr_desc = Pstr_module _} :: tail ->
        (* a functor! *)
        print_string "Invalid module export - must be constrained or literal"; assert false
      (* | {pstr_desc = Pstr_recmodule e} :: tail ->
        (* a recursive module *)
        acc tail (current_signatures @ [Sig.mk (Psig_module e)]) *)
      (* | {pstr_desc = Pstr_class c} :: tail ->
        (* a class *)
        let class_signature cd =
          let rec acc2 str current_signatures =
            match str with
            | {pcl_desc = } *)
            (*
            | Pcty_constr of Longident.t loc * core_type list
                   (* c
                      ['a1, ..., 'an] c *)
             | Pcty_signature of class_signature
                   (* object ... end *)
             | Pcty_arrow of arg_label * core_type * class_type
                   (* T -> CT       Simple
                      ~l:T -> CT    Labelled l
                      ?l:T -> CT    Optional l
                    *)
             | Pcty_extension of extension
                   (* [%id] *)

            *)

          (* in acc2 cd []
        in
        let cs = class_signature c in
        acc tail (current_signatures @ [Sig.mk (Psig_class cs)]) *)

      | [] -> (current_signatures, current_structures )
      | _ -> assert false
    )
    in acc str [] [])
and process_extension structure_item =
  match structure_item with
  | {pstr_desc = Pstr_extension (({txt = "export"; loc}, PStr str), _)} -> extract str
  | _ -> ([], [structure_item])
and process structure str_ sig_ =
  match structure with
  | hd :: tl ->
      let (sigl, strl) = process_extension hd in
      process tl (str_ @ strl) (sig_ @ sigl)
  | [] -> (sig_, str_)

let export =
  Reason_toolchain.To_current.copy_mapper
  {
    Ast_mapper.default_mapper with
    structure = (fun mapper structure  ->
      let (sig_, str_) = process structure [] []
      in
        if List.length sig_ > 0 then
          let processed_structure = Str.include_  {
            pincl_mod = Mod.constraint_
              (Mod.structure str_)
              (Mty.signature sig_);
              pincl_loc = (Location.symbol_rloc ());
              pincl_attributes = [];
            }
          in
          Ast_mapper.default_mapper.structure mapper [processed_structure]
        else
          Ast_mapper.default_mapper.structure mapper str_
      );
    }

  let _ = Compiler_libs.Ast_mapper.register "export"
      (fun _argv -> export)
