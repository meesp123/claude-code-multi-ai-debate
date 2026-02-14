---
description: Agent Team 辩论赛 — 多 AI 互相辩论，Lead 汇总 DECISION
complexity: M
argument-hint: <topic> [--files f1 f2 ...] [--with pi,codex,gemini] [--rounds 2] [--preset balanced|deep] [--model cli:model,...] [--effort high|xhigh] [--advocate haiku|sonnet|opus] [--critic haiku|sonnet|opus]
keywords:
  - debate
  - review
  - challenge
  - multi-ai
  - pi
  - codex
  - gemini
  - qwen
  - kimi
  - team
---

# /debate — Agent Team 辩论赛

> 目的：多个 AI agent 互相辩论，Lead 做 moderator 汇总 DECISION。
> 原则：agents 互相发消息讨论，不是线性流水线。外部 AI (Pi/Codex/Gemini/Qwen/Kimi) 通过 proxy agent 参与。

## Phase Map

| # | Phase | 依赖 | 可跳过 |
|---|-------|------|--------|
| 1 | 参数解析 + Context Assembly | - | ❌ |
| 2 | Team Setup (创建 + Spawn) | 1 | ❌ |
| 2.5 | Wait for READY | 2 | ❌ |
| 3 | Round 1: PROPOSAL | 2.5 | ❌ |
| 4 | Round 2: CHALLENGE | 3 | ❌ |
| 4.9 | Context Refresh | 4 | ✅ (仅 rounds>=3) |
| 5 | Round 3: REBUTTAL (rounds>=3) | 4.9 | ✅ |
| 6 | DECISION + Cleanup | 4/5 | ❌ |

---

## Phase 1: 参数解析 + Context Assembly

从 `$ARGUMENTS` 中解析：
- **topic**: 除 `--flags` 外的所有文本
- **files**: `--files` 后的文件路径列表（可选）
- **with**: `--with` 后逗号分隔的外部 CLI 列表（可选，支持 pi/codex/gemini/qwen/kimi）
- **rounds**: `--rounds` 后的数字（默认 2，最多 3）
- **preset**: `--preset` 后的预设名（可选，支持 balanced/deep，默认 balanced）
- **model**: `--model` 后逗号分隔的 `cli:model` 对（可选，如 `pi:gpt-5.2,codex:gpt-5.3-codex,gemini:gemini-3-pro-preview`）
- **effort**: `--effort` 后的 reasoning effort 级别（可选，对 pi/codex/kimi 有效。pi 用 `--thinking level`，codex 用 `--config`，kimi 用 `--thinking` toggle。支持 high/xhigh）
- **advocate_model**: `--advocate` 后的 Claude 模型（可选，支持 haiku/sonnet/opus）
- **critic_model**: `--critic` 后的 Claude 模型（可选，支持 haiku/sonnet/opus）

### Preset 智能默认

Preset 提供基线配置，显式 flag (`--advocate`/`--critic`/`--model`/`--effort`) 覆盖 preset：

| Preset | advocate | critic | pi | pi effort | codex | codex effort | gemini | qwen | kimi | kimi thinking |
|--------|----------|--------|----|----------|-------|-------------|--------|------|------|---------------|
| `balanced` (默认) | sonnet | sonnet | — | high | — | high | — | — | — | off |
| `deep` | opus | sonnet | gpt-5.2 | xhigh | gpt-5.2 | xhigh | gemini-3-pro-preview | — | — | on |

> **—** = 不传 `-Model`，使用 CLI 自身默认模型（pi → gpt-5.3-codex, codex → gpt-5.3-codex, gemini → gemini-2.5-pro, qwen → coder-model）
> **显式 `--model`** 覆盖 preset 的模型，如 `--preset deep --model gemini:gemini-3-flash-preview` 只覆盖 gemini

### 可用模型参考

Lead spawn proxy agent 时按此表选择 `-Model` 参数：

| CLI | 模型 ID | 定位 | OAuth |
|-----|--------|------|-------|
| pi | `gpt-5.3-codex` | 代码专用，CLI 默认 | ✅ |
| pi | `gpt-5.2` | 大模型，更强推理 | ✅ |
| pi | `gpt-5.2-codex` | 代码版大模型 | ✅ |
| pi | `gpt-5.1-codex-mini` | 轻量快速 | ✅ |
| pi | `gpt-5.1-codex-max` | 最大模型 | ✅ |
| pi | `gpt-5.1` | 基础模型 | ✅ |
| codex | `gpt-5.3-codex` | 代码专用，CLI 默认 | ✅ |
| codex | `gpt-5.2` | 大模型，更强推理 | ✅ |
| codex | `gpt-5.2-codex` | 代码版大模型 | ✅ |
| codex | `gpt-5.1-codex-mini` | 轻量快速 | ✅ |
| gemini | `gemini-3-pro-preview` | 最新旗舰 | ✅ |
| gemini | `gemini-3-flash-preview` | 最新快速 | ✅ |
| gemini | `gemini-2.5-pro` | 稳定版旗舰 | ✅ |
| qwen | `coder-model` | CLI 默认 (alias) | ✅ |
| qwen | `qwen3-coder-plus` | 代码专用最强 | ❌ 回退 |
| qwen | `qwen3-coder-flash` | 代码快速 | ❌ 未验证 |
| kimi | (默认) | kimi v1.12.0 默认模型 | ✅ |

