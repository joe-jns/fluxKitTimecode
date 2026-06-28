# Fork — corrections & améliorations

Fork de **fluxKitTimecode** (par AccelRanger — voir README, licence MIT).
Le projet original n'est **pas** modifié dans son fonctionnement : ce fork
corrige des bugs et ajoute du confort, sans rien retirer.

> Seuls **2 scripts** sont modifiés : `server/root.luau` et `client/root.luau`.
> Pour déployer : remplace le contenu de ces 2 scripts dans le kit installé
> (le serveur = celui avec `logEvent`, le client = celui avec `processShowfile`).

---

## 🐞 Corrections

1. **Premier delay à 0 (automatique)**
   Avant, le 1er event du showfile héritait du temps écoulé depuis le boot du
   serveur → il fallait éditer le JSON à la main (Notepad) à chaque export.
   Désormais `lastEventTime` est remis à zéro au *Start Recording*, et l'export
   force le 1er `Delay` à `0` (`buildExport`). Plus aucune manip.

2. **Ordre de lecture garanti**
   `processShowfile` utilisait `pairs` (ordre non garanti sur un tableau) →
   remplacé par `ipairs`.

3. **Timing sans dérive**
   La lecture attendait chaque `Delay` en relatif (`task.wait`), ce qui accumule
   les imprécisions sur un long show. Désormais chaque event est calé sur une
   **horloge absolue** (temps de départ + somme des delays) → synchro stable.

4. **JSON protégé**
   Décodage du showfile encapsulé dans un `pcall` → message d'erreur clair au
   lieu d'un crash si un show est corrompu.

## ✨ Ajouts

5. **Bouton STOP + touche d'arrêt**
   Impossible avant d'arrêter un show lancé (et 2 clics = 2 shows superposés).
   Ajout d'un garde anti-double-lecture, d'un **bouton "STOP SHOW"** cloné dans
   le menu (même style que les boutons existants) et de la touche **Backspace**.

6. **Blackout propre à l'arrêt**
   À l'arrêt, les effets restés allumés (haze, breath…) sont coupés, et la
   **musique** (jouée côté serveur) est stoppée via `soundRemote` (`"__STOP__"`).

7. **Indicateurs en direct**
   - Enregistrement : `● REC — N events — Ts`
   - Lecture : `Lecture X/N — Ts`
   (nouvelle requête serveur `clientData("recordingCount")`).

---

Tous les changements sont commentés dans le code avec le tag `[FORK]`.
Crédit du projet original : **AccelRanger**. Licence : **MIT** (inchangée).
