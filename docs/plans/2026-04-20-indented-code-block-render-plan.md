# Indented Code Block Render Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep indented code block lines visible while preserving existing fenced code block rendering.

**Architecture:** Detect fenced code blocks inside `render.code_block` from the first line. Keep the current fence overlay path for fenced blocks, and use a simpler background-only path for indented code blocks so content lines are never mistaken for fences.

**Tech Stack:** Lua, Neovim extmarks, Tree-sitter markdown nodes, vusted/headless Neovim verification.

---

### Task 1: Split fenced and indented code block rendering

**Files:**
- Modify: `lua/marklive/render.lua`

**Step 1: Add a fenced block check**

Detect triple-backtick fences from the first line inside `render.code_block` and branch rendering logic from that boolean.

**Step 2: Keep fenced code block behavior unchanged**

Preserve the existing first-line overlay, last-line overlay, language label, and content background behavior for fenced blocks.

**Step 3: Add indented code block path**

Render every line of an indented code block with background highlighting only, without hiding the first or last line.

### Task 2: Verify regression coverage manually

**Files:**
- Modify: `lua/marklive/render.lua`
- Reference: `docs/plans/2026-04-20-indented-code-block-render-design.md`

**Step 1: Verify the reported sample**

Run a headless Neovim script with the reported sample and confirm the first and last indented lines no longer receive full-line overlay extmarks.

**Step 2: Verify fenced block behavior**

Run a second headless Neovim script with a fenced code block and confirm the fence overlay extmarks still exist.
