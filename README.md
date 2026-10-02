# Panel

Tableau de bord personnel en Flutter, pensé pour un écran toujours allumé (tablette, PC, téléphone) : musique, agenda, profil Discord, suivi des abonnements, soundboard et liens rapides.

## Fonctionnalités

| Onglet | Contenu |
| --- | --- |
| **Accueil** | Grande horloge, météo du jour (Open-Meteo, sans clé ni localisation), lecteur Spotify (pochette floutée, contrôles, playlists), agenda Google avec sélecteur de semaine, prochains prélèvements, profil Discord. Chaque carte peut être masquée. |
| **Dépenses** | Abonnements hebdo / mensuels / trimestriels / annuels, total mensuel et annuel, graphique par catégorie (touchez une part pour filtrer), prélèvements des 30 prochains jours, tri, suppression par balayage avec annulation. |
| **Sons** | Gros boutons en relief avec icône et couleur, volume général et par son, lecture en boucle, bouton « Tout arrêter », réorganisation par glisser-déposer. |
| **Liens** | Favoris avec favicon automatique ou image de fond, recherche, groupes, réorganisation, copie du lien. |
| **Paramètres** | Apparence (nuancier + roue de couleurs, fond d'écran avec flou et assombrissement, aperçu en direct), cartes de l'accueil, ville météo, comptes connectés (connexion / déconnexion sans redémarrage), vibrations, horloge 24 h, Wi-Fi invités par QR code, sauvegarde / restauration / réinitialisation. |

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

Organisation par fonctionnalité : chaque dossier de `features/` contient son modèle, sa logique (contrôleur `ChangeNotifier`) et ses écrans.

```
lib/
├── main.dart              # Initialisation (dates FR, .env, chargement des données)
├── app/
│   ├── app.dart           # MaterialApp + thème
│   ├── app_scope.dart     # État partagé (context.app)
│   └── shell.dart         # Fond d'écran + barre de navigation flottante
├── core/
│   ├── theme/             # Design system : couleurs, espacements, rayons, ThemeData (police Inter)
│   ├── storage/           # Persistance JSON (SharedPreferences)
│   ├── utils/             # Formatage (€, dates FR, URL), vibrations
│   └── widgets/           # AppPage, AppCard, AppSection/AppTile, feuilles, roue de couleurs…
└── features/
    ├── home/              # Accueil + horloge + carte dépenses
    ├── subscriptions/     # Dépenses : modèle, contrôleur, graphique, formulaire
    ├── soundboard/        # Sons : contrôleur audio, buzzer, formulaire
    ├── links/             # Liens : contrôleur, formulaire
    ├── spotify/ calendar/ discord/ weather/   # Services externes + cartes
    └── settings/          # Paramètres, apparence, Wi-Fi, sauvegarde
```

Les données déjà enregistrées par les versions précédentes sont relues telles quelles.

## Qualité

```bash
flutter analyze
flutter test
```
