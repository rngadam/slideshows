#!/bin/bash

# Script pour traiter les items PDF définis dans une matrice JSON.
# Prend la matrice JSON (compactée, sur une ligne) en argument 1
# et le dossier de build en argument 2.

set -e

MATRIX_JSON_COMPACT="$1"
BUILD_DIR="$2"

if [ -z "$MATRIX_JSON_COMPACT" ] || [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <compact_json_matrix> <build_dir>"
    exit 1
fi

# Vérifie si jq est disponible
if ! command -v jq &> /dev/null; then echo "::error::jq is not installed!"; exit 1; fi

echo "Received Matrix JSON: $MATRIX_JSON_COMPACT"
echo "Build Directory: $BUILD_DIR"

# Vérifie si la matrice est vide (ex: "[]")
if [[ "$MATRIX_JSON_COMPACT" == "[]" ]]; then
    echo "Matrix is empty. No PDFs to process."
    exit 0
fi

# Utilise jq pour itérer sur chaque objet du tableau JSON
echo "$MATRIX_JSON_COMPACT" | jq -c '.[]' | while IFS= read -r pdf_info_json; do
  # Extrait les informations de l'objet JSON courant
  # L'option -r enlève les guillemets des chaînes JSON
  source_type=$(echo "$pdf_info_json" | jq -r '.source_type')
  source_value=$(echo "$pdf_info_json" | jq -r '.source_value')
  pdf_hash=$(echo "$pdf_info_json" | jq -r '.pdf_hash') # Peut être utile pour logs/vérif
  pdf_basename=$(echo "$pdf_info_json" | jq -r '.pdf_basename')

  echo "--- Processing Item ---"
  echo "  Type: $source_type"
  echo "  Source: $source_value"
  echo "  Basename: $pdf_basename"
  echo "  Expected Hash: $pdf_hash"
  echo "-----------------------"

  # Déterminer les options pour le script process_pdf.sh
  source_option=""
  if [[ "$source_type" == "file" ]]; then
    source_option="-f"
    # Vérifier si le fichier existe DANS l'environnement actuel (workspace)
    if [ ! -f "$source_value" ]; then
       echo "::error::Local PDF file specified in matrix not found: '$source_value'"
       # Ne pas arrêter tout le traitement, juste sauter cet item
       continue
    fi
  elif [[ "$source_type" == "url" ]]; then
    source_option="-u"
  else
     echo "::error::Unknown source type in matrix item: $source_type"
     # Ne pas arrêter tout le traitement, juste sauter cet item
     continue
  fi

  # Appeler le script process_pdf.sh (situé dans le même dossier /app/scripts/)
  # Le chemin est relatif à l'image Docker
  /app/scripts/process_pdf.sh "$source_option" "$source_value" -b "$BUILD_DIR"

  # Vérifier le code de sortie de process_pdf.sh (optionnel mais recommandé)
  if [ $? -ne 0 ]; then
      echo "::warning::Processing failed for '$pdf_basename' (Source: $source_value)"
      # Décider si on continue ou on arrête tout (ici on continue)
  fi

  echo "--- Finished processing item '$pdf_basename' ---"

done

echo "Finished processing all items in the matrix."
