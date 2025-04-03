#!/bin/bash

# Script pour générer l'index.html principal listant tous les slideshows
# disponibles (basés sur les sous-dossiers SHA256) dans le dossier de build.

set -e # Arrête le script en cas d'erreur

# --- Argument ---
BUILD_DIR="$1"

# Vérification de l'argument
if [ -z "$BUILD_DIR" ] || [ ! -d "$BUILD_DIR" ]; then
  echo "Usage: $0 <build_dir>"
  echo "Erreur: Le dossier de build '$BUILD_DIR' est manquant ou invalide."
  exit 1
fi

INDEX_FILE="$BUILD_DIR/index.html"

echo "Generating main index file at: $INDEX_FILE"

# --- Génération du HTML ---
# Début du fichier HTML
echo "<!DOCTYPE html>
<html lang='fr'>
<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <title>Liste des Présentations PDF</title>
  <style>
    body { font-family: sans-serif; line-height: 1.4; margin: 2em; }
    ul { list-style: none; padding: 0; }
    li { margin-bottom: 0.5em; }
    a { text-decoration: none; }
    a:hover { text-decoration: underline; }
    code { background-color: #f0f0f0; padding: 0.2em 0.4em; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>Présentations PDF Converties</h1>
  <p>Généré le: $(date)</p>
  <ul>" > "$INDEX_FILE" # Écrase ou crée le fichier index

# Trouve tous les sous-dossiers (SHA256) dans build/, en excluant 'dist' et 'plugin'
find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! \( -name dist -o -name plugin \) -print0 | sort -z | while IFS= read -r -d $'\0' dir; do
  checksum=$(basename "$dir")
  # Ajoute un lien pour chaque dossier trouvé
  echo "    <li><a href='$checksum/index.html'><code>$checksum</code></a></li>" >> "$INDEX_FILE"
done

# Fin du fichier HTML
echo "  </ul>
</body>
</html>" >> "$INDEX_FILE"

echo "Main index file generated successfully."

exit 0
