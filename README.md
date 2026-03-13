# system0

`system0` 是一个把 CL3 与 ysyxSoC 用 `nix + bazel` 固定化的工程，目标是：

- 稳定生成 CL3 的 SystemVerilog
- 稳定生成 Verilator 可执行文件
- 稳定运行 `cpu-tests`
- 在不破坏 CL3-only 流程的前提下，增加 SoC+CL3 集成流程

它的核心意图不是“重写 CL3/ysyxSoC”，而是提供一个可复现、可迁移、可审计的集成外壳：

- 把工具链版本（JDK/Bazel/Verilator/firtool/Scala）尽量固定在 `nix develop` 环境内
- 把源码版本（CL3/ysyxSoC）固定为主仓记录的子模块指针 commit
- 把构建流程拆成独立工作区（`bazel-go` / `bazel-bin` / `bazel-test` / `bazel-soc-*`），避免相互污染
- 把测试资产从 CL3 中解耦到 `tests/`，让 CL3 逐步只保留 RTL 相关内容

因此，`system0` 的定位是“稳定集成与验证平台”：
同一份仓库在另一台机器上进入 `nix develop` 后，应能以相同流程复现构建与测试结果。

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

### 首次 clone（新机器）

推荐直接递归拉取子模块：

```bash
git clone --recurse-submodules git@github.com:Luyoung0001/system0_temp.git
cd system0
git submodule sync --recursive
git submodule update --init --recursive --checkout
```

如果你已经 clone 过（但没带 `--recurse-submodules`），在仓库根目录执行：

```bash
git submodule sync --recursive
git submodule update --init --recursive --checkout
```

说明：在 `system0` 流程里，通常不需要手动执行 `cd ysyxSoC && make dev-init`。

### 进入固定环境

```bash
nix develop
```

进入后会自动设置：

- `JAVA_HOME` / `BAZEL_JAVA_HOME`
- `CHISEL_FIRTOOL_PATH`（CL3 流程使用，固定为 firtool `1.133.0`）
- `CHISEL_FIRTOOL_PATH_SOC`（SoC 流程使用，固定为 firtool `1.62.1`）

### 一次性初始化（首次或依赖变化后）

