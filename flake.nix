{
  description = "Soda's NixOS configs";

inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  dms = {
    url = "github:AvengeMedia/DankMaterialShell/stable";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  dgop = {
    url = "github:AvengeMedia/dgop";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
  outputs = { self, nixpkgs, dms, dgop, ... }: {
    nixosConfigurations = {

      framework16 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          dms.nixosModules.dank-material-shell
	  ({ pkgs, ... }: {
          programs.dank-material-shell = {
            enableSystemMonitoring = true;
            dgop.package = dgop.packages.${pkgs.system}.default;
          };
        })
        ];
      };

      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/desktop/configuration.nix
          dms.nixosModules.dank-material-shell
        ];
      };

    };
  };
}
