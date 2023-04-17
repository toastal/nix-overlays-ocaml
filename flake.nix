{
  description = "ocaml-packages-overlay";

  nixConfig = {
    extra-substituters = "https://anmonteiro.nix-cache.workers.dev";
    extra-trusted-public-keys = "ocaml.nix-cache.com-1:/xI2h2+56rwFfKyyFVbkJSeGqSIYMC/Je+7XXqGKDIY=";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=9a60b3eef1a0ccb4e3459eba1814bae91d07134e";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      patchChannel = { system, channel }:
        let
          patches = [ ];
        in
        if patches == [ ]
        then channel
        else
          (import channel { inherit system; }).pkgs.applyPatches {
            name = "nixpkgs-patched";
            src = channel;
            patches = patches;
          };
      overlay = import ./overlay nixpkgs;
    in
    nixpkgs.lib.recursiveUpdate
      {
        lib = nixpkgs.lib;

        hydraJobs = builtins.listToAttrs (map
          (system: {
            name = system;
            value = (import ./ci/hydra.nix {
              inherit system;
              pkgs = self.legacyPackages.${system};
            });
          })
          [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ]);

        makePkgs = { system, extraOverlays ? [ ], ... }@attrs:
          let
            pkgs = import nixpkgs ({
              inherit system;
              overlays = [ overlay ];
              config.allowUnfree = true;
            } // attrs);
          in
            /*
            You might read
            https://nixos.org/manual/nixpkgs/stable/#sec-overlays-argument and
            want to change this but because of how we're doing overlays we will
            be overriding any extraOverlays if we don't use `appendOverlays`
            */
          pkgs.appendOverlays extraOverlays;

        overlays.default = final: prev: overlay final prev;
      }
      (flake-utils.lib.eachDefaultSystem (system:
        {
          legacyPackages = self.makePkgs { inherit system; };

          overlays = (final: prev:
            let
              channel = patchChannel {
                inherit system;
                channel = nixpkgs;
              };
            in

            import channel {
              inherit system;
              overlays = [ (import ./overlay channel) ];
              config.allowUnfree = true;
            }
          );
        }));
}
