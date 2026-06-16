/**
 * Markdown pre-processor.
 *
 * CommonMark requires fenced code blocks inside list items to be indented to
 * the list item's content column, otherwise the fence breaks out of the list
 * and renders as plain text with visible backticks. STIG authors write natural
 * markdown with zero-indent fences, so this normalizes the source before it
 * reaches any CommonMark parser (marked, markdown-it, ...). Parser-agnostic by
 * design: we re-indent the input, we do not fork the renderer.
 */

const FENCE_RE = /^( *)(`{3,}|~{3,})(.*)$/;
const ORDERED_RE = /^( *)(\d+)([.)])( +)(.*)$/;
const UNORDERED_RE = /^( *)([-*+])( +)(.*)$/;
const BLANK_RE = /^\s*$/;
const INDENT_PER_LEVEL = 4;

// Track the open list items as a stack so fence indentation reflects real
// nesting depth rather than guessing from a single line.
function updateListStack(stack, lead, content) {
  while (stack.length && lead < stack[stack.length - 1].lead) stack.pop();
  if (stack.length === 0) {
    stack.push({ lead, content });
    return;
  }
  const top = stack[stack.length - 1];
  if (lead >= top.content) {
    stack.push({ lead, content }); // indented past the marker -> deeper level
  } else {
    top.lead = lead; // sibling at the current level
    top.content = content;
  }
}

// Copy a fence body verbatim (only adding `pad`) until the matching close, so
// list markers or fences inside the code block are never reinterpreted.
function copyFenceBody(lines, start, result, fenceMarker, pad) {
  const closeRe = fenceMarker[0] === "~" ? /^ *~{3,} *$/ : /^ *`{3,} *$/;
  let i = start;
  while (i < lines.length) {
    const line = lines[i];
    result.push(pad + line);
    i += 1;
    if (closeRe.test(line)) break;
  }
  return i;
}

export function normalizeListFences(markdown) {
  if (typeof markdown !== "string" || markdown === "") return "";

  const lines = markdown.split("\n");
  const result = [];
  const stack = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    const fenceM = line.match(FENCE_RE);
    if (fenceM) {
      const level = stack.length;
      const required = level * INDENT_PER_LEVEL;
      const currentIndent = fenceM[1].length;
      const pad =
        level === 0 || currentIndent >= required ? "" : " ".repeat(required - currentIndent);
      result.push(pad + line);
      i = copyFenceBody(lines, i + 1, result, fenceM[2], pad);
      continue;
    }

    if (BLANK_RE.test(line)) {
      result.push(line);
      i += 1;
      continue;
    }

    const orderedM = line.match(ORDERED_RE);
    const unorderedM = orderedM ? null : line.match(UNORDERED_RE);
    if (orderedM || unorderedM) {
      const m = orderedM || unorderedM;
      const lead = m[1].length;
      const content = orderedM
        ? lead + orderedM[2].length + orderedM[3].length + orderedM[4].length
        : lead + 1 + unorderedM[3].length;
      updateListStack(stack, lead, content);
      result.push(line);
      i += 1;
      continue;
    }

    // Plain text dedented to the left of the outermost list content closes the
    // list; subsequent fences are then root-level and pass through unchanged.
    const lead = (line.match(/^ */) || [""])[0].length;
    if (stack.length && lead < stack[0].content) stack.length = 0;
    result.push(line);
    i += 1;
  }

  return result.join("\n");
}
