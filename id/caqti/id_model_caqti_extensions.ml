module type With_caqti_type = sig
  type t

  val t : t
  val caqti_t : t Caqti_type.t
end
