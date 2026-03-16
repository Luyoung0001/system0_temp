# system0 贡献说明

`system0` 是集成仓库。
`CL3` 和 `ysyxSoC` 是源码仓库，以 submodule 的形式被 `system0` 锁定。

如果你要给这个项目贡献代码，按下面做就够了。

## 分支约定

- `master`：稳定分支。
- `dev`：日常集成分支。
- `feature/<topic>`：个人开发分支。

通常建议：

- 日常开发从 `dev` 拉出 `feature/<topic>`。
- 测试通过后，提交 PR 到 `dev`。
- 需要发稳定版本时，再从 `dev` 合并到 `master`。

## 开工前先同步

在 `system0` 根目录执行：

```bash
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive --checkout
```

作用：

- 更新 `system0` 自己的代码。
- 同步 submodule 的 URL 配置。
- 把 `CL3` 和 `ysyxSoC` 检出到 `system0` 当前锁定的 commit。

## 只修改 system0

如果你只改 `system0` 本身，比如 `Makefile`、文档、顶层脚本：

```bash
git switch dev
git pull --ff-only
git switch -c feature/<topic>
nix develop
make test-run-soc-all ALLOW_DIRTY=1
git add -A
git commit -m "<message>"
git push -u <your-remote> HEAD
```

然后发一个从 `feature/<topic>` 到 `dev` 的 PR。

## 修改 CL3 或 ysyxSoC

如果你改的是子仓库，流程要分两步。

第一步，先在子仓库里开发、提交、推送：

```bash
git -C CL3 switch -c feature/<topic>
```

或者：

```bash
git -C ysyxSoC switch -c feature/<topic>
```

开发完成后先测试：

```bash
nix develop
make test-run-soc-all ALLOW_DIRTY=1
```

然后在子仓库里提交并 push。

第二步，回到 `system0` 更新 submodule 指针：

```bash
make bump-cl3 REF=<full_sha>
```

或者：

```bash
make bump-ysyxsoc REF=<full_sha>
```

再跑一次干净集成测试：

```bash
make test-run-soc-all
```

最后提交 `system0` 里的 submodule 指针变更，并发 PR 到 `dev`。

## 一条硬规则

先 push 子仓库 commit，再 bump `system0` 里的 submodule 指针。

不要让 `system0` 指向一个只存在于你本地、别人拉不到的 commit。

## 最常用的判断方式

如果你不确定改动应该提到哪里，可以这样判断：

- 改顶层脚本、文档、集成流程：提到 `system0`。
- 改 CPU 本体、Chisel 源码：提到 `CL3`。
- 改 SoC 集成、外设、SoC 相关逻辑：提到 `ysyxSoC`。

拿不准时，先在本地改完并跑通：

```bash
nix develop
make test-run-soc-all ALLOW_DIRTY=1
```

能跑通后，再决定是只提 `system0`，还是同时更新子仓库和 submodule 指针。
