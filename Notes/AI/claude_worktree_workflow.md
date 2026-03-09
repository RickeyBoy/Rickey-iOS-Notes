# Git Worktree / Worktrunk：并行 AI 开发工作流实战

> 最近在日常开发中尝试了用 Git Worktree (Worktrunk) 配合 Claude Code 进行并行开发，体验下来效果非常好。这篇文章就来分享一下这套工作流的搭建和使用经验，希望能对大家有点帮助~



## 一、为什么需要 Git Worktree

先说一个日常开发中很常见的场景：你正在开发一个新功能，突然来了一个紧急 bug 需要修复。通常你要么 `git stash`，要么 `git commit` 一个半成品，切换分支去修 bug，改完再切回来。

这个过程不仅繁琐，而且一旦涉及到 AI 辅助开发（比如 Claude Code），问题就更大了——每个 Claude 会话的上下文会因为切换分支而断掉。

Git Worktree 就是为了解决这个问题的。简单来说，它允许一个 Git 仓库拥有**多个工作目录**，每个目录检出不同的分支：

```
my-project/            # 主仓库，develop 分支
my-project.feature-A/  # worktree，feature-A 分支
my-project.feature-B/  # worktree，feature-B 分支
my-project.bugfix/     # worktree，bugfix 分支
```

核心优势：

- **不需要多次克隆仓库**，所有 worktree 共享同一个 `.git` 数据库
- **多个分支同时活跃**，互不干扰
- **磁盘空间省得多**，不像 clone 那样每次都复制整个 git 历史



## 二、Worktree vs Clone：到底省了什么

可能有同学会问：我直接 clone 多份不也行吗？

当然可以，不过在回答这个问题之前，我们先看看一个 Git 仓库到底包含了哪些东西。

### .git 目录里有什么

当你 `git clone` 一个仓库，实际上拿到的是两部分：**工作目录**（你能看到的源代码文件）和 **`.git` 目录**（Git 的"数据库"）。

`.git` 目录里主要包含这些内容：

| 目录/文件 | 作用 | 说明 |
|-----------|------|------|
| `objects/` | 对象数据库 | 存储所有的 commit、tree、blob 对象，经过压缩打包后放在 `objects/pack/` 中。这是 Git 历史的核心 |
| `refs/` | 引用 | 分支指针（`refs/heads/`）、标签（`refs/tags/`）、远程跟踪（`refs/remotes/`） |
| `logs/` | 操作日志 | 记录 HEAD 和各分支的变更历史（reflog） |
| `hooks/` | 钩子脚本 | pre-commit、pre-push 等自动化脚本 |
| `lfs/` | 大文件存储 | 如果项目使用了 Git LFS，大文件（图片、二进制等）会缓存在这里 |
| `index` | 暂存区 | 记录当前 staged 的文件状态 |
| `HEAD` | 当前指针 | 指向当前检出的分支或 commit |
| `config` | 仓库配置 | remote 地址、分支追踪关系等 |

### 实际项目的占比

那这些东西到底占多大空间呢？我用我的一个 iOS 项目跑了一下：

```
.git 目录总大小：4.2 GB
├── lfs/       3.4 GB  (81%)  ← 大文件缓存（图片、字体等）
├── objects/   761 MB  (18%)  ← 所有历史 commit 的压缩包
├── logs/      1.3 MB  (<1%)
├── refs/      196 KB  (<1%)
├── hooks/      88 KB  (<1%)
└── 其他        ~2 MB  (<1%)
```

可以看到，`.git` 里面大头是两块：**LFS 大文件缓存**和 **objects 对象数据库**，两者加起来占了 99% 以上。

不过这里说的"工作目录"可不只是源代码。我实际看了一下手边这个项目的空间分布：

