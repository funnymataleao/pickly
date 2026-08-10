# Reicon UI icons

Pickly interface icons are sourced from [Reicon](https://reicon.dev/icons) and
rendered as tintable 24 x 24 SVG template assets. Outline icons are the default;
filled variants are reserved for active, selected, and confirmed states.

The committed SVG assets were generated from `reicon-react` 1.1.302 with:

```sh
node Scripts/generate-reicon-assets.mjs \
  /path/to/reicon-react/package \
  Pickly/Assets.xcassets/Reicon
```

Reicon is distributed under the MIT License. Copyright (c) 2026 Dev Chauhan.
See the upstream [license](https://github.com/dqev/reicon/blob/main/LICENSE) and
[credits](https://github.com/dqev/reicon#credits).