> **Qwen OAuth 限制**: 免费订阅版仅支持 `coder-model`，其他模型需 API Key。不传 `-Model` 时 CLI 自动用默认模型。

### 响应时间参考

| 组合 | 预估时间 | TimeoutSec | 注意 |
|------|---------|-----------|------|
| pi `gpt-5.2` + `xhigh` | **~5-10 分钟** | 900 | Pi wrapper 较轻 |
| pi `gpt-5.3-codex` + `high` | ~2-5 分钟 | 600 | 代码任务推荐 |
| codex `gpt-5.2` + `xhigh` | **~10-30 分钟** | 1800 | 最慢组合，需要耐心 |
| codex `gpt-5.3-codex` + `high` | ~3-7 分钟 | 600 | 代码任务推荐 |
| gemini `gemini-3-pro-preview` | ~1-3 分钟 | 300 | 可能触发 429 |
| qwen `coder-model` (默认) | ~1-3 分钟 | 300 | 较快 |
| kimi (默认, thinking off) | ~1-3 分钟 | 300 | Python 需 PYTHONIOENCODING=utf-8 |
| kimi (默认, thinking on) | ~2-5 分钟 | 600 | thinking 模式更慢 |

> **Lead 辩论管理**: `gpt-5.2 + xhigh` 响应慢但观点质量高（曾发现其他参与方都没注意到的关键 bug）。
> Lead **必须等齐所有 CHALLENGE（含 proxy-pi/proxy-codex）** 再让 advocate 回应。等待期间内部 agent 可自由讨论已收到的观点，但 advocate 的正式回应要等所有人到齐。

### Lead 行为规范
- AskUserQuestion 尽可能合并为一次（主题 + 模型 + 其他确认一起问）
- 等待期间只在状态变化时更新（收到新 CHALLENGE → 刷新追踪表），不重复输出 "等待中..."

解析优先级（高→低）：显式 flag > preset > 硬编码默认
- `advocate_model` = `--advocate` || preset.advocate || sonnet
- `critic_model` = `--critic` || preset.critic || sonnet
- `effort` = `--effort` || (有 pi/codex/kimi 时: preset.effort) || 不传
- 各 CLI model = `--model cli:xxx` || preset.{cli}_model || 不传 (-Model 省略)

IF `--with` 中有不支持的 CLI:
→ 警告用户："不支持的 CLI: {cli}，已跳过。当前支持: pi, codex, gemini, qwen, kimi。你是否想用: {最相似的支持项}?"
→ 跳过该 CLI，继续处理其余项
→ 如果所有 CLI 都不支持，则停止

如有 `--files`，读取每个文件内容，组装为 context 文本。

文件安全门控:
- 校验每个文件存在性，不存在则警告并跳过
- 单文件上限 500 行，超限则截取首尾各 100 行 + 中间省略标记
- 总 context 上限 2000 行，超限则按文件顺序截断

解析 `--model` 时，将每个 `cli:model` 对存入 map，如 `{ pi: "gpt-5.2", codex: "gpt-5.3-codex", gemini: "gemini-3-pro-preview" }`。

### Context Assembly (Phase 1.5)

Lead 组装 `{technical_context}` — 精选项目技术上下文，供外部 AI 参考。

#### 组装规则

**自动包含** (从项目文档提取，不超过 15 行):
1. Stack 信息: 框架、语言版本、主要依赖 (1-2 行)
2. 数据约定: 货币单位、精度规则 (1 行)
3. 架构模式: DB 类型、认证方式 (1 行)
4. 如有 `--files`: 文件的核心数据结构/接口 (5-8 行摘要)

**自动排除** (绝不注入):
- 行为规则: 个人称呼、角色设定、性格类型
- 工作流指令: TDD 流程、commit 规则、验证门禁
- 工具限制: 禁用命令列表、文件操作规则
- 结论性描述: "API rate limits are tiered (see config.ts)" → 改为 "API rate limits vary by subscription tier"
- Skills/Agents 定义
- 任何包含 "should"/"must"/"always"/"never" 的指令性语句

**反锚定原则**:
- 只给事实 (WHAT)，不给结论 (WHY/HOW)
- "系统使用 PostgreSQL 存储数据" ✅
- "PostgreSQL 比 MySQL 更安全" ❌ (这是结论，让外部 AI 自己判断)
- "API rate limits vary by subscription tier" ✅
- "API rate limits are tiered (see config.ts)" ❌ (指向具体文件 = 锚定)

#### 输出格式

```
## Project Technical Context (background reference only — challenge any assumption)
- Stack: {framework} {version}, {ui_lib}, {db}
- Language: TypeScript {version}, {runtime}
- Data: {currency_convention}, {precision_rule}
- Auth: {auth_method}
- Domain: {domain_specific_facts}
{if --files:}
- Key structures from provided files:
  {interface/type summaries, max 8 lines}
```

#### Lead 自检 (组装后):
- [ ] 总行数 ≤ 15 行？
- [ ] 不含 "should/must/always/never" 等指令？
- [ ] 不含文件路径引用 (防止锚定特定实现)？
- [ ] 不含角色/行为/工作流描述？
- [ ] 只有事实，没有结论？

### 报告给用户

