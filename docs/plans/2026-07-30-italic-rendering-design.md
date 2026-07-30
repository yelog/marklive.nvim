# Italic Rendering Design

## Goal

Render Markdown emphasis written as `_text_` or `*text*` with the
`markdownItalic` highlight group, without styling inline or fenced code.

## Approach

Use the Markdown Tree-sitter parser to capture emphasis nodes instead of
matching emphasis with line regular expressions. For each capture, conceal the
opening and closing delimiters and apply `markdownItalic` directly to the
content range. This makes the configured yellow italic style independent of
Neovim's syntax-highlighting implementation.

## Boundaries

Tree-sitter determines whether text is emphasis. Its grammar excludes code
nodes, escaped punctuation, and other non-emphasis Markdown contexts, so the
renderer will not apply italic styling to those ranges.

## Verification

Add deterministic tests for both delimiter forms at line boundaries and in
prose, plus inline-code and fenced-code cases that must remain unstyled.
