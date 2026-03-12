# system0

`system0` 是一个把 CL3 与 ysyxSoC 用 `nix + bazel` 固定化的工程，目标是：

- 稳定生成 CL3 的 SystemVerilog
- 稳定生成 Verilator 可执行文件
- 稳定运行 `cpu-tests`
- 在不破坏 CL3-only 流程的前提下，增加 SoC+CL3 集成流程

## 项目结构

- `CL3/`：CL3 原始工程（Chisel 源码、C++ 仿真代码）
- `tests/`：从 CL3 拆分出的测试资产（`cpu-tests` 源码、`common`、`utils`）
- `ysyxSoC/`：ysyxSoC 原始工程（本仓只复用源码/外设/ready-to-run 资源）
- `bazel-go/`：CL3 Chisel/Scala -> SystemVerilog（产物：`cl3-verilog`）
- `bazel-bin/`：CL3 SystemVerilog -> Verilator 可执行文件（产物：`top`）
- `bazel-test/`：CL3-only 的 cpu-tests 构建与运行
- `bazel-soc-go/`：ysyxSoC Chisel/Scala -> SoC Verilog（产物：`ysyxSoCFull.v`）
- `bazel-soc-bin/`：SoC Verilog + CL3 Verilog + wrapper -> Verilator 可执行文件（产物：`soc_top`）
- `bazel-soc-test/`：SoC+CL3 的 cpu-tests 构建与运行
- `soc-integration/`：集成输入目录（由 Makefile 自动链接）
- `flake.nix`：开发环境固定（Bazel/JDK/Scala/Verilator/firtool 等）
- `Makefile`：统一入口，串起所有工作区

## 流程关系

### 1) CL3-only 三段式

1. `bazel-go` 生成 CL3 Verilog
2. `bazel-bin` 生成 CL3 仿真器 `top`
3. `bazel-test` 运行 `cpu-tests`

### 2) SoC+CL3 三段式

1. `bazel-go` 生成 CL3 Verilog
2. `bazel-soc-go` 生成 `ysyxSoCFull.v`
3. `bazel-soc-bin` 把 SoC+CL3+wrapper 编成 `soc_top`
4. `bazel-soc-test` 运行 `cpu-tests`

## SoC 启动链路关键改动

当前仓库已经切换为“先保证 SoC+CL3 可稳定编译和跑通 cpu-tests”的实现，关键点如下：

- 新增 `easy_box` 黑盒集合（用于补齐 SoC 里缺失或暂不关心的外设/桥接实现）  
  目录：`ysyxSoC/perip/easy_box/`  
  主要文件：
  - `easy_box_apb4.v`：APB4 外设桩模块 + `ChiplinkBridge` 占位实现
  - `easy_box_core_wrapper.v`：`core_wrapper` 最小可运行黑盒
  - `easy_box_nmi_psram.v`：`nmi_psram` 简化行为模型

- SoC 主内存窗口改为三别名映射  
  文件：`ysyxSoC/src/SoC.scala`  
  `sdramAddressSet` 同时包含：
  - `0x80000000`：执行别名（cacheable 视角）
  - `0x90000000`：拷贝写入别名（uncached 视角）
  - `0x20000000`：SoC 启动/直启别名（与当前测试流一致）

- SDRAM AXI 侧改为最小 DPI 行为模型（支持 burst）  
  文件：`ysyxSoC/perip/sdram/sdram_top_axi.v`  
  通过 `mem_read/mem_write` DPI 接口落地读写，替代原先复杂控制器路径，保证 Verilator 环境下可预测、可跑通。

- 仿真内存后端统一地址翻译  
  文件：`bazel-soc-bin/sim/dpi_mem.cpp`  
  统一把 `0x20000000 / 0x80000000 / 0x90000000` 访问映射到同一片 pmem 后端；并在加载镜像时同步初始化 pmem，减少“跳转后取指全 0”问题。

- SoC 测试镜像默认改为直启（不走 bootloader 搬运）  
  文件：`bazel-soc-test/scripts/build_cpu_test.sh`  
  默认：`SOC_USE_BOOTLOADER=0`，程序直接链接到 `0x20000000`，生成的 `.soc.bin` 直接用于执行。  
  兼容保留：`SOC_USE_BOOTLOADER=1` 时，仍可启用搬运模式（`0x20000000` -> `0x90000000`，再跳转 `0x80000000`）。

- bootloader 中不再依赖 `fence/fence.i`  
  文件：`bazel-soc-test/common/soc_bootloader.S`  
  目前该路径将 `fence` 位置替换为 `nop`，避免触发 CL3 当前未完整实现的 fence 语义问题。

说明：

- `ysyxSoC/perip/psram/psram.v` 在当前新流程中是最小占位模型（`dio` 高阻），cpu-tests 主路径不依赖它完成指令执行。
- 以上改动目标是“工程稳定性优先”，并不等价于完整外设功能验证或完整 cache coherence 实现。

## 快速开始

### 前置条件

- 安装 Nix（启用 flakes）
- 当前目录为仓库根目录：`/home/luyoung/system0`

### 进入固定环境

```bash
nix develop
```

进入后会自动设置：

- `JAVA_HOME` / `BAZEL_JAVA_HOME`
- `CHISEL_FIRTOOL_PATH`
- `CHISEL_FIRTOOL_PATH_SOC`

### 一次性初始化（首次或依赖变化后）

```bash
make init
make init-soc-go
```

如果 SoC 子模块未初始化：

```bash
cd ysyxSoC && make dev-init
cd ..
```

### 跑 CL3-only

```bash
make build
make build-bin
make test-run-all
```

### 跑 SoC+CL3

```bash
make build-soc-bin
make test-run-soc-all
```

## 常用目标

- `make build`：只生成 CL3 Verilog
- `make build-bin`：生成 CL3 可执行文件 `bazel-bin/bazel-bin/top`
- `make sync-tests-from-cl3`：把 `CL3/sw` 与 `CL3/utils` 的测试资产同步到根目录 `tests/`
- `make test-run-all`：CL3-only 全量 cpu-tests
- `make build-soc-bin`：生成 SoC+CL3 可执行文件 `bazel-soc-bin/bazel-bin/soc_top`
- `make test-run-soc-all`：SoC+CL3 全量 cpu-tests

## 常见问题

- 现象：`make test-run-soc-all` 里大量 `NO STATUS`，且有单个 `FAILED TO BUILD`  
  通常是某个镜像构建失败导致后续测试被跳过。  
  若你启用了 `SOC_USE_BOOTLOADER=1`，常见原因是 payload 超过 MROM 布局限制。优先查看第一个 `FAILED TO BUILD` 的 genrule 报错。
- 现象：SoC 跳转到 `0x80000000` 后取到 `0x00000000`  
  多数是“写入未真正落到可见内存”或地址别名不一致导致。  
  当前默认直启模式（`SOC_USE_BOOTLOADER=0`）直接在 `0x20000000` 运行；如需搬运链路，使用 `SOC_USE_BOOTLOADER=1` 并确保 `0x200/0x900/0x800` 三别名映射一致。

## 产物位置

- CL3 Verilog：`bazel-go/bazel-bin/cl3-verilog/`
- SoC Verilog：`bazel-soc-go/bazel-bin/ysyxSoCFull.v`
- CL3 仿真器：`bazel-bin/bazel-bin/top`
- SoC 仿真器：`bazel-soc-bin/bazel-bin/soc_top`

## 设计原则

- 保留原有 CL3-only 流程，不互相污染
- SoC 集成通过独立工作区（`bazel-soc-*`）实现
- 尽量让可变环境因素收敛到 `flake.nix` + `Makefile`