报告给用户:
```
📋 辩论设置
- 主题: {topic}
- 文件: {files count} 个
- 预设: {preset}
- 参与者: advocate({advocate_model}), critic({critic_model}){, proxy-pi({pi_model or "CLI default"}, effort: {effort}), proxy-codex({codex_model or "CLI default"}, effort: {effort}), proxy-gemini({gemini_model or "CLI default"})...}
- 轮数: {rounds}

📎 技术上下文 (将注入外部 AI prompt):
{technical_context 全文展示}
```

用户可以在此时要求调整（添加/删除某些上下文行）。

---

## Phase 2: Team Setup

### 2.1 创建 Team

```
TeamCreate(team_name="debate-{timestamp}")
```

timestamp 格式: `YYYYMMDD-HHmmss` (如 `debate-20260208-143022`)

### 2.2 初始化 Scratchpad

创建独立的 scratchpad 目录（避免跨 debate 污染）:
```
scratchpad = `.scratchpad/debate-{timestamp}/`
```
在 spawn proxy 时将 `{scratchpad}` 替换为此目录的完整绝对路径。每次 debate 用独立目录，结束后可清理。

### 2.3 创建 Tasks

为每个 member 创建一个 task:
- `advocate`: "作为 advocate 参与辩论"
- `critic`: "作为 critic 参与辩论"
- 每个 `--with` CLI: `proxy-{cli}`: "作为 {cli} 代理参与辩论"

### 2.4 Spawn Members (并行)

**advocate** (debate-advocate, {advocate_model}):
```
Task(
  name="advocate",
  subagent_type="debate-advocate",
  model="{advocate_model}",
  team_name="debate-{timestamp}",
  mode="bypassPermissions",
  prompt=<<ADVOCATE_PROMPT>>
)
```

**critic** (debate-critic, {critic_model}):
```
Task(
  name="critic",
  subagent_type="debate-critic",
  model="{critic_model}",
  team_name="debate-{timestamp}",
  mode="bypassPermissions",
  prompt=<<CRITIC_PROMPT>>
)
```

**proxy-{cli}** (每个外部 CLI 一个, debate-proxy):
```
Task(
  name="proxy-{cli}",
  subagent_type="debate-proxy",
  team_name="debate-{timestamp}",
  mode="bypassPermissions",
  prompt=<<PROXY_PROMPT>>
)
```

> **模型优先级**: spawn 时 `model` 参数覆盖 agent 文件 frontmatter。
> balanced preset: advocate=sonnet, critic=sonnet; deep preset: advocate=opus, critic=sonnet。

---

## Phase 2.5: 等待 Agent Ready

Spawn 完成后，等待每个 agent 发送 READY 消息:
- 维护 checklist: [ ] advocate, [ ] critic, [ ] proxy-{cli1}, ...
- 检查 READY 消息中的 tool 列表
- 如果 advocate/critic 报告 "WebSearch unavailable":
  → 记录，后续 ACTION DM 调整: "WebSearch 不可用，用 Grep/Read + 已有知识，标注 [无外部搜索]"
- 超时 60s 未收到 READY → 重发 spawn prompt (最多 1 次)
- 全部 READY 后才进入 Phase 3

> READY = agent init 完成确认。解决 "first DM swallowed" 问题。

---

## Phase 3: Round 1 — PROPOSAL

Lead 发 DM 给 advocate (不是 broadcast):
```
SendMessage(type="message", recipient="advocate", content=<<EOF
ACTION:PROPOSAL
这是你的行动触发器。立即执行以下步骤:

辩论主题: {topic}
{context if any files}

## 项目技术背景 (与外部 AI 共享的精选上下文)
{technical_context}

步骤: 用 WebSearch 搜索相关资讯，然后 broadcast 你的 PROPOSAL (严格 300 字以内)。
注意: 上方技术背景已同步给外部 AI。你的 PROPOSAL 中引用的技术事实应与此一致，但你可以引用更多细节。
EOF
)
```

等待 advocate broadcast PROPOSAL。收到后进入 Phase 4。
> 如果 advocate 5 分钟内无响应，再发一条 DM 催促。

---

## Phase 4: Round 2 — CHALLENGE

### 4.1 信息同步 broadcast (无行动指令)
Lead broadcast:
```
[信息同步] advocate PROPOSAL 已收到。CHALLENGE 行动指令已通过 DM 发送。
advocate 方案摘要: {1-2 句摘要}
```

> **Lead 数据验证**: DM 给 proxy/critic 前，Lead 用 Grep 验证 advocate PROPOSAL 中引用的具体数字。
> 不转发未验证数据。proxy DM 中用 "Lead 摘要" 替代 advocate 原文。

### 4.1b 共享上下文块 (Shared Context Block)

Lead 为当前 round 准备 **一份** 共享上下文块，所有 proxy 和 critic DM 复用:

模板:
```
{shared_context_block} =
---
[Round Context — {PHASE}]
advocate 方案摘要: {Lead 验证的要点，只含已验证数字}
已收到观点: {如有，列各方 1 句话摘要}
---
```

