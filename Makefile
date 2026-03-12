.PHONY: \
		check-locked-deps \
		check-cl3-dpic-mode \
		bump-cl3 bump-ysyxsoc \
		check-test-assets \
		setup-go init init-go build build-go clean clean-go \
		setup-bin build-bin clean-bin \
		setup-test build-test test-run-add test-run-all clean-test \
	setup-soc-go-src init-soc-go \
	setup-soc-ysyx check-soc-wrapper setup-soc-int \
	build-soc-bin setup-soc-test build-soc-test \
	test-run-soc-add test-run-soc-all clean-soc \
	flow shell package hashcheck

SOC_INT_DIR ?= soc-integration
SOC_CPU_WRAPPER ?= CL3/soc/ysyx_00000000.sv
SOC_GO_WS ?= bazel-soc-go
SOC_GO_TARGET ?= //:ysyxsoc-verilog
SOC_SOC_VERILOG ?= bazel-soc-go/bazel-bin/ysyxSoCFull.v
SOC_BIN_WS ?= bazel-soc-bin
SOC_BIN_TARGET ?= //:soc_top_bin
SOC_SIM_BIN ?= soc_top
SOC_TEST_WS ?= bazel-soc-test
BAZEL_USER_ROOT ?= $(abspath $(CURDIR))/out/bazel_user_root
BAZEL ?= bazel --nohome_rc --nosystem_rc --output_user_root=$(BAZEL_USER_ROOT)
BAZEL_ENV_FLAGS ?= --action_env=PATH --host_action_env=PATH \
	--action_env=JAVA_HOME --host_action_env=JAVA_HOME \
	--action_env=BAZEL_JAVA_HOME --host_action_env=BAZEL_JAVA_HOME \
	--action_env=CHISEL_FIRTOOL_PATH --host_action_env=CHISEL_FIRTOOL_PATH \
	--action_env=COURSIER_CACHE --host_action_env=COURSIER_CACHE \
	--action_env=NIX_CFLAGS_COMPILE --host_action_env=NIX_CFLAGS_COMPILE \
	--action_env=NIX_LDFLAGS --host_action_env=NIX_LDFLAGS
ALLOW_DIRTY ?= 0
TESTS_DIR ?= tests
TESTS_CPU_TESTS_DIR ?= $(TESTS_DIR)/cpu-tests/tests
TESTS_CPU_INCLUDE_DIR ?= $(TESTS_DIR)/cpu-tests/include
TESTS_COMMON_DIR ?= $(TESTS_DIR)/common
TESTS_UTILS_DIR ?= $(TESTS_DIR)/utils
CL3_CONFIG ?= CL3/cl3/src/scala/CL3Config.scala
CHISEL_FIRTOOL_PATH ?= $(patsubst %/,%,$(dir $(shell command -v firtool 2>/dev/null)))
CHISEL_FIRTOOL_PATH_SOC ?= $(CHISEL_FIRTOOL_PATH)
COURSIER_CACHE ?= /tmp/coursier-$(shell id -un)
PACKAGE_NAME ?= system0-portable.tar.gz
PACKAGE_OUT_DIR ?= $(abspath $(CURDIR))/packages
PACKAGE_OUT ?= $(PACKAGE_OUT_DIR)/$(PACKAGE_NAME)
PACKAGE_SRC_DIR ?= $(abspath $(CURDIR))
HASH_CL3_VERILOG_DIR ?= bazel-go/bazel-bin/cl3-verilog
HASH_CL3_TOP_BIN ?= bazel-bin/bazel-bin/top
HASH_SOC_VERILOG ?= bazel-soc-go/bazel-bin/ysyxSoCFull.v
HASH_SOC_TOP_BIN ?= bazel-soc-bin/bazel-bin/$(SOC_SIM_BIN)

export CHISEL_FIRTOOL_PATH
export CHISEL_FIRTOOL_PATH_SOC
export COURSIER_CACHE

check-locked-deps:
	@ALLOW_DIRTY=$(ALLOW_DIRTY) ./scripts/check_locked_deps.sh

bump-cl3:
	@test -n "$(REF)" || \
	( \
		echo "usage: make bump-cl3 REF=<commit|tag|branch>"; \
		exit 2; \
	)
	@set -euo pipefail; \
	git -C CL3 fetch --tags origin; \
	git -C CL3 checkout "$(REF)"; \
	new_rev=$$(git -C CL3 rev-parse --short HEAD); \
	git add CL3 .gitmodules; \
	if git diff --cached --quiet -- CL3 .gitmodules; then \
		echo "[deps] CL3 is already at the requested revision ($$new_rev)"; \
		exit 2; \
	fi; \
	git commit -m "Bump CL3 to $$new_rev"; \
	echo "[deps] CL3 bumped to $$new_rev"

