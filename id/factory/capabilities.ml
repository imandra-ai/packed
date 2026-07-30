module Make_sigs (X : sig
  module type SELF
end) =
(* these are factory capabilities *)
struct
  module type With_of_string = sig
    val of_string : string -> (module X.SELF) option
  end

  module type With_new = sig
    val new_ : unit -> (module X.SELF)
  end

  module type With_of_uuidm = sig
    type t

    val of_uuidm : t -> (module X.SELF)
  end

  module type With_nil = sig
    val nil : (module X.SELF)
  end
end

module Make_implementations (X : sig
  module type SELF

  val pack : 'a -> ('a -> string) -> (module SELF)
end) =
struct
  module Sigs = Make_sigs (struct
    module type SELF = X.SELF
  end)

  open Sigs

  module type A = sig
    type t

    val to_string : t -> string
    val of_string : string -> t option
  end

  module Make_with_of_string (Uuidm : A) : With_of_string = struct
    module Make_validate_string (Uuidm : A) = struct
      let f (x : string) = x |> Uuidm.of_string |> Option.map Uuidm.to_string
    end

    module Validate_string = Make_validate_string (Uuidm)

    let of_string (x : string) =
      match x |> Validate_string.f with
      | Some x -> Some (X.pack x Fun.id)
      | None -> None
  end

  module type B = sig
    type t

    val v : unit -> t
    val to_string : t -> string
  end

  module Make_with_new (Uuidm : B) : With_new = struct
    let new_ () = X.pack (Uuidm.v ()) Uuidm.to_string
  end

  module type C = sig
    type t

    val to_string : t -> string
  end

  module Make_with_of_uuidm (Uuidm : C) : With_of_uuidm with type t = Uuidm.t =
  struct
    type t = Uuidm.t

    let of_uuidm (u : Uuidm.t) = X.pack u Uuidm.to_string
  end

  module type D = sig
    type t

    val nil : t
    val to_string : t -> string
  end

  module Make_with_nil (Uuidm : D) : With_nil = struct
    let nil = X.pack Uuidm.nil Uuidm.to_string
  end
end
