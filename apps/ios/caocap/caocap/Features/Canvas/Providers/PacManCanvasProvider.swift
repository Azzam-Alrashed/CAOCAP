import CoreGraphics
import Foundation

/// A self-contained touch-first Pac-Man Mini-App used as a ready-to-run example.
public enum PacManCanvasProvider {
    public static let miniAppNodeID = UUID(uuidString: "CA0CA002-0000-4000-8000-000000000001")!

    public static var snapshot: ProjectSnapshot {
        ProjectSnapshot(
            projectName: "Pac-Man",
            nodes: [
                SpatialNode(
                    id: miniAppNodeID,
                    type: .miniApp,
                    position: .zero,
                    title: "Pac-Man",
                    subtitle: "Tap to play",
                    icon: "gamecontroller.fill",
                    theme: .purple,
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
    # Pac-Man

    ## Goal
    Clear the maze by eating every dot while avoiding the ghosts.

    ## Controls
    - Swipe on the maze or use the large directional pad on a touch screen.
    - Use Arrow keys or WASD with a hardware keyboard.
    - Pause or restart with the buttons below the maze.

    ## Mobile requirements
    The game must fit iPhone and iPad screens in either orientation, respect safe
    areas, prevent browser gestures during play, and use touch targets of at least
    44 points.
    """

    public static let code = #"""
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
      <title>Pac-Man</title>
      <style>
        :root { color-scheme: dark; --yellow:#ffd900; --blue:#2458ff; }
        * { box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
        html,body { width:100%; height:100%; margin:0; overflow:hidden; overscroll-behavior:none; }
        body {
          background:radial-gradient(circle at 50% 20%,#171738,#05050d 65%);
          color:white; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
          touch-action:none; user-select:none; -webkit-user-select:none;
        }
        main {
          height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center;
          gap:8px; padding:max(8px,env(safe-area-inset-top)) max(10px,env(safe-area-inset-right))
            max(8px,env(safe-area-inset-bottom)) max(10px,env(safe-area-inset-left));
        }
        header { width:min(94vw,520px); display:flex; align-items:center; justify-content:space-between; gap:10px; }
        h1 { margin:0; color:var(--yellow); font-size:clamp(18px,5vw,28px); letter-spacing:1px; }
        .stats { display:flex; gap:12px; font-weight:800; font-variant-numeric:tabular-nums; font-size:14px; }
        #game {
          display:block; background:#02020a; border:2px solid #3434a8; border-radius:12px;
          box-shadow:0 0 28px #3030ff55; touch-action:none;
          width:auto; height:auto; max-width:min(94vw,520px); max-height:min(62vh,610px);
        }
        #message {
          min-height:20px; margin:0; color:#d9d9ff; text-align:center; font-size:13px; font-weight:700;
        }
        .controls { display:grid; grid-template-columns:repeat(3,56px); grid-template-rows:repeat(2,52px); gap:6px; }
        .dir,.action {
          min-width:44px; min-height:44px; border:1px solid #ffffff35; color:white;
          background:linear-gradient(#34345b,#1a1a31); border-radius:14px; font-size:24px; font-weight:900;
          touch-action:none; box-shadow:inset 0 1px #ffffff25,0 4px 12px #0008;
        }
        .dir:active,.dir.active,.action:active { transform:scale(.94); background:#4b4b88; }
        [data-dir=up]{grid-column:2;grid-row:1}[data-dir=left]{grid-column:1;grid-row:2}
        [data-dir=down]{grid-column:2;grid-row:2}[data-dir=right]{grid-column:3;grid-row:2}
        .actions { display:flex; gap:8px; }
        .action { padding:0 16px; font-size:14px; }
        @media (orientation:landscape) and (max-height:600px) {
          main { display:grid; grid-template-columns:minmax(260px,1fr) 190px; grid-template-rows:auto 1fr; }
          header { grid-column:1; width:min(68vw,520px); justify-self:center; }
          #game { grid-column:1; grid-row:2; max-width:min(68vw,520px); max-height:78vh; justify-self:center; }
          .panel { grid-column:2; grid-row:1/3; align-self:center; display:flex; flex-direction:column; align-items:center; gap:10px; }
        }
      </style>
    </head>
    <body>
      <main>
        <header><h1>PAC-MAN</h1><div class="stats"><span>SCORE <b id="score">0</b></span><span>LIVES <b id="lives">3</b></span></div></header>
        <canvas id="game" aria-label="Pac-Man maze"></canvas>
        <section class="panel">
          <p id="message" aria-live="polite">Swipe or use the controls</p>
          <div class="controls" aria-label="Direction controls">
            <button class="dir" data-dir="up" aria-label="Move up">▲</button>
            <button class="dir" data-dir="left" aria-label="Move left">◀</button>
            <button class="dir" data-dir="down" aria-label="Move down">▼</button>
            <button class="dir" data-dir="right" aria-label="Move right">▶</button>
          </div>
          <div class="actions">
            <button class="action" id="pause">Pause</button>
            <button class="action" id="restart">Restart</button>
          </div>
        </section>
      </main>
      <script>
      (() => {
        "use strict";
        const MAP = [
          "#################",
          "#.......#.......#",
          "#.###.#.#.#.###.#",
          "#o###.#.#.#.###o#",
          "#...............#",
          "#.###.#####.###.#",
          "#.....#...#.....#",
          "#####.#.#.#.#####",
          "    #.#...#.#    ",
          "#####.#---#.#####",
          "     . --- .     ",
          "#####.#---#.#####",
          "    #.#...#.#    ",
          "#####.#.###.#.###",
          "#.......#.......#",
          "#.###.#.#.#.###.#",
          "#o..#.........#o#",
          "###.#.#####.#.###",
          "#.....#...#.....#",
          "#.#######.#######",
          "#...............#",
          "#################"
        ];
        const COLS=17, ROWS=22, TILE=24;
        const canvas=document.querySelector("#game"), ctx=canvas.getContext("2d");
        const scoreEl=document.querySelector("#score"), livesEl=document.querySelector("#lives");
        const message=document.querySelector("#message"), pauseButton=document.querySelector("#pause");
        const directions={left:{x:-1,y:0},right:{x:1,y:0},up:{x:0,y:-1},down:{x:0,y:1}};
        let grid,player,ghosts,score,lives,dots,paused,ended,lastTime,swipeStart;

        canvas.width=COLS*TILE; canvas.height=ROWS*TILE;

        function reset(full=true){
          if(full){
            grid=MAP.map(row=>row.padEnd(COLS," ").slice(0,COLS).split(""));
            score=0;lives=3;dots=grid.flat().filter(c=>c==="."||c==="o").length;ended=false;
          }
          player={x:8,y:16,dir:directions.left,next:directions.left,mouth:0};
          ghosts=[
            {x:7,y:10,dir:directions.left,color:"#ff4055"},
            {x:8,y:10,dir:directions.up,color:"#ff91d0"},
            {x:9,y:10,dir:directions.right,color:"#46e5ff"}
          ];
          paused=false; pauseButton.textContent="Pause"; message.textContent="Swipe or use the controls";
          updateStats(); lastTime=performance.now();
        }
        function wall(x,y){ return y<0||y>=ROWS||x<0||x>=COLS||grid[y][x]==="#"; }
        function canMove(entity,dir){ return !wall(entity.x+dir.x,entity.y+dir.y); }
        function choose(name){
          if(ended) return;
          player.next=directions[name];
          document.querySelectorAll(".dir").forEach(b=>b.classList.toggle("active",b.dataset.dir===name));
        }
        function movePlayer(){
          if(canMove(player,player.next)) player.dir=player.next;
          if(canMove(player,player.dir)){ player.x+=player.dir.x; player.y+=player.dir.y; }
          const cell=grid[player.y]?.[player.x];
          if(cell==="."||cell==="o"){
            score+=cell==="o"?50:10; grid[player.y][player.x]=" "; dots--; updateStats();
            if(!dots){ ended=true; message.textContent="Maze cleared! You win!"; }
          }
        }
        function moveGhost(g){
          const choices=Object.values(directions).filter(d=>canMove(g,d)&&!(d.x===-g.dir.x&&d.y===-g.dir.y));
          const chase=choices.sort((a,b)=>{
            const ad=Math.abs(g.x+a.x-player.x)+Math.abs(g.y+a.y-player.y);
            const bd=Math.abs(g.x+b.x-player.x)+Math.abs(g.y+b.y-player.y);
            return ad-bd+(Math.random()-.5)*3;
          })[0];
          if(chase) g.dir=chase;
          if(canMove(g,g.dir)){g.x+=g.dir.x;g.y+=g.dir.y;}
        }
        function collision(){
          if(!ghosts.some(g=>g.x===player.x&&g.y===player.y)) return;
          lives--;updateStats();
          if(lives<=0){ended=true;message.textContent="Game over — tap Restart";return;}
          message.textContent="Caught! Keep going"; reset(false);
        }
        function updateStats(){scoreEl.textContent=score;livesEl.textContent=lives;}
        function draw(){
          ctx.clearRect(0,0,canvas.width,canvas.height);
          for(let y=0;y<ROWS;y++)for(let x=0;x<COLS;x++){
            const c=grid[y][x],cx=x*TILE,cy=y*TILE;
            if(c==="#"){ctx.strokeStyle="#3157ff";ctx.lineWidth=3;ctx.strokeRect(cx+3,cy+3,TILE-6,TILE-6);}
            else if(c==="."||c==="o"){ctx.fillStyle="#ffe6ba";ctx.beginPath();ctx.arc(cx+TILE/2,cy+TILE/2,c==="o"?5:2,0,Math.PI*2);ctx.fill();}
          }
          const px=player.x*TILE+TILE/2,py=player.y*TILE+TILE/2;
          const angle=Math.atan2(player.dir.y,player.dir.x),bite=.22+Math.abs(Math.sin(player.mouth))*.22;
          ctx.fillStyle="#ffd900";ctx.beginPath();ctx.moveTo(px,py);ctx.arc(px,py,TILE*.43,angle+bite,angle+Math.PI*2-bite);ctx.closePath();ctx.fill();
          ghosts.forEach(g=>{
            const x=g.x*TILE+TILE/2,y=g.y*TILE+TILE/2,r=TILE*.4;
            ctx.fillStyle=g.color;ctx.beginPath();ctx.arc(x,y,r,Math.PI,0);ctx.lineTo(x+r,y+r);
            ctx.lineTo(x+r/2,y+r*.65);ctx.lineTo(x,y+r);ctx.lineTo(x-r/2,y+r*.65);ctx.lineTo(x-r,y+r);ctx.closePath();ctx.fill();
            ctx.fillStyle="white";ctx.beginPath();ctx.arc(x-5,y-2,4,0,7);ctx.arc(x+5,y-2,4,0,7);ctx.fill();
          });
        }
        function loop(now){
          if(!paused&&!ended&&now-lastTime>145){
            player.mouth+=1;movePlayer();ghosts.forEach(moveGhost);collision();lastTime=now;
          }
          draw();requestAnimationFrame(loop);
        }

        document.querySelectorAll(".dir").forEach(button=>{
          const select=e=>{e.preventDefault();button.setPointerCapture?.(e.pointerId);choose(button.dataset.dir);};
          button.addEventListener("pointerdown",select);
          button.addEventListener("pointerup",()=>button.classList.remove("active"));
          button.addEventListener("pointercancel",()=>button.classList.remove("active"));
        });
        canvas.addEventListener("pointerdown",e=>{e.preventDefault();swipeStart={x:e.clientX,y:e.clientY};});
        canvas.addEventListener("pointerup",e=>{
          e.preventDefault();if(!swipeStart)return;
          const dx=e.clientX-swipeStart.x,dy=e.clientY-swipeStart.y;swipeStart=null;
          if(Math.max(Math.abs(dx),Math.abs(dy))<18)return;
          choose(Math.abs(dx)>Math.abs(dy)?(dx>0?"right":"left"):(dy>0?"down":"up"));
        });
        canvas.addEventListener("pointercancel",()=>swipeStart=null);
        document.addEventListener("keydown",e=>{
          const key={ArrowLeft:"left",a:"left",ArrowRight:"right",d:"right",ArrowUp:"up",w:"up",ArrowDown:"down",s:"down"}[e.key];
          if(key){e.preventDefault();choose(key);}
        });
        pauseButton.addEventListener("click",()=>{
          if(ended)return;paused=!paused;pauseButton.textContent=paused?"Resume":"Pause";
          message.textContent=paused?"Paused":"Swipe or use the controls";lastTime=performance.now();
        });
        document.querySelector("#restart").addEventListener("click",()=>reset(true));
        document.addEventListener("visibilitychange",()=>{if(document.hidden&&!ended){paused=true;pauseButton.textContent="Resume";}});
        reset(true);requestAnimationFrame(loop);
      })();
      </script>
    </body>
    </html>
    """#
}
