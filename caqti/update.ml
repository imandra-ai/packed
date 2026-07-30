(* Optional-update fields for UPDATE statements built around COALESCE:
   [`Ignore] encodes to NULL (COALESCE keeps the current value),
   [`Update v] encodes to [v]. [nullable_caqti_t] is the variant for
   columns that are themselves nullable, where NULL is a legitimate
   target value -- it encodes as (is_set, value) so the SQL can
   distinguish "leave alone" from "set to NULL". *)

type 'a t = [ `Ignore | `Update of 'a ]

let caqti_t (inner : 'a Caqti_type.t) : 'a t Caqti_type.t =
  let encode = function `Ignore -> Ok None | `Update x -> Ok (Some x) in
  let decode = function None -> Ok `Ignore | Some x -> Ok (`Update x) in
  Caqti_type.custom ~encode ~decode (Caqti_type.option inner)

let nullable_caqti_t (inner : 'a Caqti_type.t) : 'a option t Caqti_type.t =
  let open Caqti_type in
  let encode = function
    | `Ignore -> Ok (false, None)
    | `Update v -> Ok (true, v)
  in
  let decode (is_set, v) = if is_set then Ok (`Update v) else Ok `Ignore in
  Caqti_type.custom ~encode ~decode (t2 bool (option inner))