bump-ysyxsoc:
	@test -n "$(REF)" || \
	( \
		echo "usage: make bump-ysyxsoc REF=<commit|tag|branch>"; \
		exit 2; \
	)
	@set -euo pipefail; \
	git -C ysyxSoC fetch --tags origin; \
	git -C ysyxSoC checkout "$(REF)"; \
	new_rev=$$(git -C ysyxSoC rev-parse --short HEAD); \
	git add ysyxSoC .gitmodules; \
	if git diff --cached --quiet -- ysyxSoC .gitmodules; then \
		echo "[deps] ysyxSoC is already at the requested revision ($$new_rev)"; \
		exit 2; \
	fi; \
	git commit -m "Bump ysyxSoC to $$new_rev"; \
	echo "[deps] ysyxSoC bumped to $$new_rev"

check-test-assets:
	@test -d "$(TESTS_CPU_TESTS_DIR)" || \
	( \
		echo "[tests] missing $(TESTS_CPU_TESTS_DIR)"; \
		echo "[tests] restore tracked assets under $(TESTS_DIR)/"; \
		exit 2; \
	)
	@test -d "$(TESTS_CPU_INCLUDE_DIR)" || \
	( \
		echo "[tests] missing $(TESTS_CPU_INCLUDE_DIR)"; \
		echo "[tests] restore tracked assets under $(TESTS_DIR)/"; \
		exit 2; \
	)
	@test -d "$(TESTS_COMMON_DIR)" || \
	( \
		echo "[tests] missing $(TESTS_COMMON_DIR)"; \
		echo "[tests] restore tracked assets under $(TESTS_DIR)/"; \
		exit 2; \
	)
	@test -f "$(TESTS_UTILS_DIR)/riscv32-spike-so" || \
	( \
		echo "[tests] missing $(TESTS_UTILS_DIR)/riscv32-spike-so"; \
		echo "[tests] restore tracked assets under $(TESTS_DIR)/"; \
		exit 2; \
	)

check-cl3-dpic-mode:
	@grep -Eq '^[[:space:]]*val[[:space:]]+SimMemOption[[:space:]]*=[[:space:]]*"DPI-C"' "$(CL3_CONFIG)" || \
	( \
		echo "[mode] CL3 test-run requires DPI-C mode"; \
		echo "[mode] please edit $(CL3_CONFIG):"; \
		echo "       val SimMemOption = \"DPI-C\""; \
		exit 2; \
	)

# ----------------------------------------------------------------------
# bazel-go: Chisel/Scala -> SystemVerilog
# ----------------------------------------------------------------------
setup-go: check-locked-deps
	cd bazel-go && ln -sfn ../CL3/cl3/src/scala src
	cd bazel-go && ln -sfn ../CL3/cl3/resources resources

init: init-go

init-go: setup-go
	cd bazel-go && $(BAZEL) run $(BAZEL_ENV_FLAGS) @maven//:pin

build: build-go

build-go: setup-go
	cd bazel-go && $(BAZEL) build $(BAZEL_ENV_FLAGS) //:cl3-verilog

clean-go:
	cd bazel-go && $(BAZEL) clean

# ----------------------------------------------------------------------
# bazel-bin: SystemVerilog -> Verilator executable (top)
# ----------------------------------------------------------------------
setup-bin: build-go
	cd bazel-bin && ln -sfn ../bazel-go/bazel-bin/cl3-verilog rtl
	cd bazel-bin && ln -sfn ../CL3/soc soc
	cd bazel-bin && ln -sfn ../CL3/cl3/src/cc cc

build-bin: setup-bin
	cd bazel-bin && $(BAZEL) build $(BAZEL_ENV_FLAGS) //:top_bin

clean-bin:
	cd bazel-bin && $(BAZEL) clean

# ----------------------------------------------------------------------
# bazel-test: cpu-tests image build and test execution
# ----------------------------------------------------------------------
setup-test: check-cl3-dpic-mode build-bin check-test-assets
	rm -rf bazel-test/tests bazel-test/include bazel-test/common bazel-test/utils
	ln -sfn ../$(TESTS_CPU_TESTS_DIR) bazel-test/tests
	ln -sfn ../$(TESTS_CPU_INCLUDE_DIR) bazel-test/include
	ln -sfn ../$(TESTS_COMMON_DIR) bazel-test/common
	ln -sfn ../$(TESTS_UTILS_DIR) bazel-test/utils
	cd bazel-test && mkdir -p sim && ln -sfn ../../bazel-bin/bazel-bin/top sim/top

build-test: setup-test
	cd bazel-test && $(BAZEL) build $(BAZEL_ENV_FLAGS) //:cpu_tests_images

