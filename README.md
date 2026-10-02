# Panel

Tableau de bord personnel en Flutter, pensé pour un écran toujours allumé (tablette, PC, téléphone) : musique, agenda, profil Discord, suivi des abonnements, soundboard et liens rapides.

## Fonctionnalités

| Onglet | Contenu |
| --- | --- |
| **Panel** | Lecteur Spotify (lecture, pistes, playlists), agenda Google du jour (créer / modifier / supprimer des rappels), carte de profil Discord. Tirer vers le bas pour tout rafraîchir. |
| **Dépenses** | Abonnements avec total mensuel et annuel, part de chaque abonnement, suggestions (Netflix, Spotify…), édition au tap, suppression par balayage avec annulation. |
| **Sons** | Soundboard de gros boutons colorés (MP3, WAV, OGG, M4A), bouton « tout arrêter », appui long pour modifier. |
| **Liens** | Favoris avec favicon automatique ou image de fond, copie du lien, édition. |
| **Paramètres** | Couleur d'accent (nuancier ou hexadécimal), image de fond, état des comptes connectés et déconnexion instantanée, QR code Wi-Fi invités. |

L'interface s'adapte : barre de navigation en bas sur mobile, rail latéral et mise en page en deux colonnes sur grand écran.

## Démarrage

```bash
flutter pub get
cp .env.example .env   # puis renseignez vos identifiants
flutter run
```

### Variables `.env`

```
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
SPOTIFY_REDIRECT_URI=com.panel.panelapp://callback
DISCORD_CLIENT_ID=
DISCORD_CLIENT_SECRET=
DISCORD_REDIRECT_URI=com.panel.panelapp://callback
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
```

Sans `.env`, l'application démarre quand même ; seules les connexions aux services externes sont indisponibles.

## Architecture

```
lib/
├── core/
│   ├── theme/          # Design system : couleurs, espacements, rayons, ThemeData
│   └── utils/          # Formatage (€, dates en français, URL)
├── data/
│   ├── models/         # Subscription, SoundItem, LinkItem
│   └── local_store.dart# Persistance JSON (SharedPreferences)
├── presentation/
│   ├── pages/          # Onglets + paramètres
│   └── widgets/
│       └── common/     # AppCard, PageHeader, dialogues, feuilles, états vides…
└── services/           # Spotify, Google Agenda, thème
```

Tous les styles (boutons, champs, dialogues, feuilles, navigation) sont définis une seule fois dans `lib/core/theme/app_theme.dart` et suivent la couleur d'accent choisie.

## Qualité

```bash
flutter analyze
flutter test
```
