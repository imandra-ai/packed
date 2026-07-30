module Tx_connection = struct
  type token = Token

  module type S = sig
    include Db_connection.S

    val tx_token : token
  end
end

module Make (Db : Db_connection.S) = struct
  let do_in_tx (type repos) ~(build : (module Tx_connection.S) -> repos)
      ~map_transaction_error f =
    Db.with_tx_map_error ~map_transaction_error (fun conn ->
        let module Conn =
          (val Db_connection.(pack (Tx conn)) : Db_connection.S)
        in
        let tx_conn : (module Tx_connection.S) =
          (module struct
            include Conn

            let tx_token = Tx_connection.Token
          end)
        in
        f (build tx_conn))
end
