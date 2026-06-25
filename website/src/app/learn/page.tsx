import fs from "node:fs";
import path from "node:path";
import type { Metadata } from "next";
import Link from "next/link";
import { BookOpen, Github } from "lucide-react";
import { SiteNav } from "../components/SiteNav";

export const metadata: Metadata = {
  title: "CAOCAP Codebase Learning Book",
  description:
    "A guided book for understanding CAOCAP's SwiftUI app, spatial canvas, project store, live preview runtime, and CoCaptain agent flow."
};

type Block =
  | { type: "heading"; level: number; text: string; id: string }
  | { type: "paragraph"; text: string }
  | { type: "list"; items: string[] }
  | { type: "code"; code: string }
  | { type: "table"; rows: string[][] }
  | { type: "rule" };

type Heading = Extract<Block, { type: "heading" }>;

const githubBookUrl =
  "https://github.com/Azzam-Alrashed/CAOCAP/blob/main/docs/caocap-codebase-learning-book.md";

function slugify(text: string) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-");
}

function inlineText(text: string) {
  const parts = text.split(/(`[^`]+`|\*\*[^*]+\*\*)/g);

  return parts.map((part, index) => {
    if (part.startsWith("`") && part.endsWith("`")) {
      return <code key={`${part}-${index}`}>{part.slice(1, -1)}</code>;
    }

    if (part.startsWith("**") && part.endsWith("**")) {
      return <strong key={`${part}-${index}`}>{part.slice(2, -2)}</strong>;
    }

    return part;
  });
}

function readBook() {
  return fs.readFileSync(
    path.join(process.cwd(), "..", "docs", "caocap-codebase-learning-book.md"),
    "utf8"
  );
}

function parseMarkdown(markdown: string): { blocks: Block[]; headings: Heading[] } {
  const lines = markdown.split(/\r?\n/);
  const blocks: Block[] = [];
  const headings: Heading[] = [];
  let index = 0;

  while (index < lines.length) {
    const line = lines[index];
    const trimmed = line.trim();

    if (!trimmed) {
      index += 1;
      continue;
    }

    if (trimmed === "---") {
      blocks.push({ type: "rule" });
      index += 1;
      continue;
    }

    if (trimmed.startsWith("```")) {
      index += 1;
      const codeLines: string[] = [];
      while (index < lines.length && !lines[index].trim().startsWith("```")) {
        codeLines.push(lines[index]);
        index += 1;
      }
      blocks.push({ type: "code", code: codeLines.join("\n") });
      index += 1;
      continue;
    }

    if (trimmed.startsWith("#")) {
      const match = trimmed.match(/^(#{1,3})\s+(.+)$/);
      if (match) {
        const level = match[1].length;
        const text = match[2];
        const id = slugify(text);
        const heading = { type: "heading" as const, level, text, id };
        blocks.push(heading);
        if (level <= 2 || text.startsWith("Chapter") || text.startsWith("Appendix")) {
          headings.push(heading);
        }
        index += 1;
        continue;
      }
    }

    if (trimmed.startsWith("|")) {
      const rows: string[][] = [];
      while (index < lines.length && lines[index].trim().startsWith("|")) {
        const current = lines[index].trim();
        const cells = current
          .slice(1, -1)
          .split("|")
          .map((cell) => cell.trim());
        const isDivider = cells.every((cell) => /^:?-{3,}:?$/.test(cell));
        if (!isDivider) {
          rows.push(cells);
        }
        index += 1;
      }
      blocks.push({ type: "table", rows });
      continue;
    }

    if (trimmed.startsWith("- ")) {
      const items: string[] = [];
      while (index < lines.length && lines[index].trim().startsWith("- ")) {
        items.push(lines[index].trim().slice(2));
        index += 1;
      }
      blocks.push({ type: "list", items });
      continue;
    }

    const paragraph: string[] = [trimmed];
    index += 1;
    while (
      index < lines.length &&
      lines[index].trim() &&
      !lines[index].trim().startsWith("#") &&
      !lines[index].trim().startsWith("- ") &&
      !lines[index].trim().startsWith("|") &&
      !lines[index].trim().startsWith("```") &&
      lines[index].trim() !== "---"
    ) {
      paragraph.push(lines[index].trim());
      index += 1;
    }
    blocks.push({ type: "paragraph", text: paragraph.join(" ") });
  }

  return { blocks, headings };
}

function BookBlock({ block }: { block: Block }) {
  switch (block.type) {
    case "heading": {
      const HeadingTag = `h${Math.min(block.level, 3)}` as "h1" | "h2" | "h3";
      return (
        <HeadingTag id={block.id} className={`book-heading level-${block.level}`}>
          {block.text}
        </HeadingTag>
      );
    }
    case "paragraph":
      return <p>{inlineText(block.text)}</p>;
    case "list":
      return (
        <ul>
          {block.items.map((item) => (
            <li key={item}>{inlineText(item)}</li>
          ))}
        </ul>
      );
    case "code":
      return (
        <pre>
          <code>{block.code}</code>
        </pre>
      );
    case "table":
      return (
        <div className="book-table-wrap">
          <table>
            <tbody>
              {block.rows.map((row, rowIndex) => (
                <tr key={`${row.join("-")}-${rowIndex}`}>
                  {row.map((cell, cellIndex) => {
                    const Cell = rowIndex === 0 ? "th" : "td";
                    return <Cell key={`${cell}-${cellIndex}`}>{inlineText(cell)}</Cell>;
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    case "rule":
      return <hr />;
  }
}

export default function LearnPage() {
  const { blocks, headings } = parseMarkdown(readBook());
  const titleBlock = blocks[0]?.type === "heading" ? blocks[0] : null;
  const contentBlocks = titleBlock ? blocks.slice(1) : blocks;
  const chapterLinks = headings.filter(
    (heading) => heading.text.startsWith("Chapter") || heading.text.startsWith("Appendix")
  );

  return (
    <main className="book-page">
      <SiteNav showContribute={false} />

      <section className="book-hero">
        <div className="book-hero-icon">
          <BookOpen aria-hidden="true" size={30} />
        </div>
        <p className="eyebrow">Codebase guide</p>
        <h1>{titleBlock?.text ?? "The CAOCAP Codebase Learning Book"}</h1>
        <p>
          A guided path through the SwiftUI app shell, spatial canvas, project
          store, live preview runtime, and CoCaptain agent flow.
        </p>
        <div className="book-actions">
          <a href={githubBookUrl} target="_blank" rel="noreferrer">
            <Github aria-hidden="true" size={18} />
            View source
          </a>
          <Link href="#chapter-1-big-picture-what-caocap-is">Start reading</Link>
        </div>
      </section>

      <div className="book-layout">
        <aside className="book-toc" aria-label="Book contents">
          <strong>Contents</strong>
          <nav>
            {chapterLinks.map((heading) => (
              <Link key={heading.id} href={`#${heading.id}`}>
                {heading.text}
              </Link>
            ))}
          </nav>
        </aside>

        <article className="book-content">
          {contentBlocks.map((block, index) => (
            <BookBlock block={block} key={`${block.type}-${index}`} />
          ))}
        </article>
      </div>
    </main>
  );
}
