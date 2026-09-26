{
  description = "Soda's NixOS configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      soda-fw = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules     = [
          ./hosts/soda-fw/configuration.nix
        ];
      };
      soda-desk = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules     = [
          ./hosts/soda-desk/configuration.nix
        ];
      };
    };
  };
}
