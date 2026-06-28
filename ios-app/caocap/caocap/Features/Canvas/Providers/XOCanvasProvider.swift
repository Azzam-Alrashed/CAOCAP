import CoreGraphics
import Foundation

/// A self-contained touch-first tic-tac-toe Mini-App used as a ready-to-run example.
public enum XOCanvasProvider {
    public static let miniAppNodeID = UUID(uuidString: "CA0CA002-0000-4000-8000-000000000002")!

    public static var snapshot: ProjectSnapshot {
        ProjectSnapshot(
            projectName: "XO",
            nodes: [
                SpatialNode(
                    id: miniAppNodeID,
                    type: .miniApp,
                    position: .zero,
                    title: "XO",
                    subtitle: "Tap to play",
                    icon: "square.grid.3x3.fill",
                    theme: .secondary,
                    miniApp: MiniAppState(
                        srsText: srs,
                        srsReadinessState: .implementationReady,
                        codeText: code
                    )
                )
            ],
            viewportOffset: .zero,
            viewportScale: 0.8
        )
    }

    public static let srs = """
    # XO

    ## Goal
    Get three marks in a row before your opponent.

    ## Controls
    - Tap an empty cell to place your mark.
    - Play against a friend on the same device or switch to solo mode against the CPU.
    - Restart anytime with the button below the board.

    ## Mobile requirements
    The game must fit iPhone and iPad screens, respect safe areas, prevent browser
    gestures during play, and use touch targets of at least 44 points.
    """