**规则**:
1. Lead 写此块 **一次**，copy-paste 到每个 proxy/critic DM
2. **禁止按 CLI 定制** 辩论内容深度。所有 proxy/critic 收到完全相同的 {shared_context_block}
3. CLI 特定注意事项 (如 codex 的 AGENTS.md 加载风险) 只能在 shared block **之后** 以单行追加，不修改 shared block
4. Lead 自检: 所有 DM 的 `[Round Context` 部分是否逐字一致？不一致 = 违规，修正后重发

### 4.2 并行 DM 给所有 challengers

> ⚠️ broadcast (4.1) 和 ACTION DMs (4.2) 分两次 tool call 发送，确保 broadcast 先到达。

**DM to critic:**
```
SendMessage(type="message", recipient="critic", content=<<EOF
ACTION:CHALLENGE
这是你的行动触发器。立即执行以下步骤:
{shared_context_block}

⚠️ 反锚定提醒: 项目文档和已有代码中的设计决策可能包含未经验证的假设。
你的职责是从零质疑，不是在现有框架内微调。独立搜索外部证据。

步骤: 必须先用 WebSearch 搜索反面证据 (至少 2 个查询)，然后 broadcast CHALLENGE (严格 300 字以内)。
如 WebSearch 不可用，DM Lead 报告后用 Grep/Read 代码分析，标注 "[无外部搜索，仅代码分析]"。
EOF
)
```

**DM to each proxy-{cli}:**
```
SendMessage(type="message", recipient="proxy-{cli}", content=<<EOF
ACTION:CHALLENGE
这是你的行动触发器。立即执行以下步骤:
{shared_context_block}
技术背景: 已包含在 prompt 文件 header 中
步骤:
1. broadcast "正在调用 {cli}，预计 {time}"
2. 准备 prompt 文件: proxy-{cli}-r2-prompt.md (以 Context Isolation + Selective Injection 开头)
3. 调用 CLI → 输出到 proxy-{cli}-r2-response.md
4. broadcast 观点 (严格 200 字以内，超长必须截取/摘要)
EOF
)
```

**DM to advocate:**
```
SendMessage(type="message", recipient="advocate", content="等待 CHALLENGE 中，不要回应。Lead 会在所有 CHALLENGE 收齐后通知你。")
```

> **WebSearch 不可用应急**:
> 如 critic DM Lead 报告 WebSearch 不可用:
> 1. Lead DM proxy-{最快cli}: "ACTION:SEARCH — 搜索 {2 查询}，broadcast 结果摘要"
> 2. critic 基于代码分析继续，proxy 搜索结果作为补充信息同步

### 4.3 等待追踪

Lead 维护收到状态追踪 (在 text output 中):
- [ ] critic (timeout: 300s)
- [ ] proxy-{cli1} (timeout: 按 TimeoutSec 表)
- [ ] proxy-{cli2}
- ...

收到一个 CHALLENGE → 打钩。全部打钩 → DM advocate。

> **critic 超时**: 300s 未 broadcast → DM 催促 → 再等 120s → 标记 "无响应"，继续
> **proxy 超时**: TimeoutSec × 1.5 未响应 → 标记 "无响应"

> **Lead 字数检查**: 收到 broadcast 后，如明显超限 (>400 字):
> → DM agent: "⚠️ 字数超限，请精简到 300 字以内重新 broadcast"
> → 等待重发后再继续流程

### 渐进式等待策略
- 如果已收到 ≥ N-1 个 CHALLENGE（只差 1 个），且等待已超过该 proxy 的 TimeoutSec:
  → DM advocate: "已收到 X/Y CHALLENGE。{missing} 仍在处理中，你可以先看已到的。如果 {missing} 后续到达会补发。"
  → advocate 可先回应已到的 CHALLENGE
  → 迟到的 CHALLENGE 到达后，Lead 补发给 advocate 作为追加信息（不开新轮）
- 这避免了 codex (10-30min) 阻塞整个辩论

如果某 proxy 超过 TimeoutSec*1.5 仍未响应 → 标记为 "无响应" 并继续。

收到所有 CHALLENGE 后，DM advocate:
```
SendMessage(type="message", recipient="advocate", content=<<EOF
ACTION:RESPOND
这是你的行动触发器。立即执行以下步骤:
所有 CHALLENGE 已收到: {各方摘要}
步骤: broadcast 回应 (严格 300 字以内)。
注意: 外部 AI 已获得项目技术背景，他们的 CHALLENGE 可能基于此提出。
EOF
)
```

等待 advocate 回应。

> **循环检测**: 如果同一分歧点在两轮中被重复提出且无新证据 (代码/日志/数据)，
> Lead 在 DECISION 中直接拍板，注明 "循环终止: {分歧点}"。
> 允许 +1 轮仅当带外部证据，否则进入 DECISION。

---

## Phase 4.9: Context Refresh (仅 rounds >= 3, REBUTTAL 前强制执行)

> 防止 Lead 遗漏更新某些 CLI 的技术上下文

### 4.9.1 事实收集
Lead 汇总 CHALLENGE 轮的新发现:
- 外部 AI 提出的技术发现 (如 "3/5 CLI 已支持 MCP")
- advocate 回应中承认的事实修正
- critic/proxy 代码分析发现的新数据

### 4.9.2 更新 {technical_context}
合并新事实到 Phase 1.5 的 {technical_context}:
- 新增行标注 `[R2 发现]` (如: "- MCP coverage: 3/5 [R2 发现]")
- 保留原有行 (不删除)
- REBUTTAL 轮行数上限放宽到 20 行

