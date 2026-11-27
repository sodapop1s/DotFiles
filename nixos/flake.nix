{
  description = "Soda's NixOS configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # For the odd package where 25.11 lags too far behind (currently just Lutris)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    claude-desktop-extra.url = "github:patrickjaja/claude-desktop-extra";
    # Spotify desktop app, themed from the design tokens (modules/spotify.nix)
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
    # Declarative Flatpak apps (services.flatpak.packages in common.nix)
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.8.0";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      soda-fw = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; system = "x86_64-linux"; };
        modules     = [
          ./hosts/soda-fw/configuration.nix
          inputs.nix-flatpak.nixosModules.nix-flatpak
        ];
      };
      soda-desk = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; system = "x86_64-linux"; };
        modules     = [
          ./hosts/soda-desk/configuration.nix
          inputs.nix-flatpak.nixosModules.nix-flatpak
        ];
      };
    };
  };
}
