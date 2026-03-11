#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --src <test.c> --name <name> --out_dir <dir>" >&2
}

SRC=""
NAME=""
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src)
      SRC="$2"
      shift 2
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    --out_dir)
      OUT_DIR="$2"
      shift 2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$SRC" || -z "$NAME" || -z "$OUT_DIR" ]]; then
  usage
  exit 1
fi

if [[ -n "${RISCV_PREFIX:-}" ]]; then
  CROSS_COMPILE="${RISCV_PREFIX}"
elif command -v riscv64-none-elf-gcc >/dev/null 2>&1; then
  CROSS_COMPILE="riscv64-none-elf-"
elif command -v riscv-none-elf-gcc >/dev/null 2>&1; then
  CROSS_COMPILE="riscv-none-elf-"
elif command -v riscv64-unknown-linux-gnu-gcc >/dev/null 2>&1; then
  CROSS_COMPILE="riscv64-unknown-linux-gnu-"
elif command -v riscv64-linux-gnu-gcc >/dev/null 2>&1; then
  CROSS_COMPILE="riscv64-linux-gnu-"
else
  echo "No RISC-V GCC toolchain found in PATH" >&2
  exit 1
fi

AS="${CROSS_COMPILE}gcc"
CC="${CROSS_COMPILE}gcc"
LD="${CROSS_COMPILE}ld"
OBJDUMP="${CROSS_COMPILE}objdump"
OBJCOPY="${CROSS_COMPILE}objcopy"
if ! command -v "${CC}" >/dev/null 2>&1; then
  echo "Configured cross toolchain prefix is invalid: ${CROSS_COMPILE}" >&2
  exit 1
fi

HEXDUMP="${HEXDUMP_BIN:-hexdump}"
if ! command -v "${HEXDUMP}" >/dev/null 2>&1; then
  echo "hexdump tool not found: ${HEXDUMP}" >&2
  exit 1
fi

COMMON_CFLAGS="-fno-pic -march=rv32im_zicsr -mcmodel=medany -mstrict-align -mabi=ilp32"
CFLAGS="-DMAINARGS=\"\" -lm -g -O2 -Wall ${COMMON_CFLAGS} -Iinclude -Icommon/include -Icommon -fno-asynchronous-unwind-tables -fno-builtin -fno-stack-protector -Wno-main -U_FORTIFY_SOURCE -fvisibility=hidden -fdata-sections -ffunction-sections"
ASFLAGS="${COMMON_CFLAGS} -Iinclude -Icommon/include -Icommon"
LDFLAGS="-z noexecstack -melf32lriscv -T common/linker.ld --defsym=_pmem_start=0x80000000 --defsym=_entry_offset=0x0 --gc-sections -e _start"

mkdir -p "$OUT_DIR"
PREFIX="${OUT_DIR}/${NAME}"

TMPDIR="${OUT_DIR}/.tmp_${NAME}"
rm -rf "${TMPDIR}"
mkdir -p "${TMPDIR}"
trap 'rm -rf "${TMPDIR}"' EXIT

mapfile -t COMMON_SRCS < <(
  find -L common -type f \( -name '*.c' -o -name '*.S' \) ! -path 'common/soc_bootloader.S' | sort
)

OBJS=()
INDEX=0
for FILE in "$SRC" "${COMMON_SRCS[@]}"; do
  OBJ="${TMPDIR}/obj_${INDEX}.o"
  INDEX=$((INDEX + 1))
  case "$FILE" in
    *.c)
      "$CC" -std=gnu11 $CFLAGS -c -o "$OBJ" "$FILE"
      ;;
    *.S)
      "$AS" $ASFLAGS -c -o "$OBJ" "$FILE"
      ;;
    *)
      echo "Unsupported source: $FILE" >&2
      exit 1
      ;;
  esac
  OBJS+=("$OBJ")
done

"$LD" $LDFLAGS -o "${PREFIX}.elf" --start-group "${OBJS[@]}" --end-group
"$OBJDUMP" -d "${PREFIX}.elf" > "${PREFIX}.txt"
"$OBJCOPY" -S --set-section-flags .bss=alloc,contents -O binary "${PREFIX}.elf" "${PREFIX}.bin"
"$OBJCOPY" -O verilog --change-addresses -0x80000000 --verilog-data-width 4 "${PREFIX}.elf" "${PREFIX}.hex"
"$HEXDUMP" -v -e '/4 "%08x\n"' "${PREFIX}.bin" > "${PREFIX}.mem"