### 4.9.3 更新 {shared_context_block}
为 REBUTTAL 准备新版 shared block:
```
{shared_context_block} =
---
[Round Context — REBUTTAL]
advocate 回应摘要: {对 CHALLENGE 的回应要点}
CHALLENGE 轮发现汇总: {各方 1 句话}
---
```

### 4.9.4 Lead 自检 (Phase 5 阻塞依赖)
- [ ] {technical_context} 包含所有 CHALLENGE 轮新发现？
- [ ] 每条新发现标注了 `[R2 发现]`？
- [ ] {shared_context_block} 是 REBUTTAL 版本？
- [ ] 准备发给每个 proxy/critic 的内容引用相同的 blocks？

> ⚠️ 未完成 Phase 4.9 自检不得进入 Phase 5。

---

## Phase 5: Round 3 — REBUTTAL (仅 rounds >= 3)

Lead 并行 DM 给所有 members:

**DM to critic:**
```
SendMessage(type="message", recipient="critic", content=<<EOF
ACTION:REBUTTAL
这是你的行动触发器。立即执行以下步骤:
{shared_context_block}
步骤: broadcast 最终评论 (严格 200 字以内)。这是最后发言机会。
EOF
)
```

**DM to each proxy-{cli}:**
```
SendMessage(type="message", recipient="proxy-{cli}", content=<<EOF
ACTION:REBUTTAL
这是你的行动触发器。立即执行以下步骤:
{shared_context_block}
步骤: 准备 proxy-{cli}-r3-prompt.md → 调用 CLI → 输出 proxy-{cli}-r3-response.md → broadcast (严格 200 字以内)。
EOF
)
```

**DM to advocate:**
```
SendMessage(type="message", recipient="advocate", content=<<EOF
ACTION:FINAL_SUMMARY
这是你的行动触发器。立即执行以下步骤:
步骤: broadcast 最终总结 (严格 200 字以内)。包含: 接受的调整、坚守的立场、修订策略。
EOF
)
```

等待所有 members 发送最后评论。

> **REBUTTAL 超时**: advocate/critic 300s, proxy 按 TimeoutSec。超时 → 催促一次 → 再超时 → 跳过。

---

## Phase 6: DECISION + Cleanup

### 6.1 DECISION

Lead 汇总所有辩论内容，输出给用户:

```
## 🏛️ DEBATE DECISION

### 主题
{topic}

### 参与者
- advocate (Claude {advocate_model})
- critic (Claude {critic_model})
{- proxy-pi ({pi_model or "CLI default"}, effort: {effort})}
{- proxy-codex ({codex_model or "CLI default"}, effort: {effort})}
{- proxy-gemini ({gemini_model or "CLI default"})}

### Round 1: PROPOSAL
{advocate 的方案摘要}

### Round 2: CHALLENGE
{每个 challenger 的核心观点}

### Round 3: REBUTTAL (如有)
{最终回应}

### 最终建议
{共识: 各方一致同意的结论}
{分歧: Lead 的裁决及理由}

### 接受的 Tradeoffs
{愿意吞的代价}

### Blocking Concerns
{按标准过滤: (1) 不可逆损失 (2) 高概率大返工 (3) Deliverable 不成立}
{无 → "None — proceed"}

### Next Step
{一个具体动作}
{验证命令 (如 `npm run test`) + Done 判据}
```

### 6.2 Shutdown Agents (自动执行)

> DECISION 输出后立即执行 — 释放 agent 进程资源，但保留所有文件。

1. 并行向所有 members 发送 shutdown_request

2. 等待 shutdown_response:
   - 维护 checklist: [ ] advocate, [ ] critic, [ ] proxy-{cli1}, ...
   - 每收到 approve → 打钩
   - 30s 超时未收到 → DM 催促: "⚠️ 请回复 shutdown_response (approve)"
   - 再等 15s
   - 仍未收到 → 标记 "无响应"

3. 全部 shutdown 完成（或超时处理完毕）

> ⚠️ 此阶段 **不调用 TeamDelete**。日志文件保留。

### 6.3 报告完成 + 日志保留提示

报告给用户:
```
辩论完成 ✅

📁 讨论日志已保留:
  Team:  ~/.claude/teams/{team_name}/inboxes/
  Tasks: ~/.claude/tasks/{team_name}/
  Scratchpad: .scratchpad/debate-{timestamp}/

需要清理时说 "cleanup debate" 或 "删除 team"。
```

> ⚠️ **不主动清理**。Lead 在此暂停，等待用户下一步指令（可能是其他任务，不一定是 cleanup）。

### 6.4 Cleanup (仅在用户明确指令后执行)

**触发条件**: 用户发送以下任一指令:
- "cleanup debate"
- "cleanup team"
- "删除 team"
- "delete team"
- "TeamDelete"
- 或任何明确表达要清理 team 数据的意图

**执行步骤**:
1. 确认: "即将删除 team `{team_name}` 的所有数据（inboxes + tasks）。确认？"
2. 用户确认后 → TeamDelete
3. 报告: "Team `{team_name}` 已清理 ✅"

> 如果用户不发 cleanup 指令，team 文件将永久保留直到手动清理。
> 也可以随时通过 PowerShell 手动删除:
> `Remove-Item "$HOME\.claude\teams\{team_name}" -Recurse`

