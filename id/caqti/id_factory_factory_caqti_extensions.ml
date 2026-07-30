(* Store first-class-module ids in text columns: [caqti_t] encodes via
   the id's own [to_string] and decodes through the factory's validating
   [of_string], so a corrupt row fails decoding instead of minting an
   invalid id. *)

module Make_sigs (X : sig
  module type SELF
end) =
struct
  module type With_caqti_t = sig
    val caqti_t :
      to_string:((module X.SELF) -> string) -> (module X.SELF) Caqti_type.t
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

  module Base_implementations =
    Id_factory_factory.Capabilities.Make_implementations (X)

  module Make_with_caqti_id (Uuidm : Base_implementations.A) :
    Sigs.With_caqti_t = struct
    module With_of_string = Base_implementations.Make_with_of_string (Uuidm)

    let of_string = With_of_string.of_string

    let caqti_t ~to_string =
      let encode id = Ok (to_string id) in
      let decode str = of_string str |> Option.to_result ~none:"of_string" in
      Caqti_type.(custom ~encode ~decode string)
  end
end
