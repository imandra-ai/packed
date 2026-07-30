(* A unit of work over a [Db_connection]: [Make(Db).do_in_tx] opens a
   single transaction, hands [build] a {!Tx_connection.S} bound to it,
   and runs [f] against whatever repo bundle [build] returns -- so a
   read-then-write spanning several repos commits atomically.

   Product-agnostic: the caller supplies [build] (which repos to
   construct) and [map_transaction_error] (how a begin/commit/rollback
   failure maps into its own error type), so neither the repo bundle nor
   the error type is baked in.

   Nesting: if [Db] already holds an open transaction it is reused (no
   nested BEGIN); otherwise a connection is pulled from the pool and
   wrapped in a fresh BEGIN/COMMIT. See
   [Db_connection.S.with_tx_map_error]. *)

module Tx_connection : sig
  (* An unforgeable witness that a connection is bound to an open
     transaction. [token] is abstract with no constructor exposed, so
     the only way to obtain a [(module S)] is through
     [Make(_).do_in_tx], which mints one per transaction. Repo methods
     that hold a transaction-lifetime lock, or are one step of a
     multi-step write, take [S] instead of [Db_connection.S]; a pool
     connection satisfies only the latter, so calling such a method
     off-transaction is a compile error. [S] still includes
     [Db_connection.S], so free (read / single-statement) repos build on
     a tx connection unchanged. *)
  type token

  module type S = sig
    include Db_connection.S

    val tx_token : token
  end
end

module Make (_ : Db_connection.S) : sig
  val do_in_tx :
    build:((module Tx_connection.S) -> 'repos) ->
    map_transaction_error:(Caqti_error.t -> 'e) ->
    ('repos -> ('a, 'e) result Lwt.t) ->
    ('a, 'e) result Lwt.t
end
