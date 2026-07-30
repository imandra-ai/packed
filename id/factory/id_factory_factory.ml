module With_pack = struct
  (*
     each of the functions in this module corresponds to an ID capability.
     the `With_pack` factory capability must implement ID capabilities.
     and it's sort of distinct from the other factory capabilities.
  *)
  let base (type a) (x : a) =
    (module struct
      type t = a

      let x = x
    end : Id_model.Base.S
      with type t = a)

  let to_string (type a) (x : a) (to_string : a -> string) =
    (module struct
      let to_string () = to_string x
    end : Id_model.With_to_string.S)

  let pp (type a) (x : a) (pp : Format.formatter -> a -> unit) =
    (module struct
      let pp fmt = Format.fprintf fmt "%a" pp x
    end : Id_model.With_pp.S)
end

(* export *)
module Capabilities = Capabilities
