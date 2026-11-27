# Design tokens — the single source of truth for the rice (see RICE_SPEC.md).
# Everything under modules/theme/ is generated from this file; edit values here only.
{
  color = {
    bg       = "#0E1013";
    panel    = "#171A1F";
    raised   = "#20242B";
    hairline = "#2C313A";
    text     = "#F2F4F7";
    muted    = "#8B93A1";
    accent   = "#4C9EFF";  # focus/selection only
    good     = "#3FCF8E";  # states only
    warn     = "#F5A524";
    crit     = "#F2555A";
  };

  font = {
    ui        = "D-DIN";
    uiFallback = "Inter";    # D-DIN is not in nixpkgs yet
    mono      = "JetBrainsMono Nerd Font";
    monoSize  = 12;
    uiSize    = 13;
  };

  # One spring for niri and quickshell: slight overshoot, then settle.
  motion.spring = {
    dampingRatio = 0.75;
    stiffness    = 700;
    epsilon      = 0.0001;
  };

  radius = 12;
  gap    = 8;
}
