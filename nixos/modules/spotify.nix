# Spotify desktop app, recoloured from the design tokens with spicetify (spicetify-nix).
# Spotify keeps its own layout; only the colours change. Colour is neutral except for state: the accent
# marks the active/pressed control, red an error. Log in to Spotify as usual the first time.
{ pkgs, lib, inputs, ... }:

let
  c = (import ./theme/tokens.nix).color;
  hex = lib.removePrefix "#";
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.nixosModules.spicetify ];

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.default;
    colorScheme = "custom";
    customColorScheme = {
      text               = hex c.text;
      subtext            = hex c.muted;
      main               = hex c.bg;
      main-elevated      = hex c.panel;
      highlight          = hex c.raised;
      highlight-elevated = hex c.raised;
      sidebar            = hex c.panel;
      player             = hex c.panel;
      card               = hex c.raised;
      shadow             = hex c.bg;
      selected-row       = hex c.text;
      button             = hex c.text;
      button-active      = hex c.accent;
      button-disabled    = hex c.hairline;
      tab-active         = hex c.raised;
      notification       = hex c.raised;
      notification-error = hex c.crit;
      equalizer          = hex c.muted;
      misc               = hex c.hairline;
    };
  };
}
