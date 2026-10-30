# frozen_string_literal: true

# app/constants/design_constants.rb
# Centralized Design System Tokens & Typography for RexOne Core (Law U14 & Law U18)
module DesignConstants
  module Brand
    NAME                  = "RexOne"
    ADMIN_TITLE           = "RexOne Admin"
    EMAIL_BADGE_PRIMARY   = "REX"
    EMAIL_BADGE_SECONDARY = "ONE"
    EMAIL_HEADER_LABEL    = "ALERT CENTER"
    COPYRIGHT_OWNER       = "RexOne Ecosystem"
  end

  module Fonts
    GOOGLE_FONTS_URL = "https://fonts.googleapis.com/css2?family=Quicksand:wght@400;500;600;700&display=swap"
    SANS             = "'Quicksand', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
    DISPLAY          = "'Quicksand', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
    MONO             = "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace"
    EMAIL_STACK      = "'Quicksand', Arial, Helvetica, sans-serif"
  end

  module Colors
    # Brand (RexOne Neon Scarlet Night Palette)
    PRIMARY          = "#FF2238"
    PRIMARY_LIGHT    = "#FF5263"
    PRIMARY_DARK     = "#CC1125"
    SECONDARY        = "#FF4D2E"
    SECONDARY_LIGHT  = "#FFF2F4"
    ACCENT           = "#FF0D2D"

    # Surfaces (Dark Obsidian Crimson)
    BG               = "#120c11"
    SURFACE          = "#180f16"
    CARD             = "#20131d"
    CARD_HOVER       = "#291825"
    INPUT_BG         = "#140b12"

    # Borders & Glows
    BORDER           = "#381928"
    BORDER_SUBTLE    = "rgba(255, 255, 255, 0.12)"
    BORDER_GLOW      = "rgba(255, 34, 56, 0.45)"
    GLOW             = "rgba(255, 34, 56, 0.40)"
    GLOW_SUBTLE      = "rgba(255, 34, 56, 0.15)"

    # Typography & Contrast Hierarchy (Law U18: bg primary -> text secondary/light)
    TEXT_PRIMARY     = "#FFFFFF"
    TEXT_SECONDARY   = "#E6D9DF"
    TEXT_MUTED       = "#C9B8BE"
    TEXT_SUBTLE      = "#8A777E"
    TEXT_ON_PRIMARY  = "#FFFFFF"

    # Semantic Status
    SUCCESS          = "#10B981"
    WARNING          = "#F59E0B"
    ERROR            = "#EF4444"
    INFO             = "#38BDF8"
  end
end
