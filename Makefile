.PHONY: \
	setup setup-go init init-go build build-go clean clean-go \
	setup-bin build-bin clean-bin \
	setup-test build-test test-run-add test-run-all clean-test \
	setup-soc-go-src init-soc-go \
	setup-soc-go setup-soc-ysyx check-soc-wrapper setup-soc-int \
	build-soc-bin setup-soc-test build-soc-test \
	test-run-soc-add test-run-soc-all clean-soc \
	flow shell

SOC_INT_DIR ?= soc-integration
SOC_CPU_WRAPPER ?= CL3/soc/ysyx_00000000.sv
SOC_GO_WS ?= bazel-soc-go
SOC_GO_TARGET ?= //:ysyxsoc-verilog
SOC_SOC_VERILOG ?= bazel-soc-go/bazel-bin/ysyxSoCFull.v
SOC_BIN_WS ?= bazel-soc-bin
SOC_BIN_TARGET ?= //:soc_top_bin
SOC_SIM_BIN ?= soc_top
SOC_TEST_WS ?= bazel-soc-test

# ----------------------------------------------------------------------
# bazel-go: Chisel/Scala -> SystemVerilog
# ----------------------------------------------------------------------
setup: setup-go

setup-go:
	cd bazel-go && ln -sfn ../CL3/cl3/src/scala src
	cd bazel-go && ln -sfn ../CL3/cl3/resources resources

init: init-go

init-go: setup-go
	cd bazel-go && bazel run @maven//:pin

build: build-go

build-go: setup-go
	cd bazel-go && bazel build //:cl3-verilog

clean-go:
	cd bazel-go && bazel clean

# ----------------------------------------------------------------------
# bazel-bin: SystemVerilog -> Verilator executable (top)
# ----------------------------------------------------------------------
setup-bin: build-go
	cd bazel-bin && ln -sfn ../bazel-go/bazel-bin/cl3-verilog rtl
	cd bazel-bin && ln -sfn ../CL3/soc soc
	cd bazel-bin && ln -sfn ../CL3/cl3/src/cc cc

build-bin: setup-bin
	cd bazel-bin && bazel build //:top_bin

clean-bin:
	cd bazel-bin && bazel clean

# ----------------------------------------------------------------------
# bazel-test: cpu-tests image build and test execution
# ----------------------------------------------------------------------
setup-test: build-bin
	cd bazel-test && ln -sfn ../CL3/sw/cpu-tests/tests tests
	cd bazel-test && ln -sfn ../CL3/sw/cpu-tests/include include
	cd bazel-test && ln -sfn ../CL3/sw/common common
	cd bazel-test && ln -sfn ../CL3/utils utils
	cd bazel-test && mkdir -p sim && ln -sfn ../../bazel-bin/bazel-bin/top sim/top

build-test: setup-test
	cd bazel-test && bazel build //:cpu_tests_images

# Run one representative test first; add more targets as needed.
test-run-add: setup-test
	cd bazel-test && bazel test //:add_run

test-run-all: setup-test
	cd bazel-test && bazel test //:cpu_tests_suite

clean-test:
	cd bazel-test && bazel clean

# ----------------------------------------------------------------------
# Plan-1 integration: ysyxSoC + CL3 (single executable)
# ----------------------------------------------------------------------
setup-soc-go-src:
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
	cd $(SOC_GO_WS) && bazel run @maven//:pin

setup-soc-go: build-go

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
	cd $(SOC_GO_WS) && CHISEL_FIRTOOL_PATH=$${CHISEL_FIRTOOL_PATH_SOC:-$$CHISEL_FIRTOOL_PATH} bazel build $(SOC_GO_TARGET)

check-soc-wrapper:
	@test -f "$(SOC_CPU_WRAPPER)" || \
	( \
		echo "[soc] missing CPU wrapper: $(SOC_CPU_WRAPPER)"; \
		echo "[soc] create wrapper module 'ysyx_00000000' to adapt CL3Top <-> ysyxSoC CPU interface first"; \
		exit 2; \
	)

setup-soc-int: setup-soc-go setup-soc-ysyx check-soc-wrapper
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
	cd $(SOC_BIN_WS) && bazel build $(SOC_BIN_TARGET)

setup-soc-test: build-soc-bin
	@test -d "$(SOC_TEST_WS)" || \
	( \
		echo "[soc] missing workspace: $(SOC_TEST_WS)"; \
		echo "[soc] create $(SOC_TEST_WS) (can reuse bazel-test layout)"; \
		exit 2; \
	)
	cd $(SOC_TEST_WS) && ln -sfn ../CL3/sw/cpu-tests/tests tests
	cd $(SOC_TEST_WS) && ln -sfn ../CL3/sw/cpu-tests/include include
	cd $(SOC_TEST_WS) && ln -sfn ../CL3/sw/common common
	cd $(SOC_TEST_WS) && ln -sfn ../ysyxSoC/ready-to-run/D-stage soc_boot
	cd $(SOC_TEST_WS) && mkdir -p sim && ln -sfn ../../$(SOC_BIN_WS)/bazel-bin/$(SOC_SIM_BIN) sim/top

build-soc-test: setup-soc-test
	cd $(SOC_TEST_WS) && bazel build //:cpu_tests_images

test-run-soc-add: setup-soc-test
	cd $(SOC_TEST_WS) && bazel test //:add_run

test-run-soc-all: setup-soc-test
	cd $(SOC_TEST_WS) && bazel test //:cpu_tests_suite

clean-soc:
	@if [ -d "$(SOC_BIN_WS)" ]; then cd $(SOC_BIN_WS) && bazel clean; fi
	@if [ -d "$(SOC_TEST_WS)" ]; then cd $(SOC_TEST_WS) && bazel clean; fi

flow: build-go build-bin build-test

clean: clean-go clean-bin clean-test

shell:
	nix develop
