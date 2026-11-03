# libshumate

Ruby bindings for libshumate, the GTK4 map widget.

```ruby
require "libshumate"

registry = Shumate::MapSourceRegistry.new
registry.populate_defaults

source = registry.get_by_id("osm-mapnik")
source.name                       # => "OpenStreetMap Mapnik"

viewport = Shumate::Viewport.new
viewport.reference_map_source = source
viewport.zoom_level = 12.0

Shumate::Coordinate.new(51.5074, -0.1278)
```

Most of libshumate is `GtkWidget` subclasses — `Shumate::Map`,
`Shumate::SimpleMap`, `Shumate::Marker` — and those need what any GTK widget
needs: a display and a main loop. The map sources, the viewport and the
coordinates above are plain `GObject`s and need neither, which is also why they
are what the suite exercises.

## How this works, and what it costs to install

The library ships a GObject Introspection typelib — `Shumate-1.0.typelib` — describing
every class, method, property and signal it has. `Shumate::Loader`, about twenty
lines, hands that to ruby-gnome's `GObjectIntrospection::Loader`, which defines
the Ruby classes from it at `require` time.

So this gem is pure Ruby: no extension of its own, no Cargo workspace, no
per-platform binary. You get the whole library rather than the subset somebody
got round to wrapping by hand, and it does not drift when the library gains API.

Be precise about install, though: `gem install libshumate` still compiles C, because
`gobject-introspection` and `glib2` are themselves native extensions built
against glib, so a compiler and glib's development headers are needed. What
this gem adds on top is nothing — those two are what every ruby-gnome
application already has, since `gtk4` depends on them.

## Using it with the gtk4 gem

Put `require "gtk4"` before `require "libshumate"` in an application.

The loader defines whatever the typelib describes, and `Shumate-1.0.typelib`
declares `Gtk-4.0`, `Gsk-4.0` and `Gdk-4.0` as dependencies. So if nothing has
loaded GTK yet, this gem's loader resolves those typelibs itself and
`Shumate::Map.ancestors` comes out as `[Shumate::Map, GtkWidget,
GtkConstraintTarget, ...]` — classes defined straight off the typelib, not the
`Gtk::Widget` the `gtk4` gem defines with its hand-written overrides on top. A
`Shumate::Map` from that load cannot be packed into a `Gtk::Box`.

Requiring `gtk4` first makes the real `Gtk` namespace the one already in the
registry, and Shumate's widgets land under it. This gem does not depend on the
`gtk4` gem, because the namespace loads and is useful without it — the sources,
viewport and coordinates above work on `gobject-introspection` alone — and
depending on `gtk4` would pull all of GTK onto anyone who only wanted those.
The ordering is the cost of that choice.

## The one thing you must install

The typelib is a C-library artefact, so it belongs to your distribution and
this gem cannot install it:

| | |
|---|---|
| Debian / Ubuntu | `gir1.2-shumate-1.0` |
| Fedora | `libshumate` |
| Arch | `libshumate` |
| nix | `pkgs.libshumate` |

If it is not in the default search path, point `GI_TYPELIB_PATH` at the
directory holding `Shumate-1.0.typelib`. The dev shell in `flake.nix` does this.

**One trap worth knowing.** The typelib must come from the same glib build as
the `gobject-introspection` gem. Mixing two registers GIO twice in one process
and fails with `cannot register existing type 'GTlsCertificate'`. Under nix,
take both from one nixpkgs — and note that glib's typelibs live in its `out`
output, not the default one.

## Using it from a flake

The gem needs `Shumate-1.0.typelib` and everything that typelib declares, resolved
transitively by the loader at `require` time. A missing one surfaces as
`Typelib file for namespace 'X' not found`, one at a time, so the whole chain
is listed here rather than discovered by repeated failure:

- `pkgs.libshumate` — its typelib, which is where `Shumate-1.0.typelib` lives
- `pkgs.gtk4` — Gtk-4.0, and through it Gdk, Gsk and Graphene
- `pkgs.graphene` — Graphene-1.0, the viewport maths
- `pkgs.pango` — Pango-1.0 and PangoCairo-1.0
- `pkgs.cairo` — cairo-1.0
- `pkgs.gdk-pixbuf` — GdkPixbuf-2.0
- `pkgs.harfbuzz` — HarfBuzz-0.0
- `pkgs.glib` — GLib-2.0, GObject-2.0 and Gio-2.0, which nearly every GNOME typelib declares

Note the `.out`: a package's default output is often `bin`, which carries no
typelibs. `makeSearchPath` takes the first output, so it has to be asked for
`out` explicitly — this is the single most common way to get a search path that
looks right and finds nothing.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
        (map (drv: drv.out or drv) [ pkgs.libshumate pkgs.gtk4 pkgs.graphene pkgs.pango pkgs.cairo pkgs.gdk-pixbuf pkgs.harfbuzz pkgs.glib ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.ruby_3_4 pkgs.bundler ] ++ [ pkgs.libshumate pkgs.gtk4 pkgs.graphene pkgs.pango pkgs.cairo pkgs.gdk-pixbuf pkgs.harfbuzz pkgs.glib ];

        shellHook = ''
          export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
        '';
      };
    };
}
```

Everything must come from **one** nixpkgs. A typelib built against a different
glib than the `gobject-introspection` gem registers GIO twice in the process
and fails with `cannot register existing type 'GTlsCertificate'`.

If you are packaging an application rather than entering a shell, the same
`typelibPath` goes on the wrapper:

```nix
makeWrapper ${ruby}/bin/ruby $out/bin/my-app \
  --set GI_TYPELIB_PATH "${typelibPath}"
```

## Development

```sh
nix develop
bin/test
```

## Releasing

```sh
gem kit release
```

That is the whole thing. It gates on the changelog having an entry for this
version, on no deprecation deadline coming due, and on a clean working tree;
then builds, pushes and tags.

There is nothing to wait for in CI. This gem is pure Ruby, so `gem build`
produces one `libshumate-X.Y.Z.gem` that is the same artefact wherever it is built —
no extension, no per-platform gems, nothing for a workflow to hand back.


## Licence

Apache-2.0. The library itself keeps its own licence; this gem links nothing
and copies no code from it — it reads a description of it at runtime.
