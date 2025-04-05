#!/bin/bash

# Script pour préparer la matrice JSON des PDFs à traiter.
# Lit les informations depuis les variables d'environnement GITHUB_EVENT_NAME et INPUT_PDFURL.
# Sortie: Exporte 'matrix' (JSON compacté) et 'found_pdfs' (true/false).

set -e

matrix_json="[]" # Initialise un tableau JSON vide
found_pdfs="false"

# Vérifie si jq est disponible
if ! command -v jq &> /dev/null; then echo "::error::jq is not installed!"; exit 1; fi

echo "Event Name: ${GITHUB_EVENT_NAME}"
echo "Input PDF URL: ${INPUT_PDFURL:-<empty>}" # INPUT_PDFURL vient de l'env du workflow

# --- Cas 1: URL fournie via workflow_dispatch ---
if [[ "${GITHUB_EVENT_NAME}" == "workflow_dispatch" && -n "${INPUT_PDFURL}" ]]; then
  echo "Mode: Processing URL"
  PDF_URL="${INPUT_PDFURL}"
  TMP_DIR=$(mktemp -d)
  PDF_TMP_PATH="$TMP_DIR/downloaded.pdf"
  trap 'rm -rf "$TMP_DIR"' EXIT # Nettoyage auto

  echo "Downloading PDF from URL: $PDF_URL"
  # Utiliser des guillemets autour du chemin temporaire
  if curl -L -o "$PDF_TMP_PATH" -f "$PDF_URL"; then
    # Utiliser des guillemets pour sha256sum
    PDF_HASH=$(sha256sum "$PDF_TMP_PATH" | awk '{ print $1 }')
    URL_FILENAME=$(basename "$PDF_URL" | sed 's/\?.*//')
    if [[ "$URL_FILENAME" == *.pdf ]]; then PDF_BASENAME="$URL_FILENAME"; else PDF_BASENAME="$PDF_HASH.pdf"; fi

    echo "Download successful. Hash: $PDF_HASH, Basename: $PDF_BASENAME"
    # Utilise jq pour construire le JSON de manière sûre
    matrix_json=$(echo '[]' | jq \
      --arg type "url" \
      --arg value "$PDF_URL" \
      --arg hash "$PDF_HASH" \
      --arg name "$PDF_BASENAME" \
      '. + [{source_type: $type, source_value: $value, pdf_hash: $hash, pdf_basename: $name}]')
    found_pdfs="true"
    rm -rf "$TMP_DIR" # Nettoyage explicite (le trap le fait aussi)
    trap - EXIT # Annule le trap car nettoyage fait
  else
    echo "::error::Failed to download PDF from URL: $PDF_URL"
    # matrix_json reste "[]", found_pdfs reste "false"
  fi

# --- Cas 2: Fichiers locaux (sur push) ---
elif [[ "${GITHUB_EVENT_NAME}" == "push" ]]; then
   echo "Mode: Processing local PDF files from pdf/ directory..."
   PDF_DIR="pdf" # Relatif à /github/workspace
   temp_json="[]"
   shopt -s nullglob # Nécessite bash
   files=("$PDF_DIR"/*.pdf) # Expansion dans le workspace
   shopt -u nullglob # Désactiver après usage

   if [ ${#files[@]} -gt 0 ]; then
      echo "Found ${#files[@]} PDF file(s)."
      found_pdfs="true"
      for pdf_file in "${files[@]}"; do
         echo "  - Found: $pdf_file"
         # Utiliser des guillemets pour sha256sum
         PDF_HASH=$(sha256sum "$pdf_file" | awk '{ print $1 }')
         PDF_BASENAME=$(basename "$pdf_file")
         # Utilise jq pour ajouter à la liste temporaire
         temp_json=$(echo "$temp_json" | jq \
            --arg type "file" \
            --arg value "$pdf_file" \
            --arg hash "$PDF_HASH" \
            --arg name "$PDF_BASENAME" \
           '. + [{source_type: $type, source_value: $value, pdf_hash: $hash, pdf_basename: $name}]')
      done
      matrix_json="$temp_json"
   else
      echo "No PDF files found in $PDF_DIR."
      # matrix_json reste "[]", found_pdfs reste "false"
   fi
else
   # Cas où déclenché par workflow_dispatch mais SANS URL (ou autre event non géré)
   echo "Mode: No PDF source specified (no URL, not a push event)."
   # matrix_json reste "[]", found_pdfs reste "false"
fi

# --- Exportation vers la sortie standard pour capture par le workflow ---
# Compacte le JSON en une seule ligne avant l'exportation
compact_matrix_json=$(echo "${matrix_json}" | jq -c .)

echo "matrix=${compact_matrix_json}" >> $GITHUB_OUTPUT
echo "found_pdfs=${found_pdfs}" >> $GITHUB_OUTPUT

# Débogage (visible dans les logs du workflow)
echo "Debug: Generated Matrix JSON (compact): ${compact_matrix_json}"

