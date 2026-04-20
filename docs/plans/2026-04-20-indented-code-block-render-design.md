# Indented Code Block Render Design

## Context

The reported input is parsed by Tree-sitter as a paragraph followed by an `indented_code_block`, not as a Markdown list. `render.code_block` currently assumes every code block is fenced, so it hides the first and last rows when the cursor is not on them. For indented code blocks, those rows are real content, which makes the first and last lines disappear.

## Decision

Keep strict Markdown behavior.

- Valid lists continue to use the existing list renderer.
- Indented code blocks should render as code blocks, but all content lines must remain visible.
- Only fenced code blocks should use the current top/bottom fence overlay behavior and language label rendering.

## Implementation

Update `render.code_block` to detect whether the block is fenced by checking the first line for a triple-backtick fence.

- Fenced code blocks keep the current behavior.
- Indented code blocks render every line with background highlight only.
- No full-line overlay should be applied to the first or last line of an indented code block.

## Verification

- Reproduce with the reported sample and confirm the first and last indented lines no longer disappear.
- Re-check fenced code blocks to confirm the fence overlay and language label still work.