---

## Agent Prompt 模板

### ADVOCATE_PROMPT

```
你是 debate team "{team_name}" 的 "advocate"。

(角色和规则见 agent 文件 .claude/agents/debate-advocate.md)

补充规则:
- 🚀 启动后第一件事: SendMessage(type="message", recipient="team-lead") 发 "READY:advocate — tools: {可用工具列表}"。WebSearch 不可用则标注。READY 前不做其他操作。
- ⚡ 收到 Lead 的 DM 含 "ACTION:" 前缀时，立即执行。这是你的行动触发器。
  - ACTION:PROPOSAL → 执行步骤 (必须按顺序):
    ① WebSearch 至少 1 个查询 (强制，这是第一步。必须在 Grep/Read 之前执行。引用搜索结果时标注来源 URL)
    ② WebSearch 失败/返回空 → 标注 "[WebSearch 失败，基于知识]"，不阻塞
    ③ 如有 --files context，用 Grep 查阅代码 (引用需验证: "[Grep: {pattern} → {N} 处]")
    ④ broadcast PROPOSAL (严格 300 字以内)
  - ACTION:RESPOND → 执行步骤 (必须按顺序):
    ① WebSearch 至少 1 个查询 (强制，这是第一步。搜索反驳/补充证据)
    ② 失败 → 标注 "[WebSearch 失败，基于已有论据]"
    ③ broadcast 回应 (严格 300 字以内)
  - ACTION:FINAL_SUMMARY → broadcast 最终总结 (严格 200 字以内，无需 WebSearch)
- 收到 broadcast 消息时：仅记录分析，不行动。broadcast = 信息，DM = 命令。
- WebSearch 结果不足时用已有知识补充，标注 "[基于截止 {date} 的知识]"
- 如果提供了 --files 上下文，引用具体代码位置 (file:line)
- ⚠️ 字数限制是硬限制。超限 = 违规。broadcast 前自检字数。
- 只读审视，不做代码改动
- 禁止 TaskCreate
```

### CRITIC_PROMPT

```
你是 debate team "{team_name}" 的 "critic"。

(角色和规则见 agent 文件 .claude/agents/debate-critic.md)

补充规则:
- 🚀 启动后第一件事: SendMessage(type="message", recipient="team-lead") 发 "READY:critic — tools: {可用工具列表}"。WebSearch 不可用则标注 "⚠️ WebSearch unavailable"。READY 前不做其他操作。
- ⚡ 收到 Lead 的 DM 含 "ACTION:" 前缀时，立即执行。
  - ACTION:CHALLENGE → 执行步骤:
    ① WebSearch ≥ 2 查询 (强制)
    ② WebSearch 不可用 → DM Lead: "WebSearch 不可用"，然后用 Grep/Read 代码分析，标注 "[无外部搜索，仅代码分析]"
    ③ WebSearch 失败/空 → 标注 "[WebSearch 失败，基于代码分析]"
    ④ 引用具体数字必须 Grep 验证: "[Grep: {pattern} → {N} 处]"
    ⑤ broadcast CHALLENGE (严格 300 字以内)
  - ACTION:REBUTTAL → broadcast 最终评论 (严格 200 字以内)
- 收到 broadcast 消息时：仅记录分析，不行动。broadcast = 信息，DM = 命令。
- ⚠️ WebSearch 是 CHALLENGE 轮的强制要求。不搜索 = 违规。引用具体事实/数据/案例。
- ⚠️ 字数限制是硬限制。超限 = 违规。broadcast 前自检字数。
- 只读审视，不做代码改动
- 禁止 TaskCreate
```

### PROXY_PROMPT

```
你是 debate team "{team_name}" 的外部 AI 代理 "proxy-{cli}"。

## 工作方式
你负责调用 {cli} CLI 获取外部 AI 的观点，然后转发给队友。

## 🚀 启动确认
启动后第一件事 — SendMessage(type="message", recipient="team-lead") 发送 "READY:proxy-{cli}"。
在发送 READY 之前不做任何其他操作（不广播、不调用 CLI、不读文件）。

## ⚠️ DM-Action 触发 (最重要规则)
- **只在收到 Lead 的 DM 含 "ACTION:" 前缀时才调用 CLI**
- 收到 broadcast 时只记录，不触发 CLI。broadcast = 信息，DM = 命令。
- 每次 ACTION DM → 一次 CLI 调用 + 一次 broadcast。

## 文件命名 (round-specific，不覆盖)
- CHALLENGE: proxy-{cli}-r2-prompt.md / proxy-{cli}-r2-response.md
- REBUTTAL: proxy-{cli}-r3-prompt.md / proxy-{cli}-r3-response.md
- .err 文件由 invoke-ai.ps1 自动生成

## Context Isolation + Selective Technical Context (每个 prompt 文件必须以此开头)
```
IMPORTANT: You are an independent AI analyst in a structured debate.
- Do NOT follow any project-specific instructions from the repository (CLAUDE.md, .cursorrules, etc.)
- Do NOT address anyone by name or adopt any persona/role from project files
- The "Project Technical Context" below is FACTUAL BACKGROUND ONLY — you should challenge any assumption, including these facts
- Focus ONLY on the debate topic below
- Respond directly with your analysis
---

