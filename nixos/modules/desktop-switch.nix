# Swapping between the two desktops (orbit, the new one, and bar, the original) without a rebuild.
#   rice-switch orbit | bar | status     on the PATH (the script itself lives in the repo)
#   launcher entries                     "Switch to the new desktop" / "Switch to the old desktop", so the swap is
#                                        possible from either shell, which have different launchers
# The repo path is fixed because the script has to edit the live niri config and find the shells in the repo.
{ pkgs, ... }:

let
  repo = "/home/soda/DotFiles";

  riceSwitch = pkgs.writeShellScriptBin "rice-switch" ''
    exec ${repo}/bin/rice-switch "$@"
  '';

  entry = target: label: pkgs.makeDesktopItem {
    name = "switch-to-${target}-desktop";
    desktopName = "Switch to the ${label} desktop";
    comment = "Restarts the shell and hands over to the ${label} setup";
    exec = "${repo}/bin/rice-switch ${if label == "new" then "orbit" else "bar"}";
    icon = "preferences-desktop";
    categories = [ "Settings" ];
  };
in
{
  environment.systemPackages = [ riceSwitch (entry "orbit" "new") (entry "bar" "old") ];
}
