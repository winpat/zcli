{
  description = "A library for building command-line applications.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        deps = with pkgs; [
          zig
          zls
        ];
    in {
      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = deps;
      };
    };
}