```bash
make init
make init-soc-go
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
- `tests/`：测试资产目录（已在本仓维护，不再从 `CL3/sw` 同步）
- `make test-run-all`：CL3-only 全量 cpu-tests
- `make build-soc-bin`：生成 SoC+CL3 可执行文件 `bazel-soc-bin/bazel-bin/soc_top`
- `make test-run-soc-all`：SoC+CL3 全量 cpu-tests

## 子模块版本锁定与升级

本仓把 `CL3` / `ysyxSoC` 当作子模块管理，`system0` 主仓会记录它们的“期望 commit”（gitlink）。

### 日常检查

- 执行 `make test-run-all` 或 `make test-run-soc-all` 前，会自动做 locked dependency check。
- 输出里的：
  - `expected`：主仓当前提交里记录的子模块 commit
  - `actual`：你本地子模块当前 HEAD commit
- 两者不一致会报错；子模块 dirty 也会报错（可用 `ALLOW_DIRTY=1` 临时放行本地开发）。

### 正式升级子模块（推荐流程）

1. 在子模块里完成修改并提交（先 `CL3/` 或 `ysyxSoC/` 内部 commit）。
2. 回到主仓执行：
   - `make bump-cl3 REF=<commit|tag|branch>`
   - `make bump-ysyxsoc REF=<commit|tag|branch>`
3. 这两个目标会自动：
   - `checkout` 到目标版本
   - 在主仓更新子模块指针
   - 创建一条主仓提交（`Bump CL3 to <sha>` / `Bump ysyxSoC to <sha>`）

建议 `REF` 使用完整 commit SHA，以保证跨机器可复现。

## 多人协作分支规范（三仓统一）

目标：多人并行开发时，保证 `system0` 可复现、可回滚，且子模块指针始终可追溯。

### 分支职责

- `system0/main`（或 `master`）：稳定分支，只接收通过验证的集成结果。
- `system0/dev`：集成分支，日常协作主分支。
- `system0/feature/<topic>`：个人功能分支，从 `dev` 切出，完成后合入 `dev`。
- `CL3` / `ysyxSoC`：只有在需要修改对应仓库代码时，才创建 `dev`/`feature` 分支；不改代码时无需额外分支。

### 场景 A：只改 system0（Makefile/README/Bazel glue）

1. `git checkout -b feature/<topic> origin/dev`（或本地 `dev`）。
2. 在 `nix develop` 下完成构建与测试。
3. 提交到 `system0/feature/<topic>`，发 PR 合入 `system0/dev`。
4. 阶段稳定后，再把 `system0/dev` 合入 `main`。

此场景下通常不需要改 `CL3` / `ysyxSoC` 分支，只保留当前子模块锁定 commit。

### 场景 B：需要改 CL3 或 ysyxSoC

1. 在目标子仓（`CL3` 或 `ysyxSoC`）创建 `feature/<topic>` 分支开发。
2. 子仓代码先提交并推送（确保远端可达）。
3. 回到 `system0/dev`，更新子模块指针：
   - `make bump-cl3 REF=<full_sha>`
   - `make bump-ysyxsoc REF=<full_sha>`
4. 在 `system0` 跑集成验证（建议至少 `make test-run-soc-all`）。
5. 提交 `system0` 的“子模块指针 bump”提交并发 PR。

### 提交顺序（必须）

1. 先提交并推送子仓（CL3/ysyxSoC）。
2. 再提交 `system0` 子模块指针更新。

不要把 `system0` 指针指向“只在本地存在、远端不可 fetch”的 commit。

### 每日同步建议

```bash
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive --checkout
```

这三条保证：
- 主仓代码最新；
- 子模块 URL 与 `.gitmodules` 一致；
- 子模块检出到主仓锁定 commit（而不是分支最新 head）。

### 10 条命令速查表

1. 同步主仓 + 子模块（每天开工前）
```bash
git pull --ff-only && git submodule sync --recursive && git submodule update --init --recursive --checkout
```

2. 切到 `system0/dev`
```bash
git switch dev && git pull --ff-only
```

3. 从 `dev` 开个人分支
```bash
git switch -c feature/<topic>
```

4. 进入固定构建环境
```bash
nix develop
```

5. 本地快速验证（允许子模块本地改动）
```bash
make test-run-soc-all ALLOW_DIRTY=1
```

6. 在 CL3 开发分支（仅当要改 CL3 代码）
```bash
git -C CL3 switch -c feature/<topic>
```

7. 提交并推送 CL3 改动
```bash
git -C CL3 add -A && git -C CL3 commit -m "<cl3-change>" && git -C CL3 push -u origin HEAD
```

8. 在 system0 更新 CL3 子模块指针
```bash
make bump-cl3 REF=<cl3_full_commit_sha>
```

9. 提交并推送 system0（含子模块 bump）
```bash
git add -A && git commit -m "<system0-change>" && git push -u origin HEAD
```

10. 其他同事机器对齐到同一版本
```bash
git pull --ff-only && git submodule sync --recursive && git submodule update --init --recursive --checkout
```

## 常见问题

- 现象：`make build-go` 报 `NoSuchElementException: PATH`
  根因通常是 Chisel 生成动作运行时环境被清空。当前仓库已在 `bazel-go/rules/generate.bzl` 使用 `use_default_shell_env = True`，并在 Makefile 显式传递 Bazel action env，默认不应再出现该问题。

- 现象：`git submodule update --init --recursive --checkout` 报
  `not our ref b41ee216...`（`ysyxSoC/rocket-chip`）
  先执行：
  ```bash
  git submodule sync --recursive
  git -C ysyxSoC submodule sync --recursive
  git submodule update --init --recursive --checkout
  ```
  如果仍失败，说明该机器拉到的 `rocket-chip` 远端不包含 pinned commit，需要检查 `ysyxSoC/.gitmodules` 的 `rocket-chip` URL 是否与你当前可访问的 fork 一致。

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

## 最近更新（2026-03-12）

- CL3 子模块已更新到 `f4c510a`，包含：
  - `difftest.cpp`：DTB 改为可选加载（环境变量 `CL3_DTB_FILE`），不再依赖硬编码绝对路径。
  - `difftest.cpp`：当当前拍无 `commit` 时跳过严格 double-check，避免启动阶段误报。
  - `difftest.cpp`：保持 `a1(x11)=0x80fff9f0` 初始化，与 CL3 启动约定一致。
  - `difftest.h`：恢复 CL3-only 仿真层级宏路径（`top.u_CL3Top...`）。
  - `CL3Config.scala`：`BOOT_ADDR` 由 `SimMemOption` 自动选择。
  - `CL3Top.scala`：DPI-C 分支 `dmem` 连接改为显式字段映射。

- `bazel-bin/BUILD` 已加入 `cc/verilator/lightsss.cpp`，避免 `top_bin` 链接缺符号。

- 构建环境已做双 firtool 固定与分流：
  - `flake.nix` 中 CL3 固定 `firtool 1.133.0`，SoC 固定 `firtool 1.62.1`
  - Makefile 中 `BAZEL_ENV_FLAGS`（CL3）与 `BAZEL_ENV_FLAGS_SOC`（SoC）分离传递
  - 避免 SoC 误用新 firtool、或 CL3 误用旧 firtool 导致的 FIRRTL 降级失败

- `bazel-go` 的 Chisel 规则已保留默认动作环境（`PATH`/`CHISEL_FIRTOOL_PATH` 等），修复了 `NoSuchElementException: PATH` 的生成阶段崩溃。

- 在 `nix develop` 环境下，CL3-only 流程已验证：
  - `make test-run-add` 通过
  - `make test-run-all` 通过（35/35）

- 在 `nix develop` 环境下，SoC+CL3 流程已验证：
  - `make test-run-soc-all ALLOW_DIRTY=1` 通过（35/35）

## 设计原则

- 保留原有 CL3-only 流程，不互相污染
- SoC 集成通过独立工作区（`bazel-soc-*`）实现
- 尽量让可变环境因素收敛到 `flake.nix` + `Makefile`
