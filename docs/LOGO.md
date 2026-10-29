# Guitar Jim portrait logo

Generated with the built-in imagegen tool on 28 October 2026, at the user's request for a cartoon-like Jimmy Page app logo.

- Source illustration: `Sources/GuitarPractice/Resources/jimmy-page-logo.png`.
- Native macOS icon: `Assets/AppIcon.icns`.
- Consumers: sidebar branding, application icon, Dock icon, Finder bundle icon and menu bar icon. Active recording adds a red badge to the menu bar portrait.
- Regenerate the native icon sizes with `./Scripts/build-icon.sh`; rebuild the app with `./Scripts/build-app.sh`.

The source image is preserved with its alpha channel. The ICNS contains mechanically resized versions of that image; the portrait itself is not edited by the packaging script.

Verified the signed app build, bundled PNG and ICNS lookup, and the rendered sidebar at 1280 × 850. The app was reopened with the new icon and the previously selected U2 arrangement restored. [Native app preview](assets/logo-in-app.jpg).

The native icon is declared by `CFBundleIconFile = AppIcon.icns`. Version 0.1.1 increments the bundle build number so macOS refreshes the previously cached application identity. The build script registers only this app with Launch Services after signing; it does not restart Finder or the Dock. The running app also sets its application icon from the packaged multi-resolution ICNS.

## Original generation prompt

```text
Use case: logo-brand.
Asset type: one final 1024 by 1024 macOS app icon, also used as a sidebar logo for an arcade-style guitar practice app called Guitar Jim.
Primary request: a cartoon-like, recognizable portrait of Jimmy Page in his 1970s Led Zeppelin era.
Subject: Jimmy Page, slim angular face, youthful expressive eyes, distinctive long voluminous dark curly hair, a slight confident smile, wearing a black rock-stage jacket with a small cream embroidered dragon detail. Head and shoulders dominate. A small amber sunburst electric-guitar upper body or diagonal guitar neck appears at the lower edge as a supporting motif, with no guitar brand lettering.
Style: original polished cartoon caricature, bold clean ink outlines, simplified flat graphic shapes, restrained screen-print texture, high contrast, warm cream skin tones, amber and gold highlights, charcoal hair and shadows. A friendly rock-arcade mascot rather than a photorealistic portrait.
Composition: square app icon with a dark charcoal rounded-square tile and genuinely transparent outer corners; bust centered with face large and easy to read at 32 pixels. Hair must have a clear silhouette. Place a flat amber circular spotlight behind the head to distinguish dark curls from the charcoal tile. Comfortable safe margins inside the tile so the hair is not clipped.
Palette: charcoal #111518, amber #FABB4D, warm ivory #F5F2E4, muted terracotta for small shading accents. Match a premium dark arcade cabinet.
Constraints: one icon only, no mockup, no interface, no collage, no text, no initials, no wordmark, no watermark, no logos or symbols associated with Led Zeppelin, no photographic detail, no busy background, no tiny ornament. Preserve actual transparency outside the rounded-square tile.
```

## Muscular revision

Updated with the built-in imagegen editing tool on 28 October 2026. The current illustration has broader shoulders and defined arms, while preserving Jimmy Page's face, hair, guitar, palette and icon framing. All native icon sizes and menu bar images use the updated portrait. The previous PNG is preserved at `Assets/previous/jimmy-page-logo-v1.png`. Bundle version 0.1.2 refreshes the installed icon identity.

Current saved artwork: `Sources/GuitarPractice/Resources/jimmy-page-logo.png`. Native icon: `Assets/AppIcon.icns`.

### Final edit prompt

```text
Use case: identity-preserve.
Edit target: the attached current Guitar Jim app icon, a cartoon portrait of Jimmy Page.
Requested change: make the character noticeably more muscular, with broad powerful shoulders, a thicker athletic neck, a defined chest, and visibly muscular upper arms/biceps. Use an exaggerated but tasteful rock-arcade superhero build. Change the black stage jacket into a fitted sleeveless black stage vest so the strong arms are clearly visible; keep a cream/gold dragon embroidery motif on the vest. Keep the electric guitar in the lower part of the icon.
Preserve: the recognizable Jimmy Page face and expression, long voluminous dark curly hair, cartoon illustration style, confident friendly attitude, charcoal rounded-square tile, amber circular spotlight, warm cream/amber/charcoal palette, original square icon composition and genuinely transparent outer corners. Keep the face large enough to read as an app icon. Slightly widen the upper-body framing only as needed to show the larger shoulders and at least one prominent bicep.
Make the increased muscularity unmistakable at small sizes, using bold clean contours and simple light/shadow shapes. Do not turn the face into a different person or a bodybuilder celebrity. Do not add props, text, initials, brands, watermarks, additional people, or new background elements. One finished icon only, no mockups or comparison collage.
```
