# Post LinkedIn — mm

Visuels (joindre dans cet ordre en carrousel) :

1. `linkedin-mm-hero.jpg`
2. `linkedin-mm-attention.jpg`
3. `linkedin-mm-safety.jpg`

---

## Texte (copier-coller)

La plupart des outils de « maintenance Mac » font trop.

Ou alors ils cachent une mutation derrière un bouton vert.

J’ai publié **mm** : un petit CLI + menu bar pour macOS qui te dit l’état de la machine — Homebrew, disque, Time Machine, FileVault — **sans upgrade surprise, sans sudo, sans nettoyeur qui efface tes fichiers**.

Ce qui compte pour moi :

→ `mm update` informe. `mm upgrade` mute. Point.
→ Les jobs auto passent par **launchd**, pas cron.
→ Les upgrades hebdo sont **off** tant que tu n’optes pas in.
→ Le menu `mm ●` reste **dans l’app** : dashboard, paramètres, guide, console — plus de Terminal ni de navigateur pour comprendre ce qui cloche.

Amber = attention, avec la liste claire :
Time Machine — no backup · FileVault — disabled · packages outdated…

Open source, MIT.

GitHub : https://github.com/R0PR1/a-little-Mac-Maintenance-Tool

```bash
brew tap r0pr1/mm https://github.com/R0PR1/a-little-Mac-Maintenance-Tool
brew install r0pr1/mm/mm
mm menubar enable
```

Si tu maintiens des Mac (ou le tien) et que tu en as marre des outils magiques : je suis preneur de retours.

#macOS #OpenSource #Homebrew #DevTools #Bash

---

## Variante courte

**mm** — santé macOS sans mauvaises surprises.

CLI + menu bar. Homebrew / disque / Time Machine / FileVault.
`update` lit. `upgrade` écrit. launchd, pas cron. MIT.

→ https://github.com/R0PR1/a-little-Mac-Maintenance-Tool
