#!/bin/bash

# Script pour traiter un fichier PDF local, convertir en slideshow Reveal.js
# et organiser par SHA256sum.

set -e # Arrête le script en cas d'erreur

# --- Arguments ---
PDF_FILE_PATH="$1"
BUILD_DIR="$2"

# Vérification des arguments
if [ -z "$PDF_FILE_PATH" ] || [ ! -f "$PDF_FILE_PATH" ]; then
  echo "Usage: $0 <pdf_file_path> <build_dir>"
  echo "Erreur: Le fichier PDF '$PDF_FILE_PATH' est manquant ou invalide."
  exit 1
fi
if [ -z "$BUILD_DIR" ]; then
    echo "Erreur: Le dossier de build <build_dir> est requis."
    exit 1
fi


echo "Processing local file: $PDF_FILE_PATH"
echo "Build directory: $BUILD_DIR"

# --- Hash ---
# Calcule le SHA256 checksum du fichier local
PDF_SHA256=$(sha256sum "$PDF_FILE_PATH" | awk '{ print $1 }')
PDF_BASENAME=$(basename "$PDF_FILE_PATH") # Garde le nom du fichier pour le titre
echo "PDF SHA256: $PDF_SHA256"

# Définit le dossier de sortie basé sur le hash
OUTPUT_SUBDIR="$BUILD_DIR/$PDF_SHA256"

# Vérifie si le dossier existe déjà (pour idempotence)
if [ -d "$OUTPUT_SUBDIR" ]; then
  echo "::warning::Output directory $OUTPUT_SUBDIR already exists. Skipping processing for $PDF_FILE_PATH."
  exit 0 # Sortir avec succès car le travail est déjà fait
fi

echo "Creating output directory: $OUTPUT_SUBDIR"
mkdir -p "$OUTPUT_SUBDIR"

# --- Conversion et Compression ---
echo "Converting PDF to PNG images..."
pdftoppm "$PDF_FILE_PATH" "$OUTPUT_SUBDIR/slide" -png
if [ $? -ne 0 ]; then
    echo "::error::Failed to convert PDF to images for $PDF_SHA256 ($PDF_BASENAME)."
    exit 1 # Arrêter si la conversion échoue
fi

echo "Compressing PNG images..."
find "$OUTPUT_SUBDIR" -name 'slide-*.png' -print0 | while IFS= read -r -d $'\0' img_file; do
  pngquant "$img_file" --force --output "$img_file" --quality=65-80 --skip-if-larger
  if [ $? -ne 0 ]; then
      echo "::warning::Failed to compress $img_file."
  fi
done

# --- Génération du HTML pour ce slideshow ---
echo "Generating index.html for $PDF_SHA256..."
SLIDES_HTML=""
# Trie les images numériquement pour assurer le bon ordre
for img in $(find "$OUTPUT_SUBDIR" -name 'slide-*.png' | sort -V); do
  img_basename=$(basename "$img")
  # Ajoute une section pour chaque image
  SLIDES_HTML+="<section><img src='$img_basename' alt='Slide from PDF $PDF_BASENAME'></section>\n          "
done

# Crée le fichier index.html spécifique à ce PDF
# Notez les chemins relatifs vers les assets Reveal.js (../dist, ../plugin)
cat <<EOF > "$OUTPUT_SUBDIR/index.html"
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>$PDF_BASENAME ($PDF_SHA256)</title> <link rel="stylesheet" href="../dist/reset.css">
  <link rel="stylesheet" href="../dist/reveal.css">
  <link rel="stylesheet" href="../dist/theme/black.css" id="theme">
  <link rel="stylesheet" href="../plugin/highlight/monokai.css">
</head>
<body>
  <div class="reveal">
    <div class="slides">
      $SLIDES_HTML
    </div>
  </div>
  <script src="../dist/reveal.js"></script>
  <script src="../plugin/notes/notes.js"></script>
  <script src="../plugin/highlight/highlight.js"></script>
  <script>
    Reveal.initialize({
      hash: true,
      plugins: [ RevealHighlight, RevealNotes ]
    });
  </script>
</body>
</html>
EOF

echo "Successfully processed PDF $PDF_SHA256 from $PDF_FILE_PATH"

exit 0
