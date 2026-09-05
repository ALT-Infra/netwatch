/* Original, dependency-free 3D scene for the architecture document.
 * World-space solid geometry, orthographic orbital camera, depth-sorted faces.
 * Canvas is the renderer; DOM buttons provide accessible component selection.
 * No camera access, model inference, network requests or external assets.
 */
(() => {
  "use strict";
  const canvas = document.getElementById("scene-canvas");
  const stage = document.getElementById("scene-stage");
  const ctx = canvas.getContext("2d", {willReadFrequently:true});
  if (!ctx) {
    document.getElementById("physical-view").hidden = true;
    document.getElementById("protocol-view").hidden = false;
    document.getElementById("view3d").disabled = true;
    document.getElementById("view3d").setAttribute("aria-pressed", "false");
    document.getElementById("view2d").setAttribute("aria-pressed", "true");
    document.getElementById("scene-instructions").textContent = "3D canvas is unavailable. The complete protocol map is shown.";
    return;
  }
  const palette = {metal:"#b5c4d1", top:"#e1e8ed", dark:"#344859", board:"#406b6f", video:"#356be8", event:"#bc7f2a", optional:"#8564b4", adapt:"#356be8", retained:"#197d8a"};
  const componentInfo = [
    ["cameras","Existing cameras","retained"], ["nvr","Existing NVR","retained"],
    ["ingest","Stream / go2rtc","adapt"], ["decode","Decode / FFmpeg","retained"],
    ["detect","Detect + track","retained"], ["incident","Our incident logic","own"],
    ["record","Evidence recorder","retained"], ["store","Local database","adapt"],
    ["outbox","Export gate","optional"], ["specialist","Specialist","optional"],
    ["desktop","Desktop review","adapt"], ["cloud","Optional hosting","optional"]
  ];
  const labelRoot = document.getElementById("scene-labels");
  const labelButtons = new Map();
  const anchors = new Map();
  const state = {yaw:.34, pitch:.68, zoom:1.15, explode:.72, selected:"incident", online:true, first:false, width:0, height:0, scale:1, offsetX:0, offsetY:0};
  let faces = [], lines = [], hitFaces = [], raf = 0;
  for (const [id, title, kind] of componentInfo) {
    const button = document.createElement("button");
    button.className = "scene-label";
    button.dataset.kind = kind;
    button.dataset.component = id;
    button.setAttribute("aria-pressed", String(id === state.selected));
    button.setAttribute("aria-label", "Inspect " + title);
    const dot = document.createElement("span");
    dot.setAttribute("aria-hidden", "true");
    button.append(dot, document.createTextNode(title));
    button.addEventListener("click", () => selectNode(id));
    labelRoot.append(button);
    labelButtons.set(id, button);
  }

  // Common mesh primitives. All coordinates remain in 3D until draw time.
  function face(points, color, id, shade=1, cull=false) {
    const u=points[1].map((v,i)=>v-points[0][i]),v=points[2].map((v,i)=>v-points[0][i]);
    const normal=cull?[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]:null;
    // Subdivide large surfaces so a distant part of a floor cannot cover a
    // nearer camera just because their polygon-center depths were misordered.
    if(points.length===4){
      const [a,b,c,d]=points,dist=(p,q)=>Math.hypot(...p.map((v,i)=>v-q[i]));
      const nu=Math.ceil(dist(a,b)/.7),nv=Math.ceil(dist(a,d)/.7);
      if(nu>1||nv>1){
        const at=(u,v)=>a.map((_,i)=>(1-u)*(1-v)*a[i]+u*(1-v)*b[i]+u*v*c[i]+(1-u)*v*d[i]);
        for(let u=0;u<nu;u++)for(let v=0;v<nv;v++)faces.push({points:[at(u/nu,v/nv),at((u+1)/nu,v/nv),at((u+1)/nu,(v+1)/nv),at(u/nu,(v+1)/nv)],color,id,shade,normal,internal:true});
        return;
      }
    }
    faces.push({points, color, id, shade,normal});
  }
  function box(x,y,z,w,h,d,color,id) {
    const a=x-w/2,b=x+w/2,c=y-h/2,e=y+h/2,f=z-d/2,g=z+d/2;
    face([[a,c,f],[b,c,f],[b,c,g],[a,c,g]],color,id,.55,true);
    face([[a,e,g],[b,e,g],[b,e,f],[a,e,f]],color,id,1.10,true);
    face([[a,c,f],[a,e,f],[b,e,f],[b,c,f]],color,id,.70,true);
    face([[a,c,g],[b,c,g],[b,e,g],[a,e,g]],color,id,.88,true);
    face([[a,c,f],[a,c,g],[a,e,g],[a,e,f]],color,id,.76,true);
    face([[b,c,f],[b,e,f],[b,e,g],[b,c,g]],color,id,.95,true);
  }
  function cylinder(x,y,z,r,h,color,id,axis="y",sides=20) {
    const low=[], high=[];
    for(let i=0;i<sides;i++) {
      const a=i*2*Math.PI/sides, u=Math.cos(a)*r,v=Math.sin(a)*r;
      low.push(axis==="y"?[x+u,y-h/2,z+v]:[x+u,y+v,z-h/2]);
      high.push(axis==="y"?[x+u,y+h/2,z+v]:[x+u,y+v,z+h/2]);
    }
    face(axis==="y"?low:[...low].reverse(),color,id,.6,true);face(axis==="y"?[...high].reverse():high,color,id,1.06,true);
    for(let i=0;i<sides;i++){const j=(i+1)%sides;const p=[low[i],low[j],high[j],high[i]];face(axis==="y"?p.reverse():p,color,id,.72+.20*Math.cos(i*2*Math.PI/sides),true);}
  }
  function line(points,color,width=1.8,dashed=false,id=null){lines.push({points,color,width,dashed,id});}
  function cable(points,color,id){
    for(let i=1;i<points.length;i++){
      const a=points[i-1],b=points[i],th=.045;
      box((a[0]+b[0])/2,(a[1]+b[1])/2,(a[2]+b[2])/2,Math.max(th,Math.abs(a[0]-b[0])),Math.max(th,Math.abs(a[1]-b[1])),Math.max(th,Math.abs(a[2]-b[2])),color,id);
    }
    // A world-space arrow head on the last horizontal segment.
    const a=points[points.length-2],b=points[points.length-1];
    const dx=b[0]-a[0],dz=b[2]-a[2],len=Math.hypot(dx,dz);
    if(len>.15){const ux=dx/len,uz=dz/len;face([b,[b[0]-.20*ux+.10*uz,b[1]+.01,b[2]-.20*uz-.10*ux],[b[0]-.20*ux-.10*uz,b[1]+.01,b[2]-.20*uz+.10*ux]],color,id,1.1);}
  }
  function module(x,y,z,color,id,kind){
    box(x,y,z,1.55,.14,1.30,palette.board,id);
    box(x,y+.17,z,1.12,.24,.91,color,id);
    // Contacts and heat-sink fins make the borrowed working parts tangible.
    for(let i=0;i<6;i++){
      const pin=x-.59+i*.235;
      box(pin,y+.04,z+.68,.09,.06,.18,"#c5a66c",id);
    }
    if(kind==="fins")for(let i=0;i<7;i++)box(x-.44+i*.145,y+.42,z,.06,.29,.83,"#b8c7ce",id);
    if(kind==="ports")for(let i=0;i<3;i++)box(x-.43+i*.43,y+.22,z+.50,.29,.21,.29,palette.dark,id);
    if(kind==="chips")for(let i=0;i<3;i++)box(x-.37+i*.36,y+.35,z,.24,.09,.54,palette.dark,id);
    anchors.set(id,[x,y+.62,z]);
  }
  function buildScene(){
    faces=[];lines=[];anchors.clear();
    const e=state.explode, y=.75+e*.95;
    // Site floor is physically distinct from the detached hosted-service plinth.
    box(-.6,-.22,.4,17.3,.24,10.0,"#dce5ed",null);
    for(const f of faces)f.layer=-2;
    line([[-9.15,-.08,-4.6],[-9.15,-.08,5.4],[8.05,-.08,5.4],[8.05,-.08,-3.2]],"#70899e",1,true);
    for(let z=-4;z<=5;z++)face([[-8.8,-.087,z],[7.7,-.087,z],[7.7,-.087,z+.012],[-8.8,-.087,z+.012]],"#c6d3dd",null);
    for(let x=-8;x<=7;x++)face([[x,-.086,-4.2],[x,-.086,5.1],[x+.012,-.086,5.1],[x+.012,-.086,-4.2]],"#c6d3dd",null);
    for(const f of faces)if(f.layer===undefined)f.layer=-1;
    // Two camera assemblies and short wall mounting brackets.
    for(const [x,z] of [[-6.5,-2.6],[-7.3,-.35]]){
      box(x-.3,.22,z,.65,.45,.85,palette.metal,"cameras");
      cylinder(x-.3,1.1,z,.065,1.5,"#91a5b4","cameras");
      box(x-.15,1.87,z,.45,.15,.16,palette.metal,"cameras");
      box(x,2.09,z+.22,.94,.59,1.43,"#e6edf2","cameras");
      box(x,2.44,z+.17,1.12,.09,1.64,"#d5e0e8","cameras");
      cylinder(x,2.1,z+1.00,.245,.10,"#283e52","cameras","z");
      cylinder(x,2.1,z+1.06,.145,.015,"#3d728a","cameras","z");
      cylinder(x-.04,2.16,z+1.075,.045,.02,"#b8e0ee","cameras","z");
    }
    anchors.set("cameras",[-6.7,2.72,-1.7]);
    // NVR with disk bays and independent recording indicator.
    box(-6.1,.41,3.18,3.00,.65,2.15,"#889ba9","nvr");
    box(-6.1,.76,3.18,3.05,.06,2.2,"#c9d7e1","nvr");
    box(-6.1,.39,4.28,2.89,.45,.05,"#344859","nvr");
    for(let i=0;i<3;i++){box(-6.93+i*.68,.40,4.32,.59,.20,.04,"#657c8f","nvr");}
    for(let i=0;i<10;i++)box(-7.18+i*.24,.803,3.1,.08,.015,.98,"#6f8495","nvr");
    cylinder(-5.02,.47,4.325,.047,.03,"#54b29a","nvr","z",12);
    anchors.set("nvr",[-6.05,1.00,3.55]);
    cable([[-7.0,.01,.5],[-7.0,.01,1.8],[-6.0,.01,1.8],[-6.0,.01,2.1]],palette.video,"nvr");
    cable([[-6.1,.05,-1.2],[-4.3,.05,-1.2],[-4.3,.05,-1.6],[-3.3,.05,-1.6]],palette.video,"ingest");
    // Appliance chassis: base, back and cutaway side walls. Never seals the CV
    // modules behind a decorative shell when open.
    box(0,.18,.2,7.2,.26,6.35,palette.metal,"ingest");
    box(0,.35,.2,6.88,.06,6.06,"#496570",null);
    box(0,.55,-2.94,7.1,.70,.12,"#bdcbd6",null);
    box(-3.5,.55,.15,.12,.70,6.12,"#aabcc9",null);
    box(3.5,.55,.15,.12,.70,6.12,"#c0ced9",null);
    box(0,.47,3.35,7.12,.54,.14,"#8098aa",null);
    for(let i=0;i<9;i++)box(-2.85+i*.25,.47,3.44,.075,.27,.02,"#2f4659",null);
    for(let i=0;i<3;i++)box(1.1+i*.54,.47,3.44,.35,.21,.03,"#293c4c",null);
    cylinder(2.85,.48,3.45,.08,.025,"#5ca898",null,"z",16);
    for(const x of [-3.1,3.1])for(const z of [-2.6,2.8])cylinder(x,.08,z,.17,.33,"#415567",null);
    // Lift the metal lid behind the chassis as it is opened, freeing the view.
    const lidY=1.60+e*2.25,lidZ=.2-e*7.6;
    box(0,lidY,lidZ,7.10,.09,6.2*(1-e*.60),"#d4dfe7",null);
    for(let i=0;i<12;i++)box(-1.82+i*.33,lidY+.055,lidZ,.08,.012,.90,"#98aebd",null);
    if(e>.2){
      line([[-3.0,.50,-2.5],[-3.0,lidY-.06,lidZ+.4]],"#94a7b6",1,true);
      line([[3.0,.50,-2.5],[3.0,lidY-.06,lidZ+.4]],"#94a7b6",1,true);
    }
    // Each board is a software responsibility. Their separation is illustrative.
    module(-2.17,y,-1.38,"#83aeb5","ingest","ports");
    module(-2.17,y,.74,"#8baeb9","decode","fins");
    module(0,y+.11,-1.38,"#6a969f","detect","fins");
    module(0,y+.11,.74,"#d9b879","incident","chips");
    module(2.17,y,-1.38,"#9ab5c3","record","disk");
    cylinder(2.17,y+.38,-1.38,.42,.05,"#cbd6dc","record");
    cylinder(2.17,y+.414,-1.38,.115,.03,"#718b9d","record");
    module(2.17,y,.74,"#aac1d2","store","chips");
    if(!state.first){
      module(0,y-.20,2.41,"#b8a4ca","specialist","chips");
      module(2.17,y-.20,2.41,"#b09bc4","outbox","ports");
    }else{
      anchors.set("specialist",[0,y+.42,2.41]);anchors.set("outbox",[2.17,y+.42,2.41]);
    }
    const cy=y+.07;
    cable([[-3.5,.41,-1.38],[-3.10,.41,-1.38],[-3.10,cy,-1.38],[-2.94,cy,-1.38]],palette.video,"ingest");
    cable([[-2.17,cy,-.73],[-2.17,cy,.09]],palette.video,"decode");
    cable([[-1.39,cy,.74],[-1.08,cy,.74],[-1.08,cy,-1.38],[-.78,cy,-1.38]],palette.video,"detect");
    cable([[-2.17,cy,-2.04],[-2.17,cy,-2.43],[2.17,cy,-2.43],[2.17,cy,-2.04]],palette.video,"record");
    cable([[0,cy+.12,-.73],[0,cy+.12,.09]],palette.event,"incident");
    cable([[.78,cy+.12,.74],[1.38,cy+.12,.74]],palette.event,"store");
    cable([[2.17,cy,-.73],[2.17,cy,.09]],palette.event,"store");
    // Operator workstation: solid monitor, local scene on the screen, keyboard.
    box(6.05,.22,3.3,3.55,.15,2.30,"#cedce7","desktop");
    box(6.05,.37,2.92,.92,.10,.63,"#778f9f","desktop");
    box(6.05,.88,2.81,.18,1.00,.15,"#8fa5b5","desktop");
    box(6.05,1.81,2.81,3.15,1.9,.14,"#344859","desktop");
    box(6.05,1.84,2.894,2.94,1.60,.02,"#a9c8da","desktop");
    // Screen graphics are world-space geometry, so they rotate with the display.
    face([[4.61,1.06,2.92],[7.49,1.06,2.92],[7.49,1.65,2.92],[6.54,2.34,2.92],[5.83,1.53,2.92],[5.22,1.94,2.92]],"#648993","desktop",1);
    box(6.76,1.59,2.94,.19,.50,.01,"#e9d5a5","desktop");
    line([[6.43,1.15,2.96],[7.18,1.30,2.96],[7.03,1.80,2.96],[6.37,1.64,2.96],[6.43,1.15,2.96]],"#f5c77f",2,false,"desktop");
    box(5.43,2.45,2.93,1.38,.17,.01,"#314f64","desktop");
    box(6.05,.38,3.99,2.16,.09,.56,"#8aa0b0","desktop");
    for(let i=0;i<11;i++)box(5.08+i*.192,.436,3.99,.125,.015,.34,"#c1d0da","desktop");
    anchors.set("desktop",[6.05,2.94,2.85]);
    cable([[3.59,.24,1.0],[4.31,.24,1.0],[4.31,.24,3.1],[4.8,.24,3.1]],palette.event,"desktop");
    // Detached hosted service and its explicitly optional WAN route.
    box(6.25,.30,-5.18,3.12,.16,2.6,"#d8d1e4","cloud");
    const cloudColor=!state.online?"#a9acb4":state.first?"#bcc1cc":"#a596ba";
    for(let i=0;i<3;i++){
      box(6.25,.63+i*.39,-5.18,2.35,.30,1.52,cloudColor,"cloud");
      box(6.25,.63+i*.39,-4.40,2.10,.18,.04,"#5e6177","cloud");
      for(let j=0;j<4;j++)box(5.39+j*.23,.64+i*.39,-4.372,.10,.04,.012,state.online&&!state.first?"#c9c1ea":"#8e95a2","cloud");
    }
    anchors.set("cloud",[6.25,1.98,-5.18]);
    if(!state.first){
      cable([[2.17,cy,1.42],[2.17,cy,1.74]],palette.optional,"outbox");
      line([[2.94,cy,2.40],[4.06,cy,2.40],[4.06,cy,-4.02],[5.16,cy,-4.02],[5.16,.70,-4.40]],state.online?palette.optional:"#aab0ba",2,true,"cloud");
    }
  }
  function view(p){
    const c=Math.cos(state.yaw),s=Math.sin(state.yaw),cp=Math.cos(state.pitch),sp=Math.sin(state.pitch);
    const horizontal=c*p[0]-s*p[2],forward=s*p[0]+c*p[2];
    return [horizontal,sp*forward-cp*p[1],cp*forward+sp*p[1]];
  }
  function project(p){const a=view(p);return [a[0]*state.scale+state.offsetX,a[1]*state.scale+state.offsetY,a[2]];}
  function color(hex,shade=1,id=null){
    let v=hex.slice(1).match(/../g).map(x=>Math.min(255,parseInt(x,16)*shade));
    if(id&&id===state.selected)v=v.map((x,i)=>x*.8+[77,133,216][i]*.2);
    return `rgb(${v.map(Math.round).join(",")})`;
  }
  function tracePolygon(points){ctx.beginPath();points.forEach((p,i)=>i?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]));ctx.closePath();}
  function fit(){
    // Stable bounds prevent the scene moving around when the lid or labels change.
    const bounds=[];
    for(const x of [-9.4,8.3])for(const z of [-7,5.7])for(const y of [-.3,3.8])bounds.push(view([x,y,z]));
    const xs=bounds.map(p=>p[0]),ys=bounds.map(p=>p[1]);
    const minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys);
    state.scale=Math.min((state.width-48)/(maxX-minX),(state.height-84)/(maxY-minY))*state.zoom;
    state.offsetX=state.width/2-(minX+maxX)/2*state.scale;
    state.offsetY=state.height/2-(minY+maxY)/2*state.scale+12;
  }
  function render(){
    raf=0;
    if(document.getElementById("physical-view").hidden)return;
    const rect=stage.getBoundingClientRect();if(!rect.width||!rect.height)return;
    state.width=rect.width;state.height=rect.height;
    const dpr=Math.min(window.devicePixelRatio||1,2);
    const w=Math.round(rect.width*dpr),h=Math.round(rect.height*dpr);
    if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
    ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,rect.width,rect.height);
    fit();buildScene();
    // Contact shadow under the customer's floor; no animation or polling loop.
    const shadow=project([-.6,-.4,.9]);
    ctx.save();ctx.translate(shadow[0],shadow[1]+10);ctx.scale(state.scale*8.0,state.scale*2.55);
    const grad=ctx.createRadialGradient(0,0,.18,0,0,1);grad.addColorStop(0,"#637a8d30");grad.addColorStop(1,"#637a8d00");ctx.fillStyle=grad;ctx.beginPath();ctx.arc(0,0,1,0,Math.PI*2);ctx.fill();ctx.restore();
    const eye=[Math.cos(state.pitch)*Math.sin(state.yaw),Math.sin(state.pitch),Math.cos(state.pitch)*Math.cos(state.yaw)];
    const projected=faces.filter(f=>!f.normal||f.normal.reduce((a,v,i)=>a+v*eye[i],0)>0).map(f=>({...f,screen:f.points.map(project)}));
    for(const f of projected)f.depth=f.screen.reduce((a,p)=>a+p[2],0)/f.screen.length;
    projected.sort((a,b)=>(a.layer||0)-(b.layer||0)||a.depth-b.depth);hitFaces=[];
    for(const f of projected){
      tracePolygon(f.screen);ctx.fillStyle=color(f.color,f.shade,f.id);ctx.fill();
      ctx.strokeStyle=color(f.color,f.internal?f.shade:f.shade*.89);ctx.lineWidth=.45;ctx.stroke();
      if(f.id)hitFaces.push(f);
    }
    // Control/boundary annotations are drawn as explanatory paths above solids.
    for(const l of lines){
      const p=l.points.map(project);ctx.beginPath();p.forEach((v,i)=>i?ctx.lineTo(v[0],v[1]):ctx.moveTo(v[0],v[1]));
      ctx.strokeStyle=l.color;ctx.lineWidth=l.width;ctx.setLineDash(l.dashed?[5,5]:[]);ctx.stroke();ctx.setLineDash([]);
    }
    placeLabels();
  }
  function intersects(a,b){return a.x<b.x+b.w+5&&a.x+a.w+5>b.x&&a.y<b.y+b.h+5&&a.y+a.h+5>b.y;}
  function placeLabels(){
    const placed=[],small=state.width<720;
    // Reserve the page-level boundary annotation and cable key from labels.
    placed.push({x:0,y:0,w:230,h:65},{x:state.width-320,y:state.height-33,w:320,h:33});
    const major=new Set(["cameras","nvr","desktop","cloud"]);
    const entries=componentInfo.map(([id])=>({id,p:project(anchors.get(id))})).sort((a,b)=>a.p[1]-b.p[1]);
    for(const {id,p} of entries){
      const b=labelButtons.get(id),isDeferred=state.first&&["outbox","specialist","cloud"].includes(id);
      const hidden=(small&&!major.has(id)&&id!==state.selected)||(state.explode<.18&&!major.has(id)&&id!==state.selected);
      b.hidden=hidden;b.classList.toggle("deferred-label",isDeferred);if(hidden)continue;
      b.setAttribute("aria-pressed",String(id===state.selected));
      const w=b.offsetWidth,h=b.offsetHeight;
      let candidate=null;
      // Screen-space callouts stay upright as the physical scene rotates.
      const offsets=[[0,-28],[0,-58],[0,12],[-w*.6,-28],[w*.6,-28],[0,43],[0,-88],[-w*.8,15],[w*.8,15]];
      for(const [dx,dy] of offsets){
        const a={x:Math.max(8,Math.min(state.width-w-8,p[0]-w/2+dx)),y:Math.max(8,Math.min(state.height-h-38,p[1]+dy)),w,h};
        if(!placed.some(other=>intersects(a,other))){candidate=a;break;}
      }
      if(!candidate){
        // Exhaustive final placement for narrow or unusual orbit positions.
        let best=Infinity;
        for(let y=70;y<state.height-h-38;y+=h+8)for(let x=8;x<state.width-w-8;x+=Math.max(40,w/2)){
          const a={x,y,w,h};if(placed.some(other=>intersects(a,other)))continue;
          const dist=Math.hypot(x+w/2-p[0],y+h/2-p[1]);if(dist<best){best=dist;candidate=a;}
        }
      }
      if(!candidate){b.hidden=true;continue;}
      b.style.transform=`translate(${Math.round(candidate.x)}px,${Math.round(candidate.y)}px)`;placed.push(candidate);
      const bx=Math.max(candidate.x+5,Math.min(candidate.x+w-5,p[0]));
      const by=p[1]<candidate.y?candidate.y:candidate.y+h;
      ctx.beginPath();ctx.moveTo(p[0],p[1]);ctx.lineTo(bx,by);ctx.strokeStyle=id===state.selected?"#356be8":"#7c91a3";ctx.lineWidth=1;ctx.stroke();
      ctx.beginPath();ctx.arc(p[0],p[1],2.4,0,Math.PI*2);ctx.fillStyle=id===state.selected?"#356be8":"#7c91a3";ctx.fill();
    }
  }
  function schedule(){if(!raf)raf=requestAnimationFrame(render);}
  function reset(){state.yaw=.34;state.pitch=.68;state.zoom=1.15;schedule();}
  function inside(p,poly){let yes=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if(((a[1]>p[1])!==(b[1]>p[1]))&&(p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]))yes=!yes;}return yes;}
  let drag=null;
  canvas.addEventListener("pointerdown",e=>{
    if(e.button!==0)return;
    drag={id:e.pointerId,x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY,moved:false};
    canvas.setPointerCapture(e.pointerId);canvas.classList.add("dragging");
  });
  canvas.addEventListener("pointermove",e=>{
    if(!drag||e.pointerId!==drag.id)return;
    if(Math.hypot(e.clientX-drag.startX,e.clientY-drag.startY)>5)drag.moved=true;
    if(drag.moved){state.yaw+=(e.clientX-drag.x)*.006;state.pitch=Math.max(.30,Math.min(1.15,state.pitch+(e.clientY-drag.y)*.004));schedule();}
    drag.x=e.clientX;drag.y=e.clientY;
  });
  canvas.addEventListener("pointerup",e=>{
    if(!drag||e.pointerId!==drag.id)return;
    if(!drag.moved){const r=canvas.getBoundingClientRect(),p=[e.clientX-r.left,e.clientY-r.top];for(let i=hitFaces.length-1;i>=0;i--)if(inside(p,hitFaces[i].screen)){selectNode(hitFaces[i].id);break;}}
    drag=null;canvas.classList.remove("dragging");
  });
  canvas.addEventListener("pointercancel",()=>{drag=null;canvas.classList.remove("dragging");});
  canvas.addEventListener("lostpointercapture",()=>{drag=null;canvas.classList.remove("dragging");});
  canvas.addEventListener("keydown",e=>{
    if(!["ArrowLeft","ArrowRight","ArrowUp","ArrowDown","+","=","-","0"].includes(e.key))return;e.preventDefault();
    if(e.key==="ArrowLeft")state.yaw-=.16;if(e.key==="ArrowRight")state.yaw+=.16;
    if(e.key==="ArrowUp")state.pitch=Math.min(1.15,state.pitch+.08);if(e.key==="ArrowDown")state.pitch=Math.max(.30,state.pitch-.08);
    if(e.key==="+"||e.key==="=")state.zoom=Math.min(1.55,state.zoom+.1);if(e.key==="-")state.zoom=Math.max(.65,state.zoom-.1);if(e.key==="0")reset();schedule();
  });
  document.getElementById("orbit-left").addEventListener("click",()=>{state.yaw-=.22;schedule();});
  document.getElementById("orbit-right").addEventListener("click",()=>{state.yaw+=.22;schedule();});
  document.getElementById("zoom-in").addEventListener("click",()=>{state.zoom=Math.min(1.55,state.zoom+.1);schedule();});
  document.getElementById("zoom-out").addEventListener("click",()=>{state.zoom=Math.max(.65,state.zoom-.1);schedule();});
  document.getElementById("reset-scene").addEventListener("click",reset);
  document.getElementById("explode").addEventListener("input",e=>{state.explode=Number(e.target.value)/100;document.getElementById("explode-value").textContent=e.target.value+"%";schedule();});
  document.querySelectorAll("[data-select]").forEach(b=>b.addEventListener("click",()=>selectNode(b.dataset.select)));
  window.addEventListener("architecture-select",e=>{state.selected=e.detail.id;schedule();});
  window.addEventListener("architecture-view",e=>{state.online=e.detail.online;state.first=e.detail.firstView;schedule();});
  function setMode(threeD){
    document.getElementById("physical-view").hidden=!threeD;document.getElementById("protocol-view").hidden=threeD;
    document.getElementById("view3d").setAttribute("aria-pressed",String(threeD));document.getElementById("view2d").setAttribute("aria-pressed",String(!threeD));
    document.getElementById("scene-instructions").textContent=threeD?"Drag to orbit. Select a part to inspect its role and source.":"Follow the labeled protocols. Select a component for its contract.";
    schedule();
  }
  document.getElementById("view3d").addEventListener("click",()=>setMode(true));
  document.getElementById("view2d").addEventListener("click",()=>setMode(false));
  new ResizeObserver(schedule).observe(stage);
  schedule();
})();
