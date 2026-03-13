# system0 Collaboration Guide

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

### A/B/C 三人协作实战（从 fork 到合并）

假设：

- A：管理员（维护上游仓库）
- B、C：开发者
- 上游组织：`AUser`
- 开发者 fork：`BUser` / `CUser`

#### 1) A 的一次性初始化（只做一次）

目标：三仓都建立统一分支模型，所有功能先进入 `dev`。

在 `system0` / `CL3` / `ysyxSoC` 分别执行：

```bash
git switch master
git pull --ff-only
git switch -c dev
git push -u origin dev
```

A 在 GitHub 做仓库策略：

- 保护 `master`（禁止直接 push，必须 PR）
- 建议 `dev` 也走 PR 合并
- 约定功能分支命名：`feature/<topic>`

#### 2) B、C 首次接入（fork + clone + 配置远端）

目标：开发者既能同步上游，也能向自己的 fork 推送分支。

先在 GitHub fork 三个仓库：

- `AUser/system0`
- `AUser/CL3`
- `AUser/ysyxSoC`

然后以 B 为例（C 同理）：

```bash
git clone --recurse-submodules git@github.com:BUser/system0.git
cd system0
git remote add upstream git@github.com:AUser/system0.git
git submodule sync --recursive
git submodule update --init --recursive --checkout
```

给子模块增加“上游 + 自己 fork”双远端（可选但推荐）：

```bash
git -C CL3 remote rename origin upstream
git -C CL3 remote add origin git@github.com:BUser/CL3.git
git -C ysyxSoC remote rename origin upstream
git -C ysyxSoC remote add origin git@github.com:BUser/ysyxSoC.git
```

这一步的作用：

- `upstream`：始终跟踪 A 的主线
- `origin`：给自己推送 feature 分支

#### 3) 每天开工前同步（A/B/C 都一样）

```bash
git fetch upstream
git switch dev
git merge --ff-only upstream/dev
git submodule sync --recursive
git submodule update --init --recursive --checkout
```

作用：把主仓与子模块一起同步到团队当前基线，避免“主仓新了、子模块还旧”。

#### 4) 场景 A：B 只改 system0（不改 CL3/ysyxSoC）

```bash
git switch dev
git merge --ff-only upstream/dev
git switch -c feature/makefile-cleanup
nix develop
make test-run-soc-all ALLOW_DIRTY=1
git add Makefile README.md
git commit -m "Refine make targets and docs"
git push -u origin feature/makefile-cleanup
```

PR 方向：

- `BUser/system0:feature/makefile-cleanup` -> `AUser/system0:dev`

作用：先合入 `dev` 做集成，不直接碰 `master`。

#### 5) 场景 B：C 改 CL3（典型跨仓流程）

第一阶段：在 CL3 开发并提 CL3 PR

```bash
git -C CL3 fetch upstream
git -C CL3 switch dev
git -C CL3 merge --ff-only upstream/dev
git -C CL3 switch -c feature/decoder-fix
```

开发后先做本地联调（允许 dirty）：

```bash
nix develop
make test-run-soc-all ALLOW_DIRTY=1
```

然后提交并推送 CL3：

```bash
git -C CL3 add -A
git -C CL3 commit -m "Fix decoder hazard logic"
git -C CL3 push -u origin feature/decoder-fix
```

PR 方向：

- `CUser/CL3:feature/decoder-fix` -> `AUser/CL3:dev`

第二阶段：CL3 PR 合并后，把 system0 指针 bump 到该 commit

```bash
git switch dev
git merge --ff-only upstream/dev
git switch -c feature/bump-cl3-decoder-fix
make bump-cl3 REF=<cl3_merged_full_sha>
nix develop
make test-run-soc-all
git push -u origin feature/bump-cl3-decoder-fix
```

PR 方向：

- `CUser/system0:feature/bump-cl3-decoder-fix` -> `AUser/system0:dev`

关键点：先合并 CL3，再 bump system0；不要反过来。

#### 6) 场景 C：B 改 ysyxSoC

流程与 CL3 完全对称，把命令里的 `CL3` 换成 `ysyxSoC`，bump 命令换为：

```bash
make bump-ysyxsoc REF=<ysyxsoc_merged_full_sha>
```

#### 7) 发布阶段（A 操作）

当 `system0/dev` 达到阶段稳定，A 发发布 PR：

- `AUser/system0:dev` -> `AUser/system0:master`

合并后打 tag（可选），形成可复现里程碑版本。

#### 8) 三条硬规则（强烈建议）

1. 子模块指针只能指向“已 push 到远端、团队都能 fetch”的 commit。
2. 功能 PR 一律先进 `dev`，`master` 只做发布。
3. 最终合入前必须在 `system0` 跑一次不带 `ALLOW_DIRTY=1` 的验证。
