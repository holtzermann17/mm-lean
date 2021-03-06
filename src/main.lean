/-
Copyright (c) 2017 Minchao Wu. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Minchao Wu
-/

import system.io provers.ljt provers.tableaux mathematica lambda extract_consts
-- _target.deps.relevance_filter.k_nn
open tactic expr io mathematica name task mmexpr

@[simp]
lemma set_distrib_right {α} (s t u : set α) : s ∩ (t ∪ u) = (s ∩ t) ∪ (s ∩ u) :=
set.ext $ λ v, 
⟨λ h, begin cases h.2, left, constructor, apply h.1, assumption, right, constructor, apply h.1, assumption end,
 λ h, begin cases h, constructor, apply h.1, left, apply h.2, constructor, apply h.1, right, apply h.2 end⟩

namespace tactic
meta def solve_fully_aux {α : Type} (ex : expr) (tac : tactic α) : tactic (α × expr) :=
do (a, e) ← solve_aux ex tac,
   e' ← instantiate_mvars e,
   guard $ bnot e'.has_meta_var,
   return (a, e')
end tactic

meta def peek_type (e : expr) : tactic string :=
infer_type e >>= λ t, return $ to_string t

meta def write_string (s : string) : tactic unit :=
unsafe_run_io $ write_file "temp.txt" s io.mode.write

meta def mm_check : expr → tactic unit := 
λ e, peek_type e >>= λ s, write_string s

meta def mm_write (s : name) (b := ff) : tactic unit :=
get_decl s >>= λ e, write_string $ cond b e.value.to_string (form_of_expr e.value)

meta def mm_prover : tactic unit := intuit <|> glivenko

/--
 Solve goal using mm_prover and unfold listed constants in the resulting proof
-/
meta def mm_prover_unfold (to_unfold : list name) : tactic unit :=
do t ← target,
   (_, pf) ← tactic.solve_fully_aux t mm_prover,
   dunfold to_unfold pf {fail_if_unchanged := ff} >>= apply >> skip

meta def preprocess (mm_fml : string) : tactic expr :=
do m ← parse_mmexpr_tac $ string.to_char_buffer mm_fml,
   pexpr_of_mmexpr trans_env.empty m >>= to_expr

meta def translate (mm_fml : string) : tactic string :=
do f ← preprocess mm_fml >>= pp,
   return f.to_string

meta def prove_using_tac (tac : tactic unit) (mm_fml  : string) (b := ff) : tactic string :=
(do e ← preprocess mm_fml,
    (_, pf) ← tactic.solve_fully_aux e tac, 
    return $ if b then form_of_expr pf else pf.to_string) 
<|> return "failed"

meta def prove_mm_prop_fml (mm_fml : string) (b := ff) : tactic string :=
prove_using_tac (intros >> mm_prover_unfold ljt_lemmas) mm_fml b

meta def mk_smt_simp_lemmas : tactic simp_lemmas :=
local_context >>= simp_lemmas.append simp_lemmas.mk

meta def mm_smt (mm_fml : string) (b := ff) : tactic string :=
prove_using_tac (intros >> using_smt (do s ← mk_smt_simp_lemmas, simp_target s [] {fail_if_unchanged := ff})) mm_fml b

meta def elaborate (mm_fml : string) (b := ff) : tactic string :=
(do e ← preprocess mm_fml,
   return $ if b then form_of_expr e else e.to_string)
<|> return "failed to elaborate"

meta def type_check (mm_fml : string) (b := ff) : tactic string :=
(do e ← preprocess mm_fml >>= infer_type,
   return $ if b then form_of_expr e else e.to_string)
<|> return "failed to typecheck"

---------------------------------------------------------------------------------

meta def normalize_set (mm_fml : string) (b := ff) : tactic string :=
do e ← preprocess mm_fml,
   s ← simp_lemmas.mk_default,
   pt ← simplify s [] e {fail_if_unchanged := ff} `eq failed >>= pp,
   return $ pt.to_string

meta def normalize_set_lemmas (mm_fml : string) (b := ff) : tactic string :=
do e ← preprocess mm_fml,
   s ← simp_lemmas.mk_default,
   pt ← simplify s [] e {fail_if_unchanged := ff} `eq failed,
   print_lemmas_used pt.2
