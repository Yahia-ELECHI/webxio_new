# WebXio - Application de Gestion de Projets

Une application mobile Flutter pour la gestion de projets et de tâches, avec authentification et stockage des données dans Supabase.

## Fonctionnalités

- Authentification des utilisateurs (connexion, inscription)
- Gestion des projets (création, modification, suppression)
- Gestion des tâches (création, modification, suppression, changement de statut)
- Stockage des données dans Supabase

## Configuration de Supabase

Pour configurer la base de données Supabase, suivez ces étapes :

1. Connectez-vous à l'interface d'administration de Supabase : https://qxjxzbmihbapoeaebdvk.supabase.co
2. Allez dans l'onglet "SQL Editor"
3. Copiez et collez le contenu du fichier `supabase/setup_complete.sql`
4. Exécutez le script SQL pour créer les tables et les politiques de sécurité

Pour créer un utilisateur de test et des données de test, exécutez :

```bash
dart run lib/scripts/create_test_user_direct.dart
```

## Démarrage

1. Assurez-vous que Flutter est installé sur votre machine
2. Clonez ce dépôt
3. Exécutez `flutter pub get` pour installer les dépendances
4. Exécutez `flutter run` pour lancer l'application

## Identifiants de test

- Email : test@example.com
- Mot de passe : password123

## Structure du projet

- `lib/models/` : Modèles de données (Project, Task)
- `lib/services/` : Services pour interagir avec Supabase
- `lib/screens/` : Écrans de l'application
  - `auth/` : Écrans d'authentification
  - `projects/` : Écrans de gestion des projets
  - `tasks/` : Écrans de gestion des tâches
- `lib/scripts/` : Scripts utilitaires pour la configuration de Supabase
- `supabase/` : Scripts SQL pour la configuration de Supabase