```
仓库总大小：82 GB
├── .git/         4.2 GB   ← Git 数据库
├── .spmCache/    4.9 GB   ← SPM 依赖缓存
├── Features/      56 GB   ← 功能模块（含 SPM .build 缓存）
├── Core/          16 GB   ← 核心模块（含 SPM .build 缓存）
├── fastlane/     320 MB
└── 其他           ~1 GB   ← 纯源码、配置文件等
```

好家伙，56 GB 的 Features 目录？点进去一看，每个模块下面都有一个巨大的 `.build/` 目录——这是 SPM resolve 之后生成的本地构建缓存。比如其中一个模块，源码才 208 KB，但 `.build` 有 7.3 GB。

简单来说，这 82 GB 的构成是这样的：

| 类别 | 大小 | 说明 |
|------|------|------|
| 纯源码 + 配置 | ~1 GB | 真正的代码文件 |
| SPM 构建缓存 | ~72 GB | 每个模块的 `.build/` + `.spmCache/` |
| Git 数据库 | ~4.2 GB | `.git/` 目录 |
| 其他（fastlane 等） | ~4.8 GB | 工具链、脚本 |

### Clone vs Worktree 对比

那么问题来了，如果我需要 4 个分支同时工作。

**纯净状态**下（刚创建、还没编译），一个 worktree 只有约 **1 GB**（纯源码）。这时候对比非常夸张：

| 方案 | 4 个分支并行 | 说明 |
|------|-------------|------|
| Clone × 4 | ~328 GB | 每份都要完整下载 .git + 全部文件 |
| Worktree × 4（纯净） | ~85 GB | 主仓库 82 GB + worktree 源码 1 GB × 3 |

差距很明显。而且 clone 还有一个隐性成本：每次都要重新下载整个 Git 历史，网络慢的时候能等很久。Worktree 是本地秒创建的。

### 编译后空间会膨胀吗

不过需要注意的是，如果你在 worktree 中**运行了 app**（执行了编译），空间会显著增长。主要来自两部分：

**1. SPM 构建缓存（在项目目录内）**

每个 worktree 执行 SPM resolve 和编译后，会在各模块下生成独立的 `.build/` 目录。以我的项目为例，这部分加起来就有 70+ GB。这个缓存是**不共享的**，每个 worktree 都会生成自己的一份。

**2. Xcode DerivedData（在全局目录）**

好消息是，Xcode 的 DerivedData 默认存放在 `~/Library/Developer/Xcode/DerivedData/`，不在项目目录内，所以不会直接撑大 worktree 文件夹。但每个 worktree 编译后会在 DerivedData 里新增一个条目——我看了下我的 DerivedData 总共 37 GB。

所以实际使用中的空间大概是这样：

| 场景 | 每个 worktree 大小 |
|------|-------------------|
| 刚创建（纯源码） | ~1 GB |
| resolve 了 SPM 依赖 | ~5 GB |
| 完整编译运行过 | ~70+ GB |

> 如果你只是用 Claude Agent 写代码、不需要在每个 worktree 里都编译运行，那空间占用是很小的。只在需要验证的 worktree 中编译就好，不必每个都跑一遍。

说实话，如果每个 worktree 都跑一遍完整编译，那空间上的优势就没那么大了——省下的只是 `.git` 数据库的重复（4.2 GB × N），相比 70+ GB 的构建缓存，这点节省确实不算大。

那 worktree 的核心优势到底在哪？其实是**创建速度和工作流**：

- **秒级创建**：不需要重新 clone、不需要等网络下载，本地一行命令就搞定
- **Git 状态天然隔离**：每个 worktree 有独立的 HEAD、暂存区、工作目录，分支切换零成本
- **按需编译**：大部分 worktree 只写代码（~1 GB），只在需要验证的那个里编译就好

合理的做法是：**大部分 worktree 只写代码，选一两个去编译验证**。这样既享受了并行开发的便利，又不会把磁盘撑爆。



## 三、Claude Agent 并行开发

好了，这才是重头戏。有了 Worktree，跑多个 Claude Agent 就变得非常自然：

