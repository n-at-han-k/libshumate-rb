{
  description = "libshumate — Ruby bindings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    mine.url = "github:n-at-han-k/flake.nix";
    mine.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, mine, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = mine.lib.${system};

        gemspecFiles = pkgs.runCommand "libshumate-gemspec" { } ''
          mkdir -p $out/lib/libshumate
          cp ${./libshumate.gemspec}         $out/libshumate.gemspec
          cp ${./lib/libshumate/version.rb}  $out/lib/libshumate/version.rb
        '';

        gems = pkgs.bundlerEnv {
          name = "libshumate-gems";
          ruby = pkgs.ruby_3_4;
          gemfile = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset = import ./gemset.nix;
          extraConfigPaths = [ "${gemspecFiles}/." ];
        };

        # The namespaces the loader needs at require time: Shumate itself, and
        # whatever Shumate-1.0.typelib declares as a dependency, which the loader
        # resolves transitively. Nearly every GNOME typelib needs Gio-2.0.
        #
        # Shumate-1.0's dependency chain is the GTK widget stack, resolved
        # transitively by the loader: Graphene for the viewport maths, then
        # Gtk, which pulls PangoCairo, Pango, cairo, GdkPixbuf and HarfBuzz.
        # Each missing one surfaces as "Typelib file for namespace 'X' not
        # found", one at a time, so the whole chain is listed rather than
        # discovered by repeated failure.
        #
        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs -- hence the explicit
        # `.out`. polkit has the same shape, and that trap cost real time twice.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) [ pkgs.libshumate pkgs.gtk4 pkgs.graphene pkgs.pango pkgs.cairo pkgs.gdk-pixbuf pkgs.harfbuzz pkgs.glib ]);
      in
      {
        devShells.default = lib.mkRubyShell {
          buildInputs = with pkgs; [
            gems
            gems.wrappedRuby

            libshumate
            gtk4

            skywalking-eyes
          ];

          shellHook = /* bash */ ''
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"

            export BUNDLE_GEMFILE="$PWD/Gemfile"
            export BUNDLE_FROZEN=false

            export LANG="''${LANG:-C.UTF-8}"
            export LC_ALL="''${LC_ALL:-$LANG}"

            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
          '';
        };
      }
    );
}