    public static let code = #"""
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
      <title>XO</title>
      <style>
        :root { color-scheme: dark; --x:#5ee1ff; --o:#ff7ab8; --line:#ffffff2a; }
        * { box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
        html,body { width:100%; height:100%; margin:0; overflow:hidden; overscroll-behavior:none; }
        body {
          background:radial-gradient(circle at 50% 18%,#1a1f3d,#06060f 68%);
          color:white; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
          touch-action:none; user-select:none; -webkit-user-select:none;
        }
        main {
          height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center;
          gap:14px; padding:max(10px,env(safe-area-inset-top)) max(12px,env(safe-area-inset-right))
            max(10px,env(safe-area-inset-bottom)) max(12px,env(safe-area-inset-left));
        }
        header { width:min(92vw,360px); display:flex; align-items:center; justify-content:space-between; gap:10px; }
        h1 { margin:0; font-size:clamp(22px,6vw,34px); letter-spacing:4px; }
        .status { font-weight:800; font-size:14px; color:#d8dcff; text-align:right; }
        #board {
          display:grid; grid-template-columns:repeat(3,1fr); gap:10px;
          width:min(92vw,360px); aspect-ratio:1; padding:12px;
          background:#0b0f22; border:2px solid #3a46a8; border-radius:18px;
          box-shadow:0 0 28px #2f3fff44;
        }
        .cell {
          min-width:44px; min-height:44px; border:1px solid var(--line); border-radius:16px;
          background:linear-gradient(#171c34,#101528); font-size:clamp(42px,12vw,64px); font-weight:900;
          color:white; touch-action:none; display:flex; align-items:center; justify-content:center;
        }
        .cell:disabled { opacity:1; }
        .cell.x { color:var(--x); text-shadow:0 0 18px #5ee1ff88; }
        .cell.o { color:var(--o); text-shadow:0 0 18px #ff7ab888; }
        .cell.win { background:linear-gradient(#24305f,#1a2448); border-color:#ffffff55; }
        .panel { display:flex; flex-wrap:wrap; gap:8px; justify-content:center; width:min(92vw,360px); }
        button.action {
          min-height:44px; padding:0 18px; border:1px solid #ffffff35; border-radius:14px;
          background:linear-gradient(#34345b,#1a1a31); color:white; font-size:14px; font-weight:800;
          touch-action:none;
        }
        button.action.active { background:#4b4b88; border-color:#ffffff66; }
        button.action:active { transform:scale(.96); }
      </style>
    </head>
    <body>
      <main>
        <header>
          <h1>XO</h1>
          <p class="status" id="status" aria-live="polite">X starts</p>
        </header>
        <div id="board" role="grid" aria-label="Tic-tac-toe board"></div>
        <div class="panel">
          <button class="action active" id="mode-two" type="button">2 Players</button>
          <button class="action" id="mode-cpu" type="button">Vs CPU</button>
          <button class="action" id="restart" type="button">Restart</button>
        </div>
      </main>
      <script>
      (() => {
        "use strict";
        const boardEl = document.querySelector("#board");
        const statusEl = document.querySelector("#status");
        const lines = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
        let cells = Array(9).fill("");
        let turn = "X";
        let over = false;
        let vsCPU = false;

        function render() {
          boardEl.innerHTML = "";
          cells.forEach((mark, index) => {
            const button = document.createElement("button");
            button.type = "button";
            button.className = "cell" + (mark ? " " + mark.toLowerCase() : "");
            button.textContent = mark;
            button.disabled = over || mark !== "";
            button.setAttribute("role", "gridcell");
            button.setAttribute("aria-label", mark ? `Cell ${index + 1}, ${mark}` : `Empty cell ${index + 1}`);
            button.addEventListener("pointerdown", (event) => {
              event.preventDefault();
              play(index);
            });
            boardEl.appendChild(button);
          });
        }

        function winner(board) {
          for (const [a,b,c] of lines) {
            if (board[a] && board[a] === board[b] && board[b] === board[c]) {
              return { player: board[a], line: [a,b,c] };
            }
          }
          return board.every(Boolean) ? { player: null, line: [] } : null;
        }

        function setStatus(text) { statusEl.textContent = text; }

        function highlight(line) {
          boardEl.querySelectorAll(".cell").forEach((cell, index) => {
            if (line.includes(index)) cell.classList.add("win");
          });
        }

        function endGame(result) {
          over = true;
          if (!result) { setStatus("Draw"); return; }
          if (!result.player) { setStatus("Draw"); return; }
          highlight(result.line);
          setStatus(`${result.player} wins`);
        }

        function play(index) {
          if (over || cells[index]) return;
          cells[index] = turn;
          const result = winner(cells);
          if (result) { render(); endGame(result); return; }
          turn = turn === "X" ? "O" : "X";
          render();
          setStatus(`${turn}'s turn`);
          if (vsCPU && !over && turn === "O") {
            window.setTimeout(cpuMove, 260);
          }
        }

        function cpuMove() {
          if (over) return;
          const empties = cells.map((v,i) => v ? null : i).filter(v => v !== null);
          const pick = (predicate) => {
            for (const line of lines) {
              const marks = line.map(i => cells[i]);
              const target = predicate(marks, line);
              if (target !== null) return target;
            }
            return null;
          };
          let move = pick((marks,line) => marks.filter(m => m === "O").length === 2 && marks.includes("") ? line[marks.indexOf("")] : null);
          move ??= pick((marks,line) => marks.filter(m => m === "X").length === 2 && marks.includes("") ? line[marks.indexOf("")] : null);
          move ??= (cells[4] === "" ? 4 : null);
          move ??= empties[Math.floor(Math.random() * empties.length)];
          if (move !== null) play(move);
        }

        function reset() {
          cells = Array(9).fill("");
          turn = "X";
          over = false;
          setStatus("X starts");
          render();
        }

        document.querySelector("#restart").addEventListener("pointerdown", (event) => {
          event.preventDefault();
          reset();
        });
        document.querySelector("#mode-two").addEventListener("pointerdown", (event) => {
          event.preventDefault();
          vsCPU = false;
          document.querySelector("#mode-two").classList.add("active");
          document.querySelector("#mode-cpu").classList.remove("active");
          reset();
        });
        document.querySelector("#mode-cpu").addEventListener("pointerdown", (event) => {
          event.preventDefault();
          vsCPU = true;
          document.querySelector("#mode-cpu").classList.add("active");
          document.querySelector("#mode-two").classList.remove("active");
          reset();
        });

        reset();
      })();
      </script>
    </body>
    </html>
    """#
}
