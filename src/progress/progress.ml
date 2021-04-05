open! Import
open Progress_engine

type 'a reporter = 'a -> unit

module Platform = struct
  module Width = Width
end

module Renderer = struct
  include Renderer
  include Make (Platform)
end

module Segment = struct
  include Segment
  include Platform_dependent (Platform)
end

module Line = struct
  include Line
  include Line.Make (Mtime_clock) (Platform)

  module Expert = struct
    include Expert.Platform_dependent (Platform)
    include Expert
  end
end

type ('a, 'b) t = ('a, 'b) Renderer.t
type display = Renderer.display

let make = Renderer.make
let make_list = Renderer.make_list
let start = Renderer.start
let tick = Renderer.tick
let finalize = Renderer.finalize
let interject_with = Renderer.interject_with
let with_reporters = Renderer.with_reporters
let ( / ) top bottom = Renderer.Segment_list.append top bottom

module Reporters = Renderer.Reporters

type bar_style = [ `ASCII | `UTF8 | `Custom of string list ]

let renderer_config : Line.render_config =
  { interval = Some Duration.millisecond; max_width = Some 120 }

let make x =
  let seg = Line.compile x ~config:renderer_config in
  make seg

let make_list xs =
  let xs = List.map (Line.compile ~config:renderer_config) xs in
  make_list xs

let counter (type elt) ~(total : elt) ?color ?(style = `ASCII) ?message ?pp
    ?width:_ ?sampling_interval:(_ = 1)
    (module Integer : Integer.S with type t = elt) =
  let open Line in
  make
  @@ list
       (Option.fold ~none:[] message ~some:(fun s -> [ const s ])
       @ Option.fold ~none:[] pp ~some:(fun (pp, width) ->
             [ Line.of_pp ~elt:(module Integer) ~width pp ])
       @ [ Line.elapsed ()
         ; (bar ?color ~style ~total (module Integer) : elt Line.t)
           ++ const " "
           ++ percentage_of total (module Integer)
         ])

module Config = struct
  include Config

  let stderr_if_tty =
    if Unix.(isatty stderr) then Default.ppf
    else Format.make_formatter (fun _ _ _ -> ()) (fun () -> ())

  let create ?(ppf = stderr_if_tty) ?hide_cursor ?persistent () : t =
    { ppf = Some ppf; hide_cursor; persistent }
end

module Ansi = Ansi
module Duration = Duration
module Units = Units
