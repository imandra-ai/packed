(* Smoke tests: a hand-packed error (the no-factory idiom packed-error
   supports today) and a full entity-id built over a fake string
   backend, mirroring how imandra-web instantiates the factory. *)

(* ── packed-error ─────────────────────────────────────────────── *)

module My_error = struct
  type t = Boom of string

  let pp_t fmt = function Boom s -> Format.fprintf fmt "Boom: %s" s

  module type S = sig
    include Packed_error.S with type t = t
    include Packed_error.With_value.S with type t = t
  end

  let pack (e : t) : (module S) =
    (module struct
      type nonrec t = t

      let e = e
      let pp fmt = pp_t fmt e
    end)
end

let () =
  let (module E) = My_error.pack (Boom "kapow") in
  assert (Format.asprintf "%t" E.pp = "Boom: kapow");
  match E.e with My_error.Boom s -> assert (s = "kapow")

(* ── packed-id ────────────────────────────────────────────────── *)

module Widget_id = struct
  module rec R : sig
    module type S = sig
      include Id_model.Base.S
      include Id_model.With_to_string.S
      include Id_model.With_pp.S
      include Id_model.With_equal with module type SELF := R.S
    end
  end =
    R

  module type S = R.S
end

module Widget_id_factory = struct
  module type SELF = Widget_id.S

  module Pack = struct
    let pack (type a) (x : a) (to_string_ : a -> string) =
      (module struct
        open Id_factory_factory.With_pack
        include (val base x)
        include (val to_string x to_string_)

        include
          (val pp x (fun fmt x -> Format.pp_print_string fmt (to_string_ x)))

        let equal (module X : SELF) =
          String.equal (to_string ()) (X.to_string ())
      end : SELF)
  end

  module Capability_implementations =
  Id_factory_factory.Capabilities.Make_implementations (struct
    module type SELF = SELF

    let pack = Pack.pack
  end)

  module Backend = struct
    type t = string

    let counter = ref 0

    let v () =
      incr counter;
      Printf.sprintf "widget-%d" !counter

    let to_string x = x
    let of_string = function "" -> None | s -> Some s
    let nil = "widget-nil"
  end

  open Capability_implementations
  include Make_with_of_string (Backend)
  include Make_with_new (Backend)
  include Make_with_nil (Backend)
end

let () =
  let (module I1 : Widget_id.S) = Widget_id_factory.new_ () in
  let (module I2 : Widget_id.S) = Widget_id_factory.new_ () in
  assert (I1.equal (module I1));
  assert (not (I1.equal (module I2)));
  assert (Format.asprintf "%t" I1.pp = I1.to_string ());
  (match Widget_id_factory.of_string (I1.to_string ()) with
  | Some (module I1' : Widget_id.S) -> assert (I1'.equal (module I1))
  | None -> assert false);
  (match Widget_id_factory.of_string "" with
  | None -> ()
  | Some _ -> assert false);
  let (module N : Widget_id.S) = Widget_id_factory.nil in
  assert (N.to_string () = "widget-nil")

(* ── packed-caqti (link-level smoke; a live pool/tx needs postgres) ── *)

module _ = Packed_caqti.Unit_of_work

let _ = Packed_caqti.Db_connection.pack
let _ = Packed_caqti.Update.caqti_t
let _ = Packed_caqti.pack_error
let () = print_endline "packed: all tests passed"