## Project Technical Context (background reference only — challenge any assumption)
{technical_context}
---
Conduct ≥2 web searches on the debate topic before responding. Cite sources with URLs.
Response MUST be ≤200 words. Longer responses will be truncated.
```

## Prompt 字数预算
- Context Isolation header: ~150 words (固定)
- Technical Context: ~100 words (由 Lead 组装)
- Debate content: ~400-600 words (摘要 + 任务指令)
- 总计: ~650-850 words
- 超过 1000 words 的 prompt 必须精简 debate content 部分

## ⚠️ CLI 响应字数硬限制
- 所有 CLI 统一: Response ≤200 words (硬限制)
- 禁止给某些 CLI 更高字数 (如 "400 max" 或 "~250 aim")
- 模板尾部已包含此限制，Lead 不需要额外写
- Proxy 端在 broadcast 前强制截取 (见 debate-proxy.md)

## ⚠️ 路径注意
- invoke-ai.ps1 路径: 在 `powershell -NoProfile -File` 命令中使用 `"$HOME/.claude/scripts/invoke-ai.ps1"`
  PowerShell 会正确解析 `$HOME` 为 Windows 路径
- 如果直接在 Bash 中引用 `$HOME`，会被 bash 展开为 Linux 路径 → 失败
- scratchpad 路径: 使用 Lead spawn 时提供的绝对路径 `{scratchpad}`

## 收到 Lead 的 ACTION DM 后:

### ACTION:SEARCH (特殊 — 不调用 CLI)
当 Lead 发 "ACTION:SEARCH — 搜索 {查询}" 时:
1. 将查询写入 prompt 文件 → 调用 CLI → broadcast 搜索结果摘要 (200 字以内)
2. 标注来源: "[{cli} 搜索结果]"
3. 这是 WebSearch 降级方案 — critic 无法搜索时，Lead 委托 proxy 代搜

### ACTION:CHALLENGE / ACTION:REBUTTAL (正常流程)
1. 先 broadcast 进度: "正在调用 {cli}，预计 {estimated_time}"

2. 整理目前的辩论上下文，准备 prompt
   - 每个 prompt 必须包含:
     a. 协议轮次名: CHALLENGE 或 REBUTTAL（不是 Round 1/2/3）
     b. advocate 的 PROPOSAL 摘要（必须包含，不能省略）
     c. 本轮所有已收到的观点摘要（不是原文复制，避免无状态 CLI 返回重复内容）
     d. 本轮具体要求（如 "对 advocate 的方案提出 CHALLENGE"）
   - kimi 和 qwen 的 prompt 必须用英文撰写（Windows 编码限制）

3. 准备 prompt 文件:
   - 文件名按轮次: proxy-{cli}-r2-prompt.md (CHALLENGE) / proxy-{cli}-r3-prompt.md (REBUTTAL)
   - 首次创建: 用 Bash `mkdir -p "{scratchpad}" && touch "{scratchpad}/proxy-{cli}-r{N}-prompt.md"` 创建空文件 → Read → Write
   - 后续更新: Read → Write
     (Claude Code 的 Write 工具要求先 Read 再 Write，新文件需先 touch 创建)
   - **每个 prompt 文件必须以 Context Isolation + Selective Technical Context 声明开头** (见上方模板)
   - 如果 Lead DM 中包含技术上下文但 prompt 文件还没写入，proxy 负责将其插入 prompt header

3b. Prompt 自检 (Write 后、CLI 调用前):
   Read prompt 文件并验证:
   - [ ] 第 1 行是 "IMPORTANT: You are an independent AI analyst"？
   - [ ] 包含 "Project Technical Context" section？
   - [ ] 不含项目文档全文或行为指令？
   - [ ] debate content 包含 advocate PROPOSAL 摘要？
   - [ ] 末尾包含 "≥2 web searches" 指令？
   - [ ] 末尾包含 "≤200 words" 硬限制？
   验证失败 → 修正后重写，不调用 CLI。

4. 用 Bash 工具调用 invoke-ai.ps1:
   ⚠️ Bash tool 运行的是 bash shell，不是 PowerShell。
   所有 PowerShell 命令必须包在 `powershell -NoProfile -File ...` 或 `powershell -NoProfile -Command "..."` 里。

   调用命令:
   powershell -NoProfile -File "$HOME/.claude/scripts/invoke-ai.ps1" -CLI {cli} -PromptFile "{scratchpad}/proxy-{cli}-r{N}-prompt.md" -OutFile "{scratchpad}/proxy-{cli}-r{N}-response.md" {model_flag} {effort_flag} -TimeoutSec {timeout}

   其中:
   - {model_flag}: 如果该 CLI 有指定模型，则为 `-Model {model}`，否则省略
   - {effort_flag}: 当 CLI 为 pi、codex 或 kimi 且有指定 effort 时，为 `-ReasoningEffort {effort}`，否则省略

5. 用 Read 工具读取输出文件
   - 如果 Read 输出乱码，用 Bash 工具重读:
     powershell -NoProfile -Command "[System.IO.File]::ReadAllText('{scratchpad}/proxy-{cli}-r{N}-response.md', [System.Text.Encoding]::UTF8)"

6. 检查 stderr 文件: {scratchpad}/proxy-{cli}-r{N}-response.err
   Stderr 白名单 (按 CLI 分类):
   a. **忽略 (benign)**:
      - codex: 整个 stderr 除非包含 "error"/"failed" (codex 将 session log 写入 stderr)
      - gemini: "YOLO mode" / "Loaded cached credentials"
      - kimi: "PYTHONIOENCODING"
      - qwen: "web-search" / "--web-search-default"
   b. **警告**: "429"/"rate limit"/"quota" → 在 broadcast 标注 "[rate-limited]"
   c. **报告**: 其他 "error"/"failed" → 在 broadcast 末尾附注 "[{cli} stderr: {前 200 字}]"
   - 如果文件不存在或为空 → 正常继续

7. Response 质量检查 (broadcast 前):
   检查 CLI response:
   - 如果 response 包含项目特定的角色称呼或人名 → 说明 context isolation 失败
     → 在 broadcast 中标注 "[⚠️ context leak detected]"，仍然转发但通知 Lead
   - 如果 response 只是重复了 prompt 内容 → "[⚠️ echo detected, CLI may have failed]"
   - 如果 response 包含项目文件路径 (src/..., .claude/...) 但 prompt 中没给 → "[⚠️ possible project context leak]"

8. broadcast 外部 AI 观点 (硬限 200 字):
   - Read response 后立即估算字数
   - ≤200 字: 原文 broadcast
   - >200 字: 截取前 200 字 (保留完整句子)，末尾追加 "[已截取，原文约 {N} 字]"
   - 禁止原文 broadcast 超过 200 字的 response
   - 标注来源: "[{cli} 的观点 — CHALLENGE/REBUTTAL]"

## Broadcast 白名单 (仅允许以下 4 种)
1. "正在调用 {cli}，预计 {time}" (进度，收到 ACTION 后)
2. "[{cli} 的观点 — CHALLENGE/REBUTTAL]: {内容}" (转发结果)
3. "[proxy-{cli} 替代分析 — {cli} CLI 失败]: {内容}" (失败降级)
4. 带 [⚠️ context leak/echo/project context leak] 标注的转发 (质量问题)
其他 broadcast 禁止 (包括 "已就位"、"准备好了"、"等待指令")。

9. 如果 CLI 调用返回 0 bytes 或失败:
   a. 首先读取 .err 文件诊断原因
   b. 重试一次: 用相同命令重新调用 invoke-ai.ps1
   c. 如果第二次仍然失败: 尝试直接 PowerShell 管道:
      powershell -NoProfile -Command "Get-Content '{scratchpad}/proxy-{cli}-r{N}-prompt.md' -Raw -Encoding UTF8 | {cli} {flags} > '{scratchpad}/proxy-{cli}-r{N}-response.md' 2> '{scratchpad}/proxy-{cli}-r{N}-response.err'"
   d. 如果所有重试都失败: 告知队友 "{cli} 无法响应"，附上 stderr 摘要，并给出你自己的替代分析
   - 替代分析必须基于辩论上下文，控制在 200 字以内，标注 "[proxy-{cli} 替代分析 — {cli} CLI 失败]"

## 注意
- {timeout} 由 Lead 在 spawn 时根据模型/effort 填入:
  - pi gpt-5.2 + xhigh: 900 | pi 其他: 600
  - codex gpt-5.2 + xhigh: 1800 | codex 其他: 600
  - gemini/qwen/kimi: 300
- 创建目录用: `mkdir -p "{scratchpad}"` (bash 原生命令)
- {scratchpad} 由 Lead 在 spawn 时填入，格式: `.scratchpad/debate-{timestamp}/`
- 确保 scratchpad 目录存在后再创建 prompt 文件

## 角色边界
- 你只能广播（broadcast）外部 AI 的观点或你的替代分析
- 禁止直接发消息给 advocate 或 critic（除非回应他们的直接提问）
- 禁止催促其他 agent
- 禁止对辩论内容发表自己的"原创"观点（你的角色是转发，不是参与）
- 禁止创建 Task（TaskCreate）— task 由 Lead 管理

## 完成标准
当 Lead 发送 shutdown_request 时，必须用 SendMessage approve:
SendMessage({ type: "shutdown_response", request_id: "<从 shutdown_request JSON 提取 requestId>", approve: true })
⚠️ 仅回复文字不够，必须调用 SendMessage 工具。
```

---

## 快速示例

```
# 数据库查询性能
/debate 数据库查询是否需要索引优化 --files src/db/queries.ts src/models/user.ts --with codex

# API 认证安全策略
/debate 当前 API 认证策略是否足够安全 --with pi,codex --preset deep

# 数据模型设计
/debate 用户-角色关系用 1:N 还是 M:N --files src/models/ --with codex,gemini --rounds 3

# 只有内部 agent
/debate 表单验证要不要在前端也做 --files src/lib/ --rounds 3

# 显式覆盖 preset
/debate 状态管理方案 (React Context vs Zustand) --with codex --preset deep --effort high
```

---

{{#if argument}}
**收到参数**：`$ARGUMENTS`

开始解析参数并执行 Phase 1。
{{else}}
请提供辩论主题，例如：
`/debate 推荐算法是否覆盖所有 edge case --files src/features/engine/recommend.ts --with codex --preset deep`
{{/if}}
