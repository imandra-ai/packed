(* The seam between repository code and Caqti: a repo depends on the
   [S] capability below, not on a pool or a connection, so the same repo
   functor runs against a fresh pool checkout, inside someone else's
   open transaction, or against a test double.

   [t] is either a pool or a connection already bound to an open
   transaction. [with_tx] reuses an ambient [Tx _] (the surrounding
   transaction subsumes this one -- no nested BEGIN); a [Db_pool _]
   pulls a connection and wraps [f] in a fresh BEGIN/COMMIT with
   ROLLBACK on error or exception. *)

type t =
  | Db_pool of
      ((module Caqti_lwt.CONNECTION), Caqti_error.t) Caqti_lwt_unix.Pool.t
  | Tx of (module Caqti_lwt.CONNECTION)

let use f pool = Caqti_lwt_unix.Pool.use f pool

(* Wraps [f] in BEGIN/COMMIT. Three ways out of [f]:
   - [Ok x]     -> COMMIT, result [Ok x]
   - [Error e]  -> ROLLBACK, result [Error e]
   - raise      -> ROLLBACK, then the exception is re-raised unchanged.
   The last arm matters because [Pool.use] hands the connection back to the
   pool whatever happens; without it a raise leaves BEGIN open on a pooled
   connection and the next borrower's statements silently join (and commit)
   that transaction. A failed COMMIT needs no ROLLBACK: Postgres has already
   ended the transaction. A ROLLBACK failure on the raise path is dropped in
   favour of the original exception; Caqti resets a connection whose call
   failed, so it does not return to the pool mid-transaction either way. *)
let with_db_transaction_map_error ~map_transaction_error
    (f : (module Caqti_lwt.CONNECTION) -> ('a, 'e) result Lwt.t)
    (db_pool :
      ((module Caqti_lwt.CONNECTION), Caqti_error.t) Caqti_lwt_unix.Pool.t) :
    ('a, 'e) result Lwt.t =
  db_pool
  |> use (fun db ->
         let module Db = (val db : Caqti_lwt.CONNECTION) in
         let open Lwt.Syntax in
         let* start_result = Db.start () in
         match start_result with
         | Error transaction_error -> Lwt.return (Error transaction_error)
         | Ok () -> (
             let* outcome =
               Lwt.catch
                 (fun () ->
                   let+ result = f db in
                   `Returned result)
                 (fun exn -> Lwt.return (`Raised exn))
             in
             match outcome with
             | `Returned (Ok x) -> (
                 let* commit_result = Db.commit () in
                 match commit_result with
                 | Ok () -> Lwt.return (Ok (Ok x))
                 | Error transaction_error ->
                     Lwt.return (Error transaction_error))
             | `Returned (Error e) -> (
                 let* rollback_result = Db.rollback () in
                 match rollback_result with
                 | Ok () -> Lwt.return (Ok (Error e))
                 | Error transaction_error ->
                     Lwt.return (Error transaction_error))
             | `Raised exn ->
                 let* (_ : (unit, Caqti_error.t) result) = Db.rollback () in
                 Lwt.reraise exn))
  |> Lwt.map (function
       | Ok result -> result
       | Error transaction_error ->
           Error (map_transaction_error transaction_error))

let apply ~(db : t)
    (f : (module Caqti_lwt.CONNECTION) -> ('a, Caqti_error.t) result Lwt.t) :
    ('a, Caqti_error.t) result Lwt.t =
  match db with Db_pool db_pool -> db_pool |> use f | Tx tx -> f tx

let with_tx ~(db : t) ~map_transaction_error f =
  match db with
  | Tx tx -> f tx
  | Db_pool db_pool ->
      db_pool |> with_db_transaction_map_error ~map_transaction_error f

module type S = sig
  val apply :
    ((module Caqti_lwt.CONNECTION) -> ('a, Caqti_error.t) result Lwt.t) ->
    ('a, Caqti_error.t) result Lwt.t

  val with_tx :
    ((module Caqti_lwt.CONNECTION) -> ('a, Caqti_error.t) result Lwt.t) ->
    ('a, Caqti_error.t) result Lwt.t

  (* Like [with_tx], but lets the caller choose the result error type by
     mapping the transaction (begin/commit/rollback) error. Use this when
     you want to surface a domain/packed error out of a transaction
     instead of being pinned to [Caqti_error.t]. Nesting is identical to
     [with_tx]: an ambient [Tx _] is reused, a [Db_pool] opens a fresh
     BEGIN/COMMIT. *)
  val with_tx_map_error :
    map_transaction_error:(Caqti_error.t -> 'e) ->
    ((module Caqti_lwt.CONNECTION) -> ('a, 'e) result Lwt.t) ->
    ('a, 'e) result Lwt.t
end

module Make (Db : sig
  val db : t
end) =
struct
  let apply f = apply ~db:Db.db f

  (* Defined before [with_tx] so its body refers to the enclosing free
     [with_tx], not the shadowing local one below. *)
  let with_tx_map_error ~map_transaction_error f =
    with_tx ~db:Db.db ~map_transaction_error f

  let with_tx f =
    with_tx_map_error ~map_transaction_error:(fun e -> (e :> Caqti_error.t)) f
end

let pack (db : t) =
  let module Db = struct
    let db = db
  end in
  (module Make (Db) : S)
