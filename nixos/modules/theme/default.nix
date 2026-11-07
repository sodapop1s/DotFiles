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

    # GTK colours. libadwaita (GTK4) reads the first block, the Adwaita theme in GTK3 (Thunar, ...) the second.
    # Wire it in with: @import url("file:///run/current-system/sw/share/rice-theme/gtk/gtk.css");
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

      @define-color theme_bg_color ${c.bg};
      @define-color theme_fg_color ${c.text};
      @define-color theme_base_color ${c.panel};
      @define-color theme_text_color ${c.text};
      @define-color theme_selected_bg_color ${c.accent};
      @define-color theme_selected_fg_color ${c.bg};
      @define-color theme_unfocused_bg_color ${c.bg};
      @define-color theme_unfocused_fg_color ${c.muted};
      @define-color theme_unfocused_base_color ${c.panel};
      @define-color theme_unfocused_text_color ${c.text};
      @define-color theme_unfocused_selected_bg_color ${c.raised};
      @define-color theme_unfocused_selected_fg_color ${c.text};
      @define-color insensitive_bg_color ${c.panel};
      @define-color insensitive_fg_color ${c.muted};
      @define-color insensitive_base_color ${c.panel};
      @define-color borders ${c.hairline};
      @define-color unfocused_borders ${c.hairline};
      @define-color content_view_bg ${c.panel};
      @define-color link_color ${c.accent};
      @define-color tooltip_bg_color ${c.raised};
      @define-color tooltip_fg_color ${c.text};
    '')

    # Neovim: lazy.nvim loads this directory as a plugin (see plugins/rice.lua), then `colorscheme rice`.
    # Syntax stays inside the palette: weight and italics carry the structure, colour is for state.
    (file "nvim/colors/rice.lua" ''
      vim.cmd("highlight clear")
      if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
      vim.g.colors_name = "rice"
      vim.o.termguicolors = true
      vim.o.background = "dark"
      local p = { bg = "${c.bg}", panel = "${c.panel}", raised = "${c.raised}", line = "${c.hairline}",
                  text = "${c.text}", muted = "${c.muted}", accent = "${c.accent}",
                  good = "${c.good}", warn = "${c.warn}", crit = "${c.crit}" }
      local groups = {
        Normal = { fg = p.text, bg = p.bg }, NormalNC = { fg = p.text, bg = p.bg },
        NormalFloat = { fg = p.text, bg = p.panel }, FloatBorder = { fg = p.line, bg = p.panel }, FloatTitle = { fg = p.text, bg = p.panel, bold = true },
        Cursor = { fg = p.bg, bg = p.text }, CursorLine = { bg = p.panel }, CursorColumn = { bg = p.panel },
        CursorLineNr = { fg = p.text, bold = true }, LineNr = { fg = p.muted }, SignColumn = { bg = p.bg },
        ColorColumn = { bg = p.panel }, FoldColumn = { fg = p.muted }, Folded = { fg = p.muted, bg = p.panel },
        Visual = { bg = p.raised }, VisualNOS = { bg = p.raised },
        Search = { fg = p.bg, bg = p.accent }, IncSearch = { fg = p.bg, bg = p.accent }, CurSearch = { fg = p.bg, bg = p.accent },
        MatchParen = { fg = p.text, bg = p.raised, bold = true },
        Pmenu = { fg = p.text, bg = p.panel }, PmenuSel = { fg = p.text, bg = p.raised }, PmenuSbar = { bg = p.panel }, PmenuThumb = { bg = p.line },
        StatusLine = { fg = p.text, bg = p.panel }, StatusLineNC = { fg = p.muted, bg = p.panel },
        TabLine = { fg = p.muted, bg = p.panel }, TabLineSel = { fg = p.text, bg = p.bg, bold = true }, TabLineFill = { bg = p.panel },
        WinSeparator = { fg = p.line }, VertSplit = { fg = p.line }, WinBar = { fg = p.text, bg = p.bg }, WinBarNC = { fg = p.muted, bg = p.bg },
        NonText = { fg = p.line }, EndOfBuffer = { fg = p.bg }, Whitespace = { fg = p.line }, SpecialKey = { fg = p.line },
        Conceal = { fg = p.muted }, Directory = { fg = p.text, bold = true }, Title = { fg = p.text, bold = true },
        ErrorMsg = { fg = p.crit }, WarningMsg = { fg = p.warn }, MoreMsg = { fg = p.good }, ModeMsg = { fg = p.text }, Question = { fg = p.text },
        -- syntax
        Comment = { fg = p.muted, italic = true }, SpecialComment = { fg = p.muted, italic = true },
        Constant = { fg = p.text }, String = { fg = p.text }, Character = { fg = p.text },
        Number = { fg = p.text }, Boolean = { fg = p.text, bold = true }, Float = { fg = p.text },
        Identifier = { fg = p.text }, Function = { fg = p.text, bold = true },
        Statement = { fg = p.text, bold = true }, Conditional = { fg = p.text, bold = true }, Repeat = { fg = p.text, bold = true },
        Label = { fg = p.text }, Operator = { fg = p.muted }, Keyword = { fg = p.text, bold = true }, Exception = { fg = p.text, bold = true },
        PreProc = { fg = p.muted }, Include = { fg = p.muted }, Define = { fg = p.muted }, Macro = { fg = p.muted }, PreCondit = { fg = p.muted },
        Type = { fg = p.text, italic = true }, StorageClass = { fg = p.text, bold = true }, Structure = { fg = p.text, italic = true }, Typedef = { fg = p.text, italic = true },
        Special = { fg = p.muted }, SpecialChar = { fg = p.muted }, Tag = { fg = p.text }, Delimiter = { fg = p.muted }, Debug = { fg = p.warn },
        Underlined = { fg = p.text, underline = true }, Error = { fg = p.crit }, Todo = { fg = p.bg, bg = p.warn, bold = true },
        -- state colours
        DiagnosticError = { fg = p.crit }, DiagnosticWarn = { fg = p.warn }, DiagnosticInfo = { fg = p.muted }, DiagnosticHint = { fg = p.muted }, DiagnosticOk = { fg = p.good },
        DiagnosticUnderlineError = { sp = p.crit, undercurl = true }, DiagnosticUnderlineWarn = { sp = p.warn, undercurl = true },
        DiagnosticUnderlineInfo = { sp = p.muted, undercurl = true }, DiagnosticUnderlineHint = { sp = p.muted, undercurl = true },
        DiffAdd = { fg = p.good }, DiffDelete = { fg = p.crit }, DiffChange = { fg = p.warn }, DiffText = { fg = p.text, bg = p.raised },
        Added = { fg = p.good }, Removed = { fg = p.crit }, Changed = { fg = p.warn },
        SpellBad = { sp = p.crit, undercurl = true }, SpellCap = { sp = p.warn, undercurl = true }, SpellRare = { sp = p.muted, undercurl = true }, SpellLocal = { sp = p.muted, undercurl = true },
      }
      for name, spec in pairs(groups) do vim.api.nvim_set_hl(0, name, spec) end
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

      # yazi's own file-type colours (orange images, green archives, ...) are outside the palette:
      # folders are bold, everything else is plain text
      [filetype]
      rules = [
        { url = "*/", fg = "${c.text}", bold = true },
        { url = "*", fg = "${c.text}" },
      ]
    '')

    # swayimg: `include = <this file>` from ~/.config/swayimg/config. Colours are #RRGGBBAA.
    (file "swayimg/theme.conf" ''
      [viewer]
      window = ${c.bg}ff
      transparency = ${c.bg}ff

      [slideshow]
      window = ${c.bg}ff
      transparency = ${c.bg}ff

      [gallery]
      window = ${c.bg}ff
      background = ${c.panel}ff
      select = ${c.raised}ff
      border = ${c.accent}ff
      shadow = ${c.bg}ff

      [font]
      name = ${t.font.ui}
      color = ${c.text}ff
      shadow = ${c.bg}00
      background = ${c.bg}00
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

    # sioyek: ~/.config/sioyek/prefs_user.config links here. Pages are recoloured with the custom colour mode.
    (file "sioyek/theme.config" ''
      background_color ${floats c.bg}
      custom_background_color ${floats c.panel}
      custom_text_color ${floats c.text}
      dark_mode_background_color ${floats c.bg}
      dark_mode_contrast 0.9
      text_highlight_color ${floats c.accent}
      search_highlight_color ${floats c.warn}
      link_highlight_color ${floats c.accent}
      visual_mark_color ${floats c.accent}
      status_bar_color ${floats c.panel}
      status_bar_text_color ${floats c.text}
      startup_commands toggle_custom_color
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

    # swaylock reads this with `swaylock -C <file>` (orbit-lock does); colours are RRGGBB without the #
    (file "swaylock/config" ''
      color=${noHash c.bg}
      font=${t.font.ui},${t.font.uiFallback}
      indicator-radius=84
      indicator-thickness=5
      inside-color=${noHash c.panel}
      inside-clear-color=${noHash c.panel}
      inside-ver-color=${noHash c.panel}
      inside-wrong-color=${noHash c.panel}
      ring-color=${noHash c.hairline}
      ring-clear-color=${noHash c.muted}
      ring-ver-color=${noHash c.accent}
      ring-wrong-color=${noHash c.crit}
      key-hl-color=${noHash c.accent}
      bs-hl-color=${noHash c.crit}
      line-color=00000000
      line-clear-color=00000000
      line-ver-color=00000000
      line-wrong-color=00000000
      separator-color=00000000
      text-color=${noHash c.text}
      text-clear-color=${noHash c.text}
      text-ver-color=${noHash c.text}
      text-wrong-color=${noHash c.crit}
      show-failed-attempts
      ignore-empty-password
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
  # adw-gtk3 is the GTK3 theme that reads the libadwaita colour names generated above; GTK3's own Adwaita
  # bakes its colours in and ignores them. Select it with gtk-theme-name=adw-gtk3-dark.
  environment.systemPackages = [ (pkgs.linkFarm "rice-theme" files) pkgs.adw-gtk3 ];
  # pathsToLink is an allow-list; without this the files never reach /run/current-system/sw
  # dconf overrides gtk-theme-name in settings.ini, so the theme has to be set here as well. color-scheme is what
  # libadwaita (GTK4) apps such as Papers read to choose dark.
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface" = {
      gtk-theme = "adw-gtk3-dark";
      color-scheme = "prefer-dark";
    };
  }];

  environment.pathsToLink = [ "/share/rice-theme" ];
}