```
终端标签页 1 → my-project.feature-A/ → claude
终端标签页 2 → my-project.feature-B/ → claude
终端标签页 3 → my-project.bugfix/    → claude
```

每个标签页里的 Claude：

- 在独立的工作目录中操作
- 提交到各自的分支
- 完全不会互相影响

这样你就可以让一个 Claude 做功能 A，另一个做功能 B，第三个修 bug，三件事**同时推进**。每个 Agent 的上下文都是干净的，不会因为别的任务搞乱文件状态。



## 四、Worktree 管理工具：Worktrunk

手动管理 worktree 的命令其实挺繁琐的，正常流程你得这样：

```bash
git worktree add ../my-project.feature-A develop -b feature-A
cd ../my-project.feature-A
```

每次都要敲这么一长串，分支名还得写两遍，确实不太优雅。

推荐使用 [**Worktrunk**](https://github.com/max-sixty/worktrunk)（命令行工具名为 `wt`），它是一个用 Rust 写的 worktree 管理器，专门为并行 AI 开发设计的。用起来就一行：

```bash
wt switch -c feature-A
```

这条命令会自动帮你：

1. 基于当前分支创建新分支 `feature-A`
2. 在主仓库的同级目录下创建 worktree
3. 切换到新的工作目录

执行完之后，你的目录结构就变成了这样：

```
~/Projects/
├── my-project/            # 主仓库（你执行命令的地方）
│   ├── .git/              # 完整的 Git 数据库
│   ├── src/
│   └── ...
├── my-project.feature-A/  # 新创建的 worktree
│   ├── .git               # 注意：这里只是一个文件，指向主仓库的 .git
│   ├── src/               # 完整的工作目录副本
│   └── ...
└── my-project.feature-B/  # 另一个 worktree（如果你再创建一个的话）
    ├── .git
    ├── src/
    └── ...
```

> 注意看 worktree 目录下的 `.git`——它不是一个目录，而是一个**文件**，内容就一行指向主仓库 `.git` 的路径。这就是 worktree 能共享 Git 数据库的原理。

你还可以搭配 Claude Code 一起用（但其实没必要）：

```bash
wt switch -x claude -c feature-A -- '实现功能 A'
```

这条命令会创建 worktree 之后自动启动 Claude，并把任务描述传给它。



## 五、实际开发流程

我目前的开发流程大概是这样的：

**第一步：创建 worktree**

```bash
wt switch -c feature-A
wt switch -c feature-B
wt switch -c bugfix
```

**第二步：在各个 worktree 中启动 Claude**

每个终端标签页进入对应的 worktree 目录，然后启动 `claude`。

**第三步：并行工作**

三个标签页同时推进，互不干扰。想看哪个任务的进度就切到对应的标签页。

**第四步：完成后合并**

每个 Agent 完成任务后，正常走 PR 流程合并回主分支就行。

**第五步：清理不必要分支**

清理用完的 worktree，节省空间，具体方式可以看后续。



## 六、用完之后怎么清理

Worktree 用完不清理，时间一长目录就会越积越多。正确的清理姿势分两步：

### 1. 删除 worktree

**用 git 命令删除**：

```bash
git worktree remove ../my-project.feature-A
```

这条命令会同时做两件事：
- 删除 worktree 对应的目录（`my-project.feature-A/`）
- 清理主仓库 `.git/worktrees/` 中的关联记录

**用 wt 命令删除**：

```bash
wt remove feature-A
```

效果一样，如果是用了 Worktrunk 的话这条命令更简洁。

**手动删了目录怎么办？**

如果你直接 `rm -rf` 了 worktree 目录，Git 并不知道它已经没了，`git worktree list` 里还会显示这条记录。这时候跑一下：

```bash
git worktree prune
```

它会扫描所有 worktree 记录，把指向已不存在目录的条目清理掉。

### 2. 清理构建产物

前面提到，`git worktree remove` 会删掉整个 worktree 目录，所以目录内的 SPM `.build/` 缓存会一并清理。但 Xcode 的 **DerivedData 不会被清理**——它在全局目录 `~/Library/Developer/Xcode/DerivedData/` 里，每个 worktree 编译后都会留下一个条目。

以我的项目为例，两个 worktree 编译后的 DerivedData 条目加起来就有 39 GB：

```
~/Library/Developer/Xcode/DerivedData/
├── MyProject-abwbwhgd...  21 GB  ← 主仓库的
├── MyProject-gqrqpoak...  18 GB  ← 某个 worktree 的
└── ...
```

worktree 删了，但对应的 DerivedData 条目还在。时间一长这里会积攒大量无用缓存。

**用 Worktrunk hook 自动清理**：

如果你用了 Worktrunk，可以通过 [hook](https://worktrunk.dev/hook/) 在删除 worktree 时自动清理 DerivedData。

这里的关键问题是：DerivedData 目录名是 `项目名-<一段哈希>`，这个哈希是根据 `.xcodeproj` 的完整路径用 MD5 生成的，没法直接从 worktree 路径推算出来。但好在每个 DerivedData 目录下都有一个 `info.plist`，里面的 `WorkspacePath` 字段记录了对应的项目路径：

```bash
$ plutil -p ~/Library/Developer/Xcode/DerivedData/MyProject-gqrqpoak*/info.plist
  "WorkspacePath" => "/Users/me/Projects/my-project.feature-A/MyProject.xcodeproj"
```

利用这一点，我们可以配一个 Worktrunk 的 `post-remove` hook，在 worktree 删除后自动清理对应的 DerivedData。

> `post-remove` 阶段虽然目录已经被删了，但 Worktrunk 的模板变量（如 `{{ worktree_path }}`）仍然可用，它们引用的是被删除 worktree 的信息。

配置文件位置：

- **项目级**：仓库根目录下的 `.config/wt.toml`
- **用户级**（推荐，全局生效）：`~/.config/worktrunk/config.toml`

在配置文件中加上：

```toml
[post-remove]
clean-derived = """
  grep -rl {{ worktree_path }} \
    ~/Library/Developer/Xcode/DerivedData/*/info.plist 2>/dev/null \
  | while read plist; do
      derived_dir=$(dirname "$plist")
      rm -rf "$derived_dir"
      echo "Cleaned DerivedData: $derived_dir"
    done
"""
```

原理很简单：DerivedData 的 `info.plist` 是 XML 格式的纯文本文件，用 `grep -rl` 直接搜索包含当前 worktree 路径的 plist，找到了就删掉对应目录。

> 这不是 Worktrunk 的官方方案，是我根据 Xcode DerivedData 的 [目录命名机制](https://pewpewthespells.com/blog/xcode_deriveddata_hashes.html) 写的自定义 hook。hook 中可以使用 Worktrunk 的模板变量，比如 `{{ worktree_path }}`（worktree 完整路径）、`{{ repo }}`（仓库目录名）、`{{ branch }}`（分支名）等，完整列表参考 [Worktrunk hook 文档](https://worktrunk.dev/hook/)。另外注意模板变量会自动 shell-escape，不需要额外加引号。

这样每次执行 `wt remove` 时，只会精确清理**这个 worktree 对应的** DerivedData，不会误删主仓库或其他 worktree 的编译缓存。

**手动清理**：

如果你没有用 Worktrunk 的话，那只能手动清理了。直接删掉对应的 DerivedData 目录即可（说起来容易做起来难，主要是难以找到对应的编译产物目录，所以我推荐用 Worktrunk，第一次配置麻烦一点，但之后省事）

```bash
# 查看有哪些条目
ls ~/Library/Developer/Xcode/DerivedData/
# 删掉不需要的（根据名称和时间判断）
rm -rf ~/Library/Developer/Xcode/DerivedData/MyProject-gqrqpoak*
```

### 3. 清理分支

删掉 worktree 并不会删除对应的分支。如果分支已经合并了、不再需要，记得顺手清理：

```bash
# 删除本地分支
git branch -d feature-A

# 删除远程分支（如果 push 过的话）
git push origin --delete feature-A
```

### 完整清理流程

总结一下，一个 worktree 用完后的标准清理流程：

**使用原生 Git 命令**：

```bash
# 1. 回到主仓库
cd ~/Projects/my-project
# 2. 删除 worktree（目录 + SPM 缓存一起清理）
git worktree remove ../my-project.feature-A
# 3. 删除本地分支
git branch -d feature-A
# 4.（可选）清理对应的 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/MyProject-<hash>
# 5.（可选）如果之前手动删过目录，统一清理残留记录
git worktree prune
```

**使用 Worktrunk**：

```bash
# 1. 删除 worktree + 分支一步搞定
wt remove feature-A
# 2. DerivedData 通过 post-remove hook 自动清理（需提前配置）
```

如果配置了 `post-remove` hook，Worktrunk 会在删除 worktree 后自动执行清理脚本，连 DerivedData 都不用手动管。这也是我推荐用 Worktrunk 的原因之一——清理流程从 5 步缩减到 1 步。





## 七、用 GitHub Desktop 查看 Diff

Claude Code 在 worktree 里改了一堆代码，你怎么 review 呢？纯命令行 `git diff` 看大量改动还是挺累的。我本身是用 [**GitHub Desktop**](https://desktop.github.com/) 来查看 diff，它对 worktree 的支持其实并没有那么好，但是免费。

**第一次需要手动添加仓库**

GitHub Desktop 不会自动识别 worktree 目录，你需要手动把它添加进来：

1. 打开 GitHub Desktop
2. 菜单 → File → Add Local Repository（或直接 `⌘O`）
3. 选择 worktree 所在的目录（比如 `~/Projects/my-project.feature-A/`）

添加一次之后就会一直保留在列表里，下次直接切换就行。

**日常使用**

添加完之后，体验和普通仓库完全一样：

| 功能 | 说明 |
|------|------|
| Changes 面板 | 实时查看 Claude 改了哪些文件 |
| Diff 视图 | 逐行查看代码变更，高亮增删 |
| History | 查看 Agent 的提交历史 |
| 分支切换 | 在左上角切换不同的 worktree 仓库 |

> 如果你同时开了多个 worktree，可以在 GitHub Desktop 的仓库列表里快速切换，每个 worktree 都是独立的条目。这样一边让 Claude 在终端里写代码，一边在 GitHub Desktop 里实时看 diff，体验非常舒服。



## 八、其他实用工具

### gwq：Worktree 管理 UI

当你的 worktree 越来越多（比如超过 10 个），手动管理就开始头疼了。这时候可以试试 [**gwq**](https://github.com/d-kuro/gwq)，它提供了一个模糊搜索的 UI 来管理 worktree：

```bash
gwq list
```

运行后会弹出一个交互式的列表，你可以快速搜索、切换、删除 worktree。对于重度 worktree 用户来说挺方便的。



## 九、总结

最后总结一下这套方案的核心：

- **Git Worktree** 让多个分支可以同时活跃，共享 Git 数据库，节省磁盘空间
- **Claude Code** 在每个独立的 worktree 中运行，上下文隔离互不干扰
- **Worktrunk（wt）** 简化了 worktree 的创建和管理，一行命令搞定
- **GitHub Desktop** 免费查看 diff，手动添加一次 worktree 目录即可

整套方案搭下来，其实就这几个工具：

```
Git + git worktree + wt + Claude CLI + GitHub Desktop
```

没什么复杂的配置，但效率提升确实很明显。尤其是在需要同时推进多个功能或修复的时候，并行开发的优势就体现出来了。
