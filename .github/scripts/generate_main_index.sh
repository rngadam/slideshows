#!/bin/bash
set -e

BUILD_DIR="$1"

# --- Validation ---
if [ -z "$BUILD_DIR" ] || [ ! -d "$BUILD_DIR" ]; then
  echo "Usage: $0 <build_dir>"
  echo "Erreur: Le dossier de build '$BUILD_DIR' est manquant ou invalide."
  exit 1
fi

INDEX_FILE="$BUILD_DIR/index.html"

echo "Generating main index file at: $INDEX_FILE"

# --- Génération HTML ---
cat <<EOF > "$INDEX_FILE"
<!DOCTYPE html>
<html lang='fr'>
<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <title>Liste des Présentations PDF</title>
  <style>
    body { font-family: sans-serif; line-height: 1.4; margin: 2em; }
    ul { list-style: none; padding: 0; }
    li { margin-bottom: 0.5em; border-left: 3px solid #eee; padding-left: 1em; }
    a { text-decoration: none; color: #0366d6; }
    a:hover { text-decoration: underline; }
    .pdf-title { font-weight: bold; display: block; margin-bottom: 0.2em; }
    .pdf-hash { font-size: 0.85em; color: #586069; font-family: monospace; }
  </style>
</head>
<body>
  <h1>Présentations PDF Converties</h1>
  <p>Généré le: $(date)</p>
  <ul>
EOF

# Trouve tous les sous-dossiers (SHA256) dans build/, en excluant 'dist' et 'plugin'
find "$BUILD_DIR" -maxdepth 1 -mindepth 1 -type d ! \( -name dist -o -name plugin \) -print0 | sort -z | while IFS= read -r -d $'\0' dir; do
  checksum=$(basename "$dir")
  title="$checksum" # Titre par défaut = hash
  basename_file="$dir/pdf_basename.txt"

  # Essayer de lire le nom de base original s'il existe
  if [ -f "$basename_file" ]; then
    read -r title < "$basename_file"
    # Nettoyer le titre (échapper les caractères HTML potentiels - basique)
    title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    # Si le titre est vide après lecture, revenir au checksum
    if [ -z "$title" ]; then
        title="$checksum"
    fi
  fi

  # Ajoute un lien formaté
  echo "    <li>" >> "$INDEX_FILE"
  echo "      <a href='$checksum/index.html'>" >> "$INDEX_FILE"
  echo "        <span class='pdf-title'>$title</span>" >> "$INDEX_FILE"
  echo "        <span class='pdf-hash'>$checksum</span>" >> "$INDEX_FILE"
  echo "      </a>" >> "$INDEX_FILE"
  echo "    </li>" >> "$INDEX_FILE"
done

# Fin du fichier HTML
echo "  </ul>
</body>
</html>" >> "$INDEX_FILE"

echo "Main index file generated successfully."
exit 0

