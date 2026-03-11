# system0

`system0` 是一个把 CL3 与 ysyxSoC 用 `nix + bazel` 固定化的工程，目标是：

- 稳定生成 CL3 的 SystemVerilog
- 稳定生成 Verilator 可执行文件
- 稳定运行 `cpu-tests`
- 在不破坏 CL3-only 流程的前提下，增加 SoC+CL3 集成流程

## 项目结构

- `CL3/`：CL3 原始工程（Chisel 源码、C++ 仿真代码、cpu-tests 等）
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

为了解决当前 CL3 在 SoC 模式下未完整实现 `fence/fence.i` 带来的 I/D 一致性问题，项目做了以下工程化改动：

- PSRAM DPI-C 行为模型接通  
  `ysyxSoC/perip/psram/psram.v` 已改为通过 DPI-C 调用读写函数（`psram_read/psram_write`），不再是“只连线不落地”的空模型。
- 仿真内存后端实现  
  `bazel-soc-bin/sim/dpi_mem.cpp` 实现了 `psram_read/psram_write`，把 PSRAM 访问落到仿真内存数组，并可打印关键调试日志。
- PSRAM 双地址别名映射  
  `ysyxSoC/src/SoC.scala`（以及 `bazel-soc-go/src/SoC.scala`）中，`APBPSRAM` 同时映射：
  - `0x80000000`：cacheable alias（取指地址）
  - `0x90000000`：uncached alias（搬运写入地址）
- SoC bootloader 搬运+跳转  
  `bazel-soc-test/common/soc_bootloader.S` 的流程是：
  1. 从 MROM payload 区读取测试程序  
  2. 拷贝到 `0x90000000`（绕过 DCache，确保写入真实落到 PSRAM）  
  3. `fence` 后跳转到 `0x80000000` 执行
- 测试镜像构建脚本参数化  
  `bazel-soc-test/scripts/build_cpu_test.sh` 固定了：
  - `BOOT_DST_BASE=0x90000000`
  - `BOOT_EXEC_BASE=0x80000000`
  从而形成“uncached 写、cacheable 取指”的稳定链路。
- 扩大 MROM 窗口避免大用例构建失败  
  为支持 `hello-str` 这类较大 payload，MROM 窗口从 `0x1000` 扩到 `0x100000`，并同步脚本中的 `BOOT_MROM_SIZE`。

### 代码改动定位（按当前版本行号）

- `ysyxSoC/src/SoC.scala`
  - 第 42-45 行：`lpsram` 使用双地址别名映射  
    `0x80000000`（cacheable alias）和 `0x90000000`（uncached alias）
  - 第 47 行：`lmrom` 地址窗口调整为 `0x20000000 + 0x100000`

- `ysyxSoC/perip/psram/psram.v`
  - 第 7-8 行：接入 DPI-C 接口  
    `psram_read` / `psram_write`
  - 第 10-11 行：命令常量  
    `CMD_READ = 0xEB`，`CMD_WRITE = 0x38`
  - 第 81-105 行：写通路（解析 nibble/byte，调用 `psram_write`）
  - 第 108-128 行：读通路（按地址取字节，调用 `psram_read`）
  - 第 134 行：`dio` 三态输出控制（读时驱动，其他时刻高阻）

说明：

- 该方案是当前实现下的稳定工程方案，不等价于完整 cache coherence。
- 若后续要支持自修改代码/JIT 等场景，仍建议补齐真正的 `fence.i`/cache 维护路径。

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
- `make test-run-all`：CL3-only 全量 cpu-tests
- `make build-soc-bin`：生成 SoC+CL3 可执行文件 `bazel-soc-bin/bazel-bin/soc_top`
- `make test-run-soc-all`：SoC+CL3 全量 cpu-tests

## 常见问题

- 现象：`make test-run-soc-all` 里大量 `NO STATUS`，且有单个 `FAILED TO BUILD`  
  通常是某个镜像构建失败（例如 payload 超过 MROM 窗口），导致后续测试被跳过显示 `NO STATUS`。优先查看第一个 `FAILED TO BUILD` 的 genrule 报错。
- 现象：SoC 跳转到 `0x80000000` 后取到 `0x00000000`  
  多数是“写入未真正落到可见内存”导致。当前仓库通过 `0x90000000` uncached 搬运 + `0x80000000` 执行规避该问题。

## 产物位置

- CL3 Verilog：`bazel-go/bazel-bin/cl3-verilog/`
- SoC Verilog：`bazel-soc-go/bazel-bin/ysyxSoCFull.v`
- CL3 仿真器：`bazel-bin/bazel-bin/top`
- SoC 仿真器：`bazel-soc-bin/bazel-bin/soc_top`

## 设计原则

- 保留原有 CL3-only 流程，不互相污染
- SoC 集成通过独立工作区（`bazel-soc-*`）实现
- 尽量让可变环境因素收敛到 `flake.nix` + `Makefile`
