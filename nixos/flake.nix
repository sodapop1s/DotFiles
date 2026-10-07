{
  description = "Soda's NixOS configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    claude-desktop-extra.url = "github:patrickjaja/claude-desktop-extra";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      soda-fw = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; system = "x86_64-linux"; };
        modules     = [
          ./hosts/soda-fw/configuration.nix
        ];
      };
      soda-desk = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; system = "x86_64-linux"; };
        modules     = [
          ./hosts/soda-desk/configuration.nix
        ];
      };
    };
  };
}
