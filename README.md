# OSIA Mobile

Compagnon mobile de l'assistant vocal local **OSIA**.

OSIA Mobile vous permet d'interagir avec votre assistant OSIA à distance,
via le réseau Tailscale. Envoyez des commandes texte ou vocales depuis
votre téléphone : le traitement (STT, agent IA, TTS) se fait sur votre PC,
et la réponse audio est lue directement sur le téléphone.

## Architecture

```
Téléphone (Flutter)  ←─ WebSocket (Tailscale) ─→  PC serveur (FastAPI)
     │                                                    │
     ├─ Texte / Audio (WAV base64) ──────────────────────→│
     │                                                    ├─ STT (faster-whisper)
     │                                                    ├─ Agent OSIA (Ollama)
     │                                                    └─ TTS (Kokoro)
     │                                                    │
     ←── Réponse texte + Audio (MP3 base64) ──────────────┘
```

## Prérequis

- Un PC sous Linux avec le projet [OSIA](https://github.com/mertioz/osia-project) installé
- [Tailscale](https://tailscale.com/) installé sur le PC et le téléphone
- Flutter 3.x installé sur la machine de build

## Lancement du serveur PC

Depuis le dossier du projet OSIA :

```bash
cd /home/OSIA/code/osia-project
source venv/bin/activate
python -m osia.server.server
```

Au premier démarrage, un token d'authentification est généré dans
`config/mobile_token.txt`. Copiez ce token pour la configuration mobile.

Le serveur écoute sur `0.0.0.0:8765`.

## Configuration de l'application mobile

1. Ouvrez l'application OSIA Mobile
2. Remplissez l'**adresse IP Tailscale** de votre PC (ex: `100.64.0.42`)
3. Collez le **token** affiché dans `config/mobile_token.txt` sur le PC
4. Appuyez sur **Se connecter**

## Build de l'application

```bash
cd osia-mobile
flutter pub get
flutter build apk --release    # Android
flutter build ios --release    # iOS
```

## Design

- Fond noir profond `#0D0B12`
- Accent violet `#C4B5F5` / `#7C3AED`
- Bulles de chat avec glassmorphism
- Indicateur de réflexion animé (violet, jamais orange)
- Animations fluides sur les interactions

## Licence

Projet privé — Tous droits réservés.