# Run one representative test first; add more targets as needed.
test-run-add: setup-test
	cd bazel-test && $(BAZEL) test $(BAZEL_ENV_FLAGS) //:add_run

test-run-all: setup-test
	cd bazel-test && $(BAZEL) test $(BAZEL_ENV_FLAGS) //:cpu_tests_suite

clean-test:
	cd bazel-test && $(BAZEL) clean

# ----------------------------------------------------------------------
# Plan-1 integration: ysyxSoC + CL3 (single executable)
# ----------------------------------------------------------------------
setup-soc-go-src: check-locked-deps
	@test -d "$(SOC_GO_WS)" || \
	( \
		echo "[soc] missing workspace: $(SOC_GO_WS)"; \
		echo "[soc] create $(SOC_GO_WS) for Bazel-based ysyxSoC Chisel->Verilog generation"; \
		exit 2; \
	)
	cd $(SOC_GO_WS) && ln -sfn ../ysyxSoC/src src
	cd $(SOC_GO_WS) && ln -sfn ../ysyxSoC/rocket-chip rocket-chip

init-soc-go: setup-soc-go-src
	cd $(SOC_GO_WS) && test -f maven_install.json || cp ../bazel-go/maven_install.json maven_install.json
	cd $(SOC_GO_WS) && $(BAZEL) run $(BAZEL_ENV_FLAGS) @maven//:pin

setup-soc-ysyx: setup-soc-go-src
	@test -f ysyxSoC/rocket-chip/common.sc || \
	( \
		echo "[soc] ysyxSoC submodules are not initialized"; \
		echo "[soc] run: cd ysyxSoC && make dev-init"; \
		exit 2; \
	)
	@test -f ysyxSoC/rocket-chip/dependencies/chisel/build.sc || \
	( \
		echo "[soc] ysyxSoC submodules are incomplete"; \
		echo "[soc] run again: cd ysyxSoC && make dev-init"; \
		exit 2; \
	)
	@test -f ysyxSoC/rocket-chip/dependencies/diplomacy/common.sc || \
	( \
		echo "[soc] ysyxSoC submodules are incomplete"; \
		echo "[soc] run again: cd ysyxSoC && make dev-init"; \
		exit 2; \
	)
	@test -f "$(SOC_GO_WS)/maven_install.json" || \
	( \
		echo "[soc] missing $(SOC_GO_WS)/maven_install.json"; \
		echo "[soc] run: make init-soc-go"; \
		exit 2; \
	)
	cd $(SOC_GO_WS) && CHISEL_FIRTOOL_PATH=$${CHISEL_FIRTOOL_PATH_SOC:-$$CHISEL_FIRTOOL_PATH} $(BAZEL) build $(BAZEL_ENV_FLAGS) $(SOC_GO_TARGET)

check-soc-wrapper:
	@test -f "$(SOC_CPU_WRAPPER)" || \
	( \
		echo "[soc] missing CPU wrapper: $(SOC_CPU_WRAPPER)"; \
		echo "[soc] create wrapper module 'ysyx_00000000' to adapt CL3Top <-> ysyxSoC CPU interface first"; \
		exit 2; \
	)

setup-soc-int: build-go setup-soc-ysyx check-soc-wrapper
	mkdir -p $(SOC_INT_DIR)
	ln -sfn ../bazel-go/bazel-bin/cl3-verilog $(SOC_INT_DIR)/cl3-verilog
	ln -sfn ../$(SOC_SOC_VERILOG) $(SOC_INT_DIR)/ysyxSoCFull.v
	ln -sfn ../$(SOC_CPU_WRAPPER) $(SOC_INT_DIR)/ysyx_00000000.sv
	ln -sfn ../ysyxSoC/perip $(SOC_INT_DIR)/perip
	@echo "[soc] integration inputs ready in $(SOC_INT_DIR)"

build-soc-bin: setup-soc-int
	@test -d "$(SOC_BIN_WS)" || \
	( \
		echo "[soc] missing workspace: $(SOC_BIN_WS)"; \
		echo "[soc] create $(SOC_BIN_WS) with a Bazel target that compiles SoC+CL3 into one Verilator executable"; \
		exit 2; \
	)
	@test -f "$(SOC_BIN_WS)/BUILD" || \
	( \
		echo "[soc] missing $(SOC_BIN_WS)/BUILD"; \
		exit 2; \
	)
	cd $(SOC_BIN_WS) && ln -sfn ../$(SOC_INT_DIR) soc-integration
	cd $(SOC_BIN_WS) && $(BAZEL) build $(BAZEL_ENV_FLAGS) $(SOC_BIN_TARGET)

