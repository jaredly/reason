
module type%export X_int = sig val x : int end

module Increment (M : X_int) : X_int = struct
  let x = M.x + 1
end

module%export Three = struct let%export x:int = 3 end
module%export Six: X_int = struct let x:int = 3 end

module%export Four: X_int = Increment(Three)
module%export Five: X_int = Four
