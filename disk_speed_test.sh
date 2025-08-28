#!/bin/bash

set -e

# === CONFIGURACIÓN ===

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
RESULT_CSV="$SCRIPT_DIR/resultados_cp_test.csv"

LOCAL_SRC_DIR="$SCRIPT_DIR/test_files_src"
TARGET_MOUNT=${TARGET_MOUNT:-"/media/$USER/$(ls /media/$USER | head -n 1)"}
DEST_EXT_DIR="$TARGET_MOUNT/test_files_dst"

declare -a TESTS=(
  "100 1 1MB"
  "50 100 100MB"
  "10 1024 1GB"
  "1 10240 10GB"
)

# === FUNCIONES ===

format_speed() {
  local speed=$1
  if (( $(echo "$speed >= 1024" | bc -l) )); then
    echo "$(echo "scale=2; $speed / 1024" | bc) GB/s"
  elif (( $(echo "$speed < 1" | bc -l) )); then
    echo "$(echo "scale=2; $speed * 1024" | bc) kB/s"
  else
    echo "$speed MB/s"
  fi
}

check_or_create_files() {
  echo "📦 Verificando/generando archivos en: $LOCAL_SRC_DIR"
  mkdir -p "$LOCAL_SRC_DIR"

  for test in "${TESTS[@]}"; do
    read -r COUNT SIZE LABEL <<< "$test"
    MISSING=0
    for ((i=1; i<=COUNT; i++)); do
      FILE="$LOCAL_SRC_DIR/file_${LABEL}_${i}"
      if [ ! -f "$FILE" ]; then
        MISSING=1
        break
      fi
    done

    if [ "$MISSING" -eq 1 ]; then
      echo "🔁 Generando archivos $LABEL..."
      for ((i=1; i<=COUNT; i++)); do
        dd if=/dev/urandom of="$LOCAL_SRC_DIR/file_${LABEL}_${i}" bs=1M count=$SIZE status=none
      done
    else
      echo "✅ Archivos $LABEL ya existen."
    fi
  done
}

copy_to_external() {
  echo "📤 Copiando a $DEST_EXT_DIR"
  rm -rf "$DEST_EXT_DIR"
  mkdir -p "$DEST_EXT_DIR"

  for test in "${TESTS[@]}"; do
    read -r COUNT SIZE LABEL <<< "$test"
    echo "✍ Escribiendo $LABEL..."
    START=$(date +%s.%N)
    cp "$LOCAL_SRC_DIR"/file_${LABEL}_* "$DEST_EXT_DIR/"
    sync
    END=$(date +%s.%N)
    TIME=$(echo "$END - $START" | bc)
    SIZE_MB=$(echo "$COUNT * $SIZE" | bc)
    SPEED=$(echo "scale=2; $SIZE_MB / $TIME" | bc)
    eval "WRITE_SPEED_$LABEL=$SPEED"
  done
}

copy_from_external_to_null() {
  echo "📥 Leyendo archivos desde $DEST_EXT_DIR → /dev/null"

  for test in "${TESTS[@]}"; do
    read -r COUNT SIZE LABEL <<< "$test"
    echo "📖 Leyendo $LABEL..."
    START=$(date +%s.%N)

    for file in "$DEST_EXT_DIR"/file_${LABEL}_*; do
      cp "$file" /dev/null
    done

    sync
    END=$(date +%s.%N)
    TIME=$(echo "$END - $START" | bc)
    SIZE_MB=$(echo "$COUNT * $SIZE" | bc)
    SPEED=$(echo "scale=2; $SIZE_MB / $TIME" | bc)
    eval "READ_SPEED_$LABEL=$SPEED"
  done
}

write_csv() {
  echo "📝 Guardando resultados en: $RESULT_CSV"

  if [ ! -f "$RESULT_CSV" ]; then
    echo -n "Fecha" > "$RESULT_CSV"
    for test in "${TESTS[@]}"; do
      read -r _ _ LABEL <<< "$test"
      echo -n ",Write_${LABEL}_MBps (MB/s),Read_${LABEL}_MBps (MB/s)" >> "$RESULT_CSV"
    done
    echo ",Duración_total (s)" >> "$RESULT_CSV"
  fi

  echo -n "$(date '+%Y-%m-%d %H:%M:%S')" >> "$RESULT_CSV"
  for test in "${TESTS[@]}"; do
    read -r _ _ LABEL <<< "$test"
    W=$(eval "echo \$WRITE_SPEED_$LABEL")
    R=$(eval "echo \$READ_SPEED_$LABEL")
    echo -n ",$(format_speed "$W"),$(format_speed "$R")" >> "$RESULT_CSV"
  done
  echo ",$TOTAL_DURATION" >> "$RESULT_CSV"
}

# === EJECUCIÓN ===

echo "🚀 Iniciando pruebas de velocidad de disco..."
echo "📂 Disco externo detectado: $TARGET_MOUNT"

if [ ! -d "$TARGET_MOUNT" ]; then
  echo "❌ ERROR: No se encontró el punto de montaje $TARGET_MOUNT"
  exit 1
fi

START_ALL=$(date +%s.%N)

check_or_create_files
copy_to_external
copy_from_external_to_null

END_ALL=$(date +%s.%N)
TOTAL_DURATION=$(echo "$END_ALL - $START_ALL" | bc)

write_csv

echo "✅ Pruebas completadas. Tiempo total: $TOTAL_DURATION segundos."
