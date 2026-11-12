# README artwork

Generated with the built-in imagegen tool on 2026-11-11.

- `docs/images/QScreenStory.png`: approved three-panel story, generated artwork.
- `docs/images/HowToUse.png`: user-provided English menu tutorial, copied unchanged.
- `docs/images/QScreenDesk.png`: generated desk illustration using the real `build/previews/restroom-en.png` screen saver render as its edit target. The desk illustration is not a photograph or evidence of a hardware test.

The original generated files remain in the image generation output directory. The README consumes the copies saved in this repository. App character animation is still drawn natively; these generated images are documentation assets only.

## Story illustration prompt

```text
Use case: illustration-story.
Create a polished wide three-panel comic strip for the GitHub README of QScreen, a cute macOS app that shows an away reason and return time on an office worker's locked external monitor. This is a PREVIEW of the story art, not a README layout. Landscape approximately 2.7:1, three equally sized panels arranged left to right, generous white margins and slim rounded warm-gray panel borders. No headings or captions.

Visual style: charming, restrained flat picture-book / code-vector-like illustration matching a cozy Mac utility: warm ivory background, sage green, honey yellow, dusty brown, soft gray. Simple rounded shapes, crisp smooth contours, tiny oval eyes, warm blush cheeks, minimal delicate shading, no photorealism, no 3D render, no loud gradients. Clear uncluttered compositions; readable at GitHub README width. Keep the same characters, desk, monitor, and viewing angle across all three panels.
Employee: a very cute small golden-yellow duck with a rounded head, tiny orange flat beak, short round wings, small feet, mint employee lanyard. Manager: a friendly round brown bear with round glasses and a simple sage blazer, carrying a small clipboard. Both have compact natural cartoon limbs; absolutely no elongated arms, trunk-like fingers, distorted hands, or human hands.

Story:
PANEL 1: the duck employee hurriedly tiptoes away from their desk toward a restroom door at the side, doing an adorable urgent waddle with a couple of small motion marks and a nervous blush. The restroom door uses ONLY a simple recognizable restroom pictogram, no word. The desk has an open silver MacBook connected to a large external monitor, an empty office chair, and one small plant. Monitor is plain dark / no status yet. The office is minimalist and cozy.
PANEL 2: the bear manager arrives at the SAME now-empty workstation and looks puzzled at the empty chair. One small speech/thought bubble containing only '?' expresses where the duck went. The monitor remains plain dark, no status. No angry or intimidating boss.
PANEL 3: same workstation and bear manager, now with a relaxed happy 'ah, got it' expression. The large external monitor is brightly showing QScreen's pale mint screen saver: a cute miniature yellow duck above TWO clearly legible English lines, exactly 'Restroom break' and 'Back in 5 min'. Make the external monitor large and front-facing enough for those two lines to be clearly readable. The bear understands the absence by reading the screen. A small reassuring sparkle by the bear's glasses is enough, no dialogue. The laptop stays open beside the monitor.

Text constraints: the ONLY written text anywhere in the image is '?' in panel 2 and 'Restroom break' / 'Back in 5 min' on panel 3's monitor. No other captions, labels, panel numbers, slogan, watermark, installation instruction, UI tutorial, logos, or fake gibberish. Tell the story through expressions and staging. Balance the three panels with consistent object and character scale.
```

## Desk illustration prompt

```text
Use case: compositing.
Asset type: QScreen GitHub README product illustration showing how the Mac desk looks during an away status.
Input image 1 is an EDIT TARGET: the real, working QScreen screen saver capture. Keep its pale mint background, precise flat yellow duck design, layout, and the text "Restroom break" and "Back in about 4 minutes" unchanged. Place this complete screen capture cleanly and faithfully inside the display of a large external monitor. Do not invent another screen saver or add macOS windows, docks, clocks or fake lock controls.

Create a polished wide landscape approximately 2:1 illustration of a simple office desk with that external monitor as the focal point, an open silver MacBook connected beside it, a small sage green office chair and one little potted plant. Show the monitor nearly front-on, occupying most of the image so the real QScreen artwork and both status lines remain easily readable. The MacBook is smaller beside the monitor, open and seen mostly from its back/side so it does not need extra screen content. No people. No keyboard clutter or extra accessories. The desk and simple setting should match the warmth of a gentle office animal comic: warm ivory background, sage and dusty brown accents, restrained rounded contours, soft delicate shading, premium cozy editorial illustration, no photorealism or 3D gloss. Maintain believable hardware proportions. Generous whitespace around the desk scene.

Only visible words are the two original status lines from the supplied screen capture. No added headings, captions, slogans, panel numbers, labels, watermarks or logos. Do not redraw or reinterpret the duck into a different character. The output should clearly show a real screen saver on an external monitor connected to a MacBook, ready to place beneath a short usage diagram in a visual README.
```

