# Application mark

The **Play again / Archive F** mark is an original FlSteamLua design. A cut
fluorescent F suggests a stack of files opening forward; the warm-white play
triangle supplies the second, game-facing silhouette. The flat geometry remains
legible in small Windows taskbar and tray slots.

| Role | Color |
| --- | --- |
| Charcoal tile | `#171A17` |
| Fluorescent archive F | `#D2F45B` |
| Warm-white play mark | `#F0EEE6` |

`app.svg` is the master vector. `app.png` is a 256×256 transparent export and
`app-512.png` is a 512×512 export. `app.ico` contains individually rasterized
16, 20, 24, 32, 40, 48, 64, 128 and 256-pixel images; the same ICO is copied to
`windows/runner/resources/app_icon.ico`. Existing references cover the About
page, tray, native window/taskbar and installer. Website assets use the same SVG.

The SVG is rendered with `@resvg/resvg-js` 2.6.2. The ICO only packages those PNG
renders; no screenshots, platform logos or generative bitmap assets are used.
To regenerate without changing application dependencies:

```powershell
npm.cmd install --prefix .git/references/icon-tools --no-audit --no-fund --save-exact @resvg/resvg-js@2.6.2
node assets/branding/export-icon.cjs .git/references/icon-tools/node_modules/@resvg/resvg-js
```

These assets are distributed under the project's GPL-3.0 license. They contain
no FlClash or Steam brand artwork.
