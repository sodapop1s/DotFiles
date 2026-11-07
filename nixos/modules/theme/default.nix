# Generates per-app theme files from tokens.nix into one store path, installed at
#   /run/current-system/sw/share/rice-theme/
# Nothing here touches ~/.config; each app opts in by including its file from there.
{ pkgs, lib, ... }:

let
  t = import ./tokens.nix;
  c = t.color;
  sp = t.motion.spring;

  noHash = lib.removePrefix "#";
  # "#RRGGBB" -> "r g b" as 0..1 floats (sioyek)
  floats = hex:
    let h = noHash hex;
        ch = i: toString (lib.fromHexString (builtins.substring i 2 h) / 255.0);
    in "${ch 0} ${ch 2} ${ch 4}";

  file = name: text: { name = "share/rice-theme/${name}"; path = pkgs.writeText (baseNameOf name) text; };

  springKdl = "spring damping-ratio=${toString sp.dampingRatio} stiffness=${toString sp.stiffness} epsilon=${toString sp.epsilon}";

  # ANSI palette stays inside the spec colors: no extra hues.
  ansi = [ c.bg c.crit c.good c.warn c.accent c.muted c.accent c.text
           c.hairline c.crit c.good c.warn c.accent c.muted c.accent c.text ];

  files = [
    # quickshell reads this at runtime
    (file "tokens.json" (builtins.toJSON t))

    (file "niri.kdl" ''
      // Generated from tokens.nix. include "/run/current-system/sw/share/rice-theme/niri.kdl"
      layout {
          border {
              active-color "${c.accent}"
              inactive-color "${c.hairline}"
              urgent-color "${c.crit}"
          }
          focus-ring {
              active-color "${c.accent}"
              inactive-color "${c.hairline}"
              urgent-color "${c.crit}"
          }
      }
      animations {
          workspace-switch { ${springKdl}; }
          window-open { ${springKdl}; }
          window-close { ${springKdl}; }
          horizontal-view-movement { ${springKdl}; }
          window-movement { ${springKdl}; }
          window-resize { ${springKdl}; }
          overview-open-close { ${springKdl}; }
      }
    '')

    (file "ghostty/rice" (''
      background = ${c.bg}
      foreground = ${c.text}
      cursor-color = ${c.accent}
      cursor-text = ${c.bg}
      selection-background = ${c.raised}
      selection-foreground = ${c.text}
    '' + lib.concatImapStringsSep "\n" (i: col: "palette = ${toString (i - 1)}=${col}") ansi + "\n"))

    (file "ghostty/fonts" ''
      font-family = ${t.font.mono}
      font-size = ${toString t.font.monoSize}
    '')

    (file "gtk/gtk.css" ''
      @define-color accent_bg_color ${c.accent};
      @define-color accent_fg_color ${c.bg};
      @define-color accent_color ${c.accent};
      @define-color window_bg_color ${c.bg};
      @define-color window_fg_color ${c.text};
      @define-color view_bg_color ${c.panel};
      @define-color view_fg_color ${c.text};
      @define-color headerbar_bg_color ${c.panel};
      @define-color headerbar_fg_color ${c.text};
      @define-color headerbar_border_color ${c.hairline};
      @define-color card_bg_color ${c.raised};
      @define-color card_fg_color ${c.text};
      @define-color popover_bg_color ${c.raised};
      @define-color popover_fg_color ${c.text};
      @define-color sidebar_bg_color ${c.panel};
      @define-color sidebar_fg_color ${c.text};
      @define-color success_color ${c.good};
      @define-color warning_color ${c.warn};
      @define-color error_color ${c.crit};
      @define-color destructive_color ${c.crit};
    '')

    # Neovim: add to runtimepath, then `colorscheme rice`
    (file "nvim/colors/rice.lua" ''
      vim.cmd("highlight clear")
      vim.g.colors_name = "rice"
      vim.o.termguicolors = true
      vim.o.background = "dark"
      local hl = function(g, o) vim.api.nvim_set_hl(0, g, o) end
      hl("Normal",       { fg = "${c.text}",  bg = "${c.bg}" })
      hl("NormalFloat",  { fg = "${c.text}",  bg = "${c.panel}" })
      hl("FloatBorder",  { fg = "${c.hairline}", bg = "${c.panel}" })
      hl("CursorLine",   { bg = "${c.panel}" })
      hl("Visual",       { bg = "${c.raised}" })
      hl("LineNr",       { fg = "${c.muted}" })
      hl("CursorLineNr", { fg = "${c.text}" })
      hl("Comment",      { fg = "${c.muted}", italic = true })
      hl("Pmenu",        { fg = "${c.text}",  bg = "${c.panel}" })
      hl("PmenuSel",     { fg = "${c.text}",  bg = "${c.raised}" })
      hl("Search",       { fg = "${c.bg}",    bg = "${c.accent}" })
      hl("IncSearch",    { fg = "${c.bg}",    bg = "${c.accent}" })
      hl("StatusLine",   { fg = "${c.text}",  bg = "${c.panel}" })
      hl("WinSeparator", { fg = "${c.hairline}" })
      hl("DiagnosticError", { fg = "${c.crit}" })
      hl("DiagnosticWarn",  { fg = "${c.warn}" })
      hl("DiagnosticOk",    { fg = "${c.good}" })
      hl("DiagnosticInfo",  { fg = "${c.accent}" })
      hl("DiffAdd",      { fg = "${c.good}" })
      hl("DiffDelete",   { fg = "${c.crit}" })
      hl("DiffChange",   { fg = "${c.warn}" })
    '')

    (file "yazi/theme.toml" ''
      [mgr]
      cwd = { fg = "${c.accent}" }
      hovered = { fg = "${c.text}", bg = "${c.raised}" }
      preview_hovered = { bg = "${c.raised}" }
      tab_active = { fg = "${c.bg}", bg = "${c.accent}" }
      tab_inactive = { fg = "${c.muted}", bg = "${c.panel}" }
      border_style = { fg = "${c.hairline}" }

      [status]
      overall = { bg = "${c.panel}" }
      progress_normal = { fg = "${c.accent}", bg = "${c.hairline}" }
      progress_error = { fg = "${c.crit}", bg = "${c.hairline}" }

      [input]
      border = { fg = "${c.accent}" }
      selected = { bg = "${c.raised}" }

      [tasks]
      border = { fg = "${c.hairline}" }
      hovered = { fg = "${c.text}", bg = "${c.raised}" }
    '')

    (file "swayimg/theme.conf" ''
      [font]
      name = ${t.font.ui}, ${t.font.uiFallback}

      [viewer]
      window = ${c.bg}
      background = ${c.bg}

      [gallery]
      window = ${c.bg}
      background = ${c.panel}
      border = ${c.accent}
      select = ${c.raised}
    '')

    (file "mpv/mpv.conf" ''
      hwdec=auto-safe
      osd-font="${t.font.ui}"
      osd-color="${c.text}"
      osd-border-color="${c.bg}"
      osd-back-color="${c.panel}"
    '')
    (file "mpv/script-opts/uosc.conf" ''
      color=foreground=${noHash c.text},foreground_text=${noHash c.bg},background=${noHash c.panel},background_text=${noHash c.text},curtain=${noHash c.bg},success=${noHash c.good},error=${noHash c.crit}
      font_bold=no
    '')

    (file "sioyek/theme.config" ''
      background_color ${floats c.bg}
      dark_mode_background_color ${floats c.bg}
      dark_mode_contrast 0.9
      text_highlight_color ${floats c.accent}
      search_highlight_color ${floats c.warn}
      link_highlight_color ${floats c.accent}
      visual_mark_color ${floats c.accent}
      ui_text_color ${floats c.text}
      ui_background_color ${floats c.panel}
      ui_selected_text_color ${floats c.text}
      ui_selected_background_color ${floats c.raised}
      status_bar_color ${floats c.panel}
      status_bar_text_color ${floats c.text}
    '')

    (file "spicetify/color.ini" ''
      [rice]
      text = ${noHash c.text}
      subtext = ${noHash c.muted}
      main = ${noHash c.bg}
      main-elevated = ${noHash c.panel}
      highlight = ${noHash c.raised}
      highlight-elevated = ${noHash c.raised}
      sidebar = ${noHash c.panel}
      player = ${noHash c.panel}
      card = ${noHash c.raised}
      shadow = ${noHash c.bg}
      selected-row = ${noHash c.text}
      button = ${noHash c.accent}
      button-active = ${noHash c.accent}
      button-disabled = ${noHash c.hairline}
      tab-active = ${noHash c.raised}
      notification = ${noHash c.raised}
      notification-error = ${noHash c.crit}
      equalizer = ${noHash c.accent}
      misc = ${noHash c.hairline}
    '')

    (file "obsidian/rice.css" ''
      body.theme-dark {
        --background-primary: ${c.bg};
        --background-primary-alt: ${c.panel};
        --background-secondary: ${c.panel};
        --background-secondary-alt: ${c.bg};
        --background-modifier-border: ${c.hairline};
        --background-modifier-hover: ${c.raised};
        --text-normal: ${c.text};
        --text-muted: ${c.muted};
        --text-faint: ${c.muted};
        --interactive-accent: ${c.accent};
        --text-selection: ${c.raised};
        --text-error: ${c.crit};
        --text-success: ${c.good};
        --text-warning: ${c.warn};
        --font-interface-theme: ${t.font.ui}, ${t.font.uiFallback}, sans-serif;
        --font-monospace-theme: ${t.font.mono}, monospace;
      }
    '')
  ];
in
{
  environment.systemPackages = [ (pkgs.linkFarm "rice-theme" files) ];
}
