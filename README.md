# Générateur de Slideshows PDF vers Reveal.js

Ce dépôt contient un système automatisé pour convertir des fichiers PDF en présentations web interactives basées sur [Reveal.js](https://revealjs.com/). Le processus utilise GitHub Actions, Docker, et des scripts shell pour générer les slideshows et les déployer automatiquement sur GitHub Pages.

L'objectif est de fournir une alternative auto-hébergée et contrôlée pour partager des présentations, inspirée par le besoin de remplacer des plateformes comme SlideShare.

**✨ Voir les slideshows générés : [https://rngadam.github.io/slideshows/](https://rngadam.github.io/slideshows/) ✨**

[![Build Status](https://github.com/rngadam/slideshows/actions/workflows/pdf-slideshow.yml/badge.svg)](https://github.com/rngadam/slideshows/actions/workflows/pdf-slideshow.yml)
[![Docker Image Build](https://github.com/rngadam/slideshows/actions/workflows/docker-build.yml/badge.svg)](https://github.com/rngadam/slideshows/actions/workflows/docker-build.yml)

## Comment ça fonctionne ?

Le processus est entièrement automatisé via GitHub Actions :

1.  **Déclenchement :** Le workflow principal (`pdf-slideshow.yml`) est déclenché soit par :
    * Un `push` ajoutant/modifiant des fichiers `.pdf` dans le dossier `pdf/` du dépôt.
    * Un déclenchement manuel via l'onglet "Actions" avec une URL de PDF spécifiée.
2.  **Exécution dans Docker :** Le job s'exécute dans un conteneur Docker basé sur Alpine Linux (défini dans le `Dockerfile` et hébergé sur `ghcr.io`). Ce conteneur inclut toutes les dépendances nécessaires (`poppler-utils`, `pngquant`, `curl`, etc.) ainsi que les scripts de traitement.
3.  **Traitement du PDF :** Le script `process_pdf.sh` est appelé :
    * Il télécharge le PDF (si URL) ou utilise le fichier local.
    * Calcule le hash SHA-256 du contenu du PDF.
    * Vérifie si un résultat existe déjà (via le nom de dossier basé sur le hash) pour utiliser le cache GitHub Actions.
    * Si nécessaire, convertit chaque page du PDF en image PNG (`pdftoppm`).
    * Compresse les images PNG (`pngquant`).
    * Génère un fichier `index.html` Reveal.js où chaque image est une diapositive en arrière-plan plein écran (`data-background-image`, `data-background-size='contain'`).
    * Stocke le résultat dans un dossier nommé d'après le hash SHA-256 (ex: `build/HASH123...`).
    * Sauvegarde le nom de fichier original dans `pdf_basename.txt` à l'intérieur du dossier du hash.
4.  **Génération de l'Index :** Le script `generate_main_index.sh` crée un `index.html` principal dans le dossier `build` qui liste toutes les présentations disponibles (en lisant les `pdf_basename.txt` pour les titres) avec des liens vers celles-ci.
5.  **Mise en Cache :** Les résultats dans le dossier `build` sont mis en cache par GitHub Actions pour accélérer les exécutions futures si les PDF et les scripts n'ont pas changé.
6.  **Déploiement :** Le contenu final du dossier `build` est déployé sur GitHub Pages.

## Fonctionnalités

* Conversion automatisée PDF vers Reveal.js.
* Entrée via le dossier local `pdf/` ou via une URL distante.
* Organisation des slideshows générés par le hash SHA-256 du contenu PDF.
* Affichage des diapositives en plein écran (images en arrière-plan).
* Environnement Dockerisé (Alpine Linux) pour la cohérence et l'efficacité.
    * Image Docker légère hébergée sur `ghcr.io`.
    * Scripts inclus dans l'image pour une utilisation standalone.
* Utilisation du cache GitHub Actions pour éviter le retraitement inutile.
* Déploiement automatique sur GitHub Pages.

## Utilisation

Il y a deux façons principales d'ajouter de nouvelles présentations :

### Méthode 1 : Ajouter un PDF au dossier `pdf/`

1.  Assurez-vous qu'un dossier nommé `pdf/` existe à la racine du dépôt.
2.  Ajoutez un ou plusieurs fichiers `.pdf` dans ce dossier `pdf/`.
3.  Commitez et poussez vos changements vers la branche `main` (ou la branche par défaut configurée).
4.  Le workflow "Generate Slideshow from PDF (using Docker)" se déclenchera automatiquement, traitera **tous** les PDF présents dans le dossier `pdf/` (en utilisant le cache pour ceux déjà traités), et mettra à jour le site GitHub Pages.

### Méthode 2 : Utiliser une URL via l'onglet Actions

1.  Allez dans l'onglet "Actions" du dépôt sur GitHub.
2.  Dans la barre latérale gauche, sélectionnez le workflow "Generate Slideshow from PDF (using Docker)".
3.  Cliquez sur le bouton "Run workflow" à droite.
4.  Entrez l'URL complète du fichier PDF que vous souhaitez convertir dans le champ "URL of the PDF file to convert".
5.  Cliquez sur le bouton vert "Run workflow".
6.  Le workflow traitera uniquement le PDF de l'URL fournie et mettra à jour le site GitHub Pages.

## Utilisation Standalone (via Docker)

L'image Docker construite par ce dépôt peut également être utilisée localement si vous avez Docker installé. L'image inclut toutes les dépendances et les scripts.

1.  **Récupérer l'image :**
    ```bash
    docker pull ghcr.io/rngadam/slideshows:latest
    ```

2.  **Traiter un fichier PDF local :**
    ```bash
    # Créez un dossier local pour la sortie, par exemple 'output_slides'
    mkdir -p output_slides

    # Exécutez le conteneur en montant votre dossier PDF et le dossier de sortie
    docker run --rm \
      -v "$(pwd)/pdf:/input_pdfs:ro" `# Monte votre dossier pdf local en lecture seule` \
      -v "$(pwd)/output_slides:/build_output" `# Monte votre dossier de sortie` \
      ghcr.io/rngadam/slideshows:latest \
      -f /input_pdfs/VOTRE_FICHIER.pdf -b /build_output
    ```
    *(Remplacez `VOTRE_FICHIER.pdf` par le nom de votre fichier)*

3.  **Traiter un PDF depuis une URL :**
    ```bash
    # Créez un dossier local pour la sortie
    mkdir -p output_slides

    # Exécutez le conteneur en montant seulement le dossier de sortie
    docker run --rm \
      -v "$(pwd)/output_slides:/build_output" \
      ghcr.io/rngadam/slideshows:latest \
      -u "URL_DE_VOTRE_PDF" -b /build_output
    ```

4.  **Générer l'index principal (après traitement) :**
    ```bash
    # Assurez-vous que le dossier de sortie contient les dossiers de hash générés
    docker run --rm \
      --entrypoint /app/scripts/generate_main_index.sh \
      -v "$(pwd)/output_slides:/build_output" \
      ghcr.io/rngadam/slideshows:latest \
      /build_output
    ```
    Le fichier `index.html` sera généré dans votre dossier `output_slides`.

## Structure du Dépôt

* `Dockerfile`: Définit l'image Docker Alpine avec les dépendances.
* `.github/workflows/`: Contient les workflows GitHub Actions.
    * `docker-build.yml`: Construit et pousse l'image Docker vers `ghcr.io`.
    * `pdf-slideshow.yml`: Workflow principal qui traite les PDF et déploie sur Pages.
* `.github/scripts/`: Contient les scripts shell utilisés dans le processus.
    * `process_pdf.sh`: Script unifié pour traiter un PDF (URL ou local).
    * `generate_main_index.sh`: Génère l'index HTML principal.
* `pdf/`: Dossier où placer les fichiers PDF locaux pour déclencher le traitement automatique.

## Technologies Utilisées

* GitHub Actions
* Docker / ghcr.io
* Alpine Linux
* Reveal.js
* Poppler (`pdftoppm`)
* Pngquant
* Shell Script (Bash/Ash compatible)
* GitHub Pages

## Licence

[Choisissez une licence, par exemple : MIT License]
