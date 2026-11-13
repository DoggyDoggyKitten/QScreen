# QScreen website previews

Five buildless HTML/CSS/JavaScript landing-page directions share the app's cream, sage, rounded typography and six original vector characters. Open `index.html?view=1` through `?view=5` to compare them; the top bar changes direction without resetting the selected character.

Local preview:

```sh
python3 -m http.server 8776 --bind 127.0.0.1 --directory website
```

The browser demo changes the character, reason, return time and background. The off-work state has no timer. Direction 4 demonstrates the menu-bar flow; its simulated desktop does not lock the visitor's computer. Directions 2 and 3 have a keyboard-dismissible expanded preview. Reduced motion is respected. Downloads point to the signed and notarized 1.0.0 DMG on GitHub Releases.

GitHub Pages publishes only this directory using `.github/workflows/pages.yml`. No server, credentials, account creation, analytics or external font service is used by the page. GitHub's hosting infrastructure has its own request logging. These review previews are marked `noindex`; select a final direction before treating them as the finished public marketing site.

Artwork is derived from `Shared/QSSceneView.m`; the wordmark is the existing user-approved project asset. Nunito is locally hosted under the SIL Open Font License; see `assets/Nunito-OFL.txt`. Other original code and artwork use the repository's MIT license.
