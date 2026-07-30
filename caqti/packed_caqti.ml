module Db_connection = Db_connection
module Unit_of_work = Unit_of_work
module Update = Update

(* Pack Caqti errors as [Packed_error.S], for layers that carry errors
   as first-class modules. *)

let pack_error (e : [> Caqti_error.t ]) =
  (module struct
    type t = Caqti_error.t

    let e = e
    let pp fmt = Caqti_error.pp fmt e
  end : Packed_error.S
    with type t = Caqti_error.t)

let pack_transaction_error (e : [> Caqti_error.transact ]) =
  (module struct
    type t = Caqti_error.transact

    let e = e
    let pp fmt = Caqti_error.pp fmt e
  end : Packed_error.S
    with type t = Caqti_error.transact)
