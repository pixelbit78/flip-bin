{{flutter_js}}
{{flutter_build_config}}

// Self-hosted engine + fonts (SPEC §12.8): CanvasKit is served from
// /canvaskit/ (built with --no-web-resources-cdn) and fallback fonts from
// /assets/fallback_fonts/, so nothing loads from www.gstatic.com or
// fonts.gstatic.com.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
    fontFallbackBaseUrl: "assets/fallback_fonts/",
  },
});
