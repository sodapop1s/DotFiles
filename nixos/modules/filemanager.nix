# Yazi, the terminal file manager, as an app that opens in Ghostty. Thunar stays the default for folders.
# The stock yazi.desktop has Terminal=true, which GTK apps cannot launch without a configured terminal,
# so this adds an entry that names the terminal explicitly (it also shows up under "Open with").
{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.makeDesktopItem {
      name = "yazi-ghostty";
      desktopName = "Yazi in Ghostty";
      genericName = "File Manager";
      comment = "Terminal file manager";
      exec = "ghostty -e yazi %u";
      icon = "system-file-manager";
      categories = [ "System" "FileManager" "FileTools" ];
      mimeTypes = [ "inode/directory" ];
    })
  ];
}