setup-soc-test: build-soc-bin check-test-assets
	@test -d "$(SOC_TEST_WS)" || \
	( \
		echo "[soc] missing workspace: $(SOC_TEST_WS)"; \
		echo "[soc] create $(SOC_TEST_WS) (can reuse bazel-test layout)"; \
		exit 2; \
	)
	rm -rf $(SOC_TEST_WS)/tests $(SOC_TEST_WS)/include $(SOC_TEST_WS)/common
	ln -sfn ../$(TESTS_CPU_TESTS_DIR) $(SOC_TEST_WS)/tests
	ln -sfn ../$(TESTS_CPU_INCLUDE_DIR) $(SOC_TEST_WS)/include
	ln -sfn ../$(TESTS_COMMON_DIR) $(SOC_TEST_WS)/common
	cd $(SOC_TEST_WS) && ln -sfn ../ysyxSoC/ready-to-run/D-stage soc_boot
	cd $(SOC_TEST_WS) && mkdir -p sim && ln -sfn ../../$(SOC_BIN_WS)/bazel-bin/$(SOC_SIM_BIN) sim/top

build-soc-test: setup-soc-test
	cd $(SOC_TEST_WS) && $(BAZEL) build $(BAZEL_ENV_FLAGS) //:cpu_tests_images

test-run-soc-add: setup-soc-test
	cd $(SOC_TEST_WS) && $(BAZEL) test $(BAZEL_ENV_FLAGS) //:add_run

test-run-soc-all: setup-soc-test
	cd $(SOC_TEST_WS) && $(BAZEL) test $(BAZEL_ENV_FLAGS) //:cpu_tests_suite

clean-soc:
	@if [ -d "$(SOC_BIN_WS)" ]; then cd $(SOC_BIN_WS) && $(BAZEL) clean; fi
	@if [ -d "$(SOC_TEST_WS)" ]; then cd $(SOC_TEST_WS) && $(BAZEL) clean; fi

flow: build-go build-bin build-test

clean: clean-go clean-bin clean-test

shell:
	nix develop

package:
	@set -eu; \
	src_dir="$(PACKAGE_SRC_DIR)"; \
	src_parent="$$(dirname "$$src_dir")"; \
	src_name="$$(basename "$$src_dir")"; \
	out_path="$(abspath $(PACKAGE_OUT))"; \
	mkdir -p "$$(dirname "$$out_path")"; \
	echo "[package] creating $$out_path"; \
	cd "$$src_parent" && tar \
		--exclude-vcs \
		--exclude="$$src_name/packages" \
		--exclude="$$src_name/bazel-soc-bin/out" \
		--exclude="$$src_name/bazel-soc-test/out" \
		--exclude="$$src_name/out" \
		--exclude="$$src_name/.metals" \
		--exclude="$$src_name/bazel-*/bazel-*" \
		-czf "$$out_path" "$$src_name"; \
	ls -lh "$$out_path"

hashcheck:
	@set -eu; \
	if command -v sha256sum >/dev/null 2>&1; then \
		hash_cmd='sha256sum'; \
	elif command -v shasum >/dev/null 2>&1; then \
		hash_cmd='shasum -a 256'; \
	else \
		echo "[hash] ERROR: neither sha256sum nor shasum found"; \
		exit 2; \
	fi; \
	hash_file() { \
		label="$$1"; \
		path="$$2"; \
		if [ -f "$$path" ]; then \
			sum=$$(eval "$$hash_cmd \"$$path\"" | awk '{print $$1}'); \
			printf '[hash] %-18s %s  %s\n' "$$label" "$$sum" "$$path"; \
		else \
			printf '[hash] %-18s MISSING  %s\n' "$$label" "$$path"; \
		fi; \
	}; \
	hash_dir() { \
		label="$$1"; \
		path="$$2"; \
		if [ -d "$$path" ]; then \
			sum=$$(cd "$$path" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do eval "$$hash_cmd \"$$f\""; done | eval "$$hash_cmd" | awk '{print $$1}'); \
			count=$$(find "$$path" -type f | wc -l | tr -d ' '); \
			printf '[hash] %-18s %s  %s (files=%s)\n' "$$label" "$$sum" "$$path" "$$count"; \
		else \
			printf '[hash] %-18s MISSING  %s\n' "$$label" "$$path"; \
		fi; \
	}; \
	echo "[hash] key build artifact hashes"; \
	hash_dir "cl3-verilog-dir" "$(HASH_CL3_VERILOG_DIR)"; \
	hash_file "cl3-top-bin" "$(HASH_CL3_TOP_BIN)"; \
	hash_file "soc-verilog" "$(HASH_SOC_VERILOG)"; \
	hash_file "soc-top-bin" "$(HASH_SOC_TOP_BIN)"
