package main

const uiHTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lumos Agent Control</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{
--bg-top:#1e293b;
--bg-mid:#0b1220;
--bg-low:#020617;
--surface:#f8fafc;
--surface-alt:#f1f5f9;
--surface-muted:#fff;
--line:#e2e8f0;
--line-strong:#cbd5e1;
--text-dark:#0f172a;
--text-subtle:#6b7280;
--text-muted:#64748b;
--text-inverse:#f8fafc;
--text-page:#e2e8f0;
--accent:#19c7b4;
--accent-deep:#0f766e;
--accent-strong:#0ea5a3;
--warning:#f59e0b;
--danger:#dc2626;
--success:#16a34a;
--card-shadow:0 14px 36px rgba(2,6,23,0.28);
--control-shadow:0 6px 14px rgba(15,118,110,0.28);
}
body{font-family:'Segoe UI',Tahoma,Arial,sans-serif;background:radial-gradient(circle at top,var(--bg-top) 0%,var(--bg-mid) 52%,var(--bg-low) 100%);min-height:100vh;padding:20px;color:var(--text-page)}
.container{max-width:1360px;margin:0 auto}
header{text-align:center;margin-bottom:28px}
.subtitle{opacity:0.86;font-size:1.02rem;font-weight:400;color:var(--line-strong)}
.brand{display:flex;align-items:center;justify-content:center;gap:14px;margin-bottom:10px}
.brand-mark{width:58px;height:58px;border-radius:14px;box-shadow:0 12px 30px rgba(2,6,23,0.55);background:var(--text-dark)}
.brand-text{display:flex;flex-direction:column;align-items:flex-start}
.brand-name{font-size:2.05rem;font-weight:800;line-height:1;letter-spacing:0.6px;color:var(--text-inverse)}
.brand-role{font-size:0.82rem;font-weight:700;letter-spacing:3.4px;color:var(--warning);margin-top:4px}
.card{background:var(--surface);border-radius:18px;padding:24px;margin-bottom:20px;box-shadow:var(--card-shadow);color:var(--text-dark);border:1px solid var(--line)}
.card h2{color:var(--text-dark);margin-bottom:18px;font-size:1.25rem;font-weight:700;display:flex;align-items:center;gap:10px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:24px}
.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.form-group{margin-bottom:18px}
label{display:block;margin-bottom:8px;font-weight:600;color:#334155;font-size:0.92rem}
input,select{width:100%;padding:13px 14px;border:1px solid var(--line-strong);border-radius:10px;font-size:0.98rem;transition:all 0.2s;font-family:inherit;background:var(--surface-muted);color:var(--text-dark)}
input:focus,select:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px rgba(25,199,180,0.18)}
input::placeholder{color:#9ca3af}
select{cursor:pointer;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%230f172a' d='M6 9L1 4h10z'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 16px center;padding-right:40px;appearance:none}
select option{padding:10px}
button{width:100%;padding:14px;background:linear-gradient(135deg,var(--accent-strong) 0%,var(--accent-deep) 100%);color:var(--surface-muted);border:none;border-radius:10px;font-size:0.97rem;font-weight:700;cursor:pointer;transition:all 0.2s;box-shadow:var(--control-shadow)}
button:hover:not(:disabled){transform:translateY(-1px);box-shadow:0 10px 18px rgba(15,118,110,0.34)}
button:active:not(:disabled){transform:translateY(0)}
button:disabled{opacity:0.5;cursor:not-allowed}
.btn-danger{background:linear-gradient(135deg,var(--danger) 0%,#b91c1c 100%);box-shadow:0 6px 14px rgba(185,28,28,0.25)}
.btn-success{background:linear-gradient(135deg,var(--accent-strong) 0%,var(--accent-deep) 100%)}
.btn-warning{background:linear-gradient(135deg,var(--warning) 0%,#d97706 100%);box-shadow:0 6px 14px rgba(217,119,6,0.26)}
.status-box{background:var(--surface-alt);border-left:4px solid var(--accent-strong);padding:14px;border-radius:10px;font-family:'Consolas','Courier New',monospace;font-size:0.89rem;color:#334155;margin-top:14px;line-height:1.5}
.status-box.error{border-left-color:var(--danger);background:#fef2f2;color:#991b1b}
.status-box.success{border-left-color:var(--success);background:#f0fdf4;color:#166534}
.scan-result{background:var(--surface-muted);border:1px solid var(--line);border-radius:12px;padding:16px;margin:10px 0;cursor:pointer;transition:all 0.2s;position:relative;overflow:hidden}
.scan-result::before{content:'';position:absolute;top:0;left:0;width:4px;height:100%;background:linear-gradient(135deg,var(--accent),#0e9f8d);transform:scaleY(0);transition:transform 0.3s}
.scan-result:hover{border-color:#14b8a6;box-shadow:0 10px 20px rgba(15,23,42,0.12);transform:translateX(4px)}
.scan-result:hover::before{transform:scaleY(1)}
.scan-result strong{color:var(--text-dark);font-size:1.08rem;display:block;margin-bottom:8px;font-weight:700}
.scan-result small{color:var(--text-subtle);display:block;margin-top:8px;font-size:0.9rem}
.mac-badge{display:inline-block;background:linear-gradient(135deg,var(--accent),#0e9f8d);color:var(--surface-muted);padding:6px 12px;border-radius:8px;font-size:0.88rem;margin:6px 6px 6px 0;font-family:'SF Mono','Monaco',monospace;font-weight:600;box-shadow:0 2px 8px rgba(102,126,234,0.3)}
.peer-list{background:var(--surface);border-radius:12px;padding:16px;max-height:400px;overflow-y:auto;border:1px solid var(--line)}
.peer-item{background:var(--surface-muted);border-left:4px solid var(--accent);padding:14px;margin:8px 0;border-radius:10px;box-shadow:0 2px 8px rgba(15,23,42,0.06);transition:all 0.2s}
.peer-item:hover{box-shadow:0 4px 16px rgba(0,0,0,0.1);transform:translateX(4px)}
.peer-item strong{color:var(--text-dark);font-size:1.02rem;display:block;margin-bottom:6px}
.peer-item small{color:var(--text-subtle);font-size:0.88rem}
.checkbox-group{display:flex;align-items:center;gap:12px;margin:12px 0;padding:12px;background:var(--surface);border-radius:10px;border:1px solid var(--line)}
.checkbox-group input[type="checkbox"]{width:22px;height:22px;margin:0;cursor:pointer;accent-color:var(--accent)}
.checkbox-group label{margin:0;cursor:pointer;font-weight:500;color:#374151}
.info-badge{display:inline-block;background:#ccfbf1;color:var(--accent-deep);padding:6px 10px;border-radius:14px;font-size:0.82rem;margin:6px 6px 6px 0;font-weight:700}
#scanResults{margin-top:20px}
.empty-state{text-align:center;padding:60px 20px;color:#9ca3af}
.empty-state-icon{font-size:4rem;margin-bottom:16px;opacity:0.5}
.divider{height:1px;background:linear-gradient(90deg,transparent,var(--line-strong),transparent);margin:20px 0}
.section-note{color:var(--text-muted);margin:-8px 0 16px 0;font-size:0.89rem}
.risk{background:#fff7ed;border:1px solid #fed7aa;color:#9a3412;padding:10px 12px;border-radius:10px;font-size:0.86rem;margin-bottom:14px}
.tabs{display:flex;gap:10px;flex-wrap:wrap;margin:0 0 18px 0}
.tab-btn{flex:1;min-width:130px;padding:11px 12px;border:1px solid #334155;background:#111827;color:var(--line-strong);border-radius:10px;cursor:pointer;font-weight:700;box-shadow:none}
.tab-btn:hover{border-color:#14b8a6;color:var(--text-inverse)}
.tab-btn.active{background:linear-gradient(135deg,var(--accent-strong) 0%,var(--accent-deep) 100%);border-color:var(--accent-deep);color:var(--surface-muted)}
.panel{display:none}
.panel.active{display:block}
.audit-row{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}
.audit-meta{color:var(--text-muted);font-size:0.82rem}
.section-description{color:var(--text-subtle);margin-bottom:20px;font-size:0.95rem}
.peer-heading{color:var(--accent);margin-bottom:16px;font-size:1.2rem}
.peer-address{color:var(--text-subtle);margin-top:4px}
.mac-list{margin-top:10px}
.mac-input{text-transform:uppercase}
.scan-empty-line{margin-top:12px;font-size:0.9rem}
.scan-empty-line-muted{margin-top:8px;font-size:0.9rem}
@media(max-width:768px){
.grid{grid-template-columns:1fr}
.grid-2{grid-template-columns:1fr}
.brand-name{font-size:1.7rem}
.tab-btn{min-width:unset;flex:1 1 calc(50% - 10px)}
}
</style>
</head>
<body>
<div class="container">
<header>
<div class="brand">
<svg class="brand-mark" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg" aria-label="Lumos mark" role="img">
<rect width="256" height="256" rx="56" fill="#0F172A"/>
<circle cx="128" cy="128" r="74" fill="none" stroke="#19C7B4" stroke-width="16"/>
<circle cx="128" cy="128" r="96" fill="none" stroke="#1E293B" stroke-width="8"/>
<path d="M121 66L89 133H124L112 190L167 112H132L146 66H121Z" fill="#F59E0B"/>
<circle cx="60" cy="128" r="8" fill="#19C7B4"/>
<circle cx="196" cy="128" r="8" fill="#19C7B4"/>
<circle cx="128" cy="60" r="8" fill="#19C7B4"/>
<circle cx="128" cy="196" r="8" fill="#19C7B4"/>
</svg>
<div class="brand-text">
<div class="brand-name">LUMOS</div>
<div class="brand-role">AGENT</div>
</div>
</div>
<p class="subtitle">Wake-on-LAN & Remote Power Management</p>
</header>

<div class="card">
<h2>Authentication</h2>
<p class="section-note">Use agent credentials to unlock operational controls.</p>
<div class="form-group">
<label>Agent Password</label>
<input id="pw" type="password" placeholder="Enter your agent password" autocomplete="current-password">
</div>
<button onclick="refreshState()" class="btn-success">Refresh Status</button>
<div id="msg" class="status-box">Ready. Enter password and click refresh to begin.</div>
</div>

<div class="tabs">
<button class="tab-btn active" data-tab="control" onclick="switchTab('control')">Control</button>
<button class="tab-btn" data-tab="scan" onclick="switchTab('scan')">Scan</button>
<button class="tab-btn" data-tab="peers" onclick="switchTab('peers')">Peers</button>
<button class="tab-btn" data-tab="settings" onclick="switchTab('settings')">Settings</button>
</div>

<section id="panel-control" class="panel active">
<div class="grid">
<div class="card">
<h2>Local Control</h2>
<div class="risk">High impact actions. Confirm target and action before execution.</div>
<div class="form-group">
<label>Power Action</label>
<select id="localAction">
<option value="shutdown">Shutdown Computer</option>
<option value="reboot">Reboot Computer</option>
<option value="sleep">Sleep Mode</option>
</select>
</div>
<button onclick="runLocalPower()" class="btn-danger">Execute Power Command</button>
<div class="divider"></div>
<div class="form-group">
<label>Wake Device by MAC Address</label>
<select id="wakeMacSelect" onchange="document.getElementById('wakeMac').value=this.value">
<option value="">-- Select from discovered MACs --</option>
</select>
</div>
<div class="form-group">
<label>Or Enter MAC Manually</label>
<input id="wakeMac" class="mac-input" placeholder="AA:BB:CC:DD:EE:FF">
</div>
<button onclick="runWake()">Send Wake-on-LAN Packet</button>
<div id="localStatus" class="status-box">Local control idle.</div>
</div>

<div class="card">
<h2>Relay to Peer</h2>
<div class="risk">Relayed actions execute on remote hosts. A confirmation prompt is required.</div>
<div class="form-group">
<label>Target Peer</label>
<select id="relayTarget" onchange="selectPeer(this.value)">
<option value="">-- Select a peer --</option>
</select>
</div>
<div class="form-group">
<label>Or Enter Manually</label>
<input id="relayTargetManual" placeholder="Agent ID or address">
</div>
<div class="form-group">
<label>Action to Execute</label>
<select id="relayAction">
<option value="wake">Wake Device</option>
<option value="shutdown">Shutdown</option>
<option value="reboot">Reboot</option>
<option value="sleep">Sleep</option>
</select>
</div>
<div class="form-group">
<label>MAC Address (required for wake action)</label>
<select id="relayMacSelect" onchange="document.getElementById('relayMac').value=this.value">
<option value="">-- Select from discovered MACs --</option>
</select>
</div>
<div class="form-group">
<label>Or Enter MAC Manually</label>
<input id="relayMac" class="mac-input" placeholder="AA:BB:CC:DD:EE:FF">
</div>
<button onclick="runRelay()">Send Relay Command</button>
<div id="relayStatus" class="status-box">Relay control idle.</div>
</div>
</div>
<div class="card">
<h2>Action Audit Trail</h2>
<p class="section-note">Recent local and relay command attempts on this agent.</p>
<div id="auditTrail" class="peer-list"></div>
</div>
</section>

<section id="panel-scan" class="panel">
<div class="card">
<h2>Network Scanner</h2>
<p class="section-description">Scan your local network to discover other Lumos agents. Leave network field empty for auto-detection.</p>
<p id="scanDetected" class="section-note">Detected local networks will appear here.</p>
<div class="grid-2">
<div class="form-group">
<label>Scan Preset</label>
<select id="scanPreset" onchange="applyScanPreset(this.value)">
<option value="balanced">Balanced</option>
<option value="fast">Fast</option>
<option value="deep">Deep</option>
<option value="custom">Custom</option>
</select>
</div>
<div class="form-group">
<label>Network Range (CIDR Notation)</label>
<input id="scanNetwork" placeholder="192.168.1.0/24 or leave empty">
</div>
<div class="form-group">
<label>Port Number</label>
<input id="scanPort" type="number" value="8080" min="1" max="65535">
</div>
<div class="form-group">
<label>Timeout (seconds)</label>
<input id="scanTimeout" type="number" value="2" min="1" max="10">
</div>
</div>
<button id="scanBtn" onclick="scanNetwork()">Scan for Lumos Agents</button>
<div id="scanStatus" class="status-box">Scan idle.</div>
<div id="scanResults"></div>
</div>
</section>

<section id="panel-peers" class="panel">
<div class="card">
<h2>Peer Management</h2>
<p class="section-description">Add or update peer agents manually. Discovered peers are automatically added.</p>
<div class="grid-2">
<div class="form-group">
<label>Peer Agent ID</label>
<input id="peerId" placeholder="desktop-02">
</div>
<div class="form-group">
<label>Peer Address</label>
<input id="peerAddr" placeholder="192.168.1.100:8080">
</div>
</div>
<div class="form-group">
<label>Peer Password (required for registration)</label>
<input type="password" id="peerPassword" placeholder="Enter peer's password">
</div>
<button onclick="upsertPeer()">Add/Update Peer</button>
<div id="peerStatus" class="status-box">Peer management idle.</div>
<div class="divider"></div>
<h3 class="peer-heading">Discovered Peers</h3>
<div id="peers" class="peer-list"></div>
</div>
</section>

<section id="panel-settings" class="panel">
<div class="card">
<h2>Agent Settings</h2>
<div class="checkbox-group">
<input type="checkbox" id="allowWake">
<label for="allowWake">Allow wake commands without password authentication</label>
</div>
<div class="checkbox-group">
<input type="checkbox" id="dryRun">
<label for="dryRun">Dry run mode (simulate power commands without executing)</label>
</div>
<div class="checkbox-group">
<input type="checkbox" id="safeModeEnabled">
<label for="safeModeEnabled">Safe mode for destructive actions (two-step confirm)</label>
</div>
<div class="form-group">
<label>Safe Mode Cooldown (seconds)</label>
<input id="safeModeCooldown" type="number" value="15" min="0" max="3600">
</div>
<div class="form-group">
<label>Advertise Address</label>
<input id="advAddr" placeholder="192.168.1.100:8080">
</div>
<div class="form-group">
<label>Bootstrap Peers (comma-separated addresses)</label>
<input id="bootPeers" placeholder="192.168.1.101:8080, 192.168.1.102:8080">
</div>
<button onclick="saveSettings()" class="btn-warning">Save Settings</button>
<div id="settingsStatus" class="status-box">Settings idle.</div>
</div>
</section>

</div>

<script>
function pw(){return document.getElementById('pw').value}
async function api(path,method='GET',body=null,needsPw=false,extraHeaders={}){
const h={'Content-Type':'application/json'};
if(needsPw)h['X-Lumos-Password']=pw();
Object.keys(extraHeaders||{}).forEach(k=>{h[k]=extraHeaders[k]});
const o={method,headers:h,credentials:'include'};
if(body)o.body=JSON.stringify(body);
const r=await fetch(path,o);
const t=await r.text();
let d={};
try{d=JSON.parse(t)}catch{d={raw:t}}
if(!r.ok){
const err=new Error(d.message||t||('HTTP '+r.status));
err.status=r.status;
err.data=d;
throw err;
}
return d
}
function msg(t,type='info'){
const el=document.getElementById('msg');
el.textContent=t;
el.className='status-box';
if(type==='error')el.className+=' error';
if(type==='success')el.className+=' success';
}
function sectionMsg(id,t,type='info'){
const el=document.getElementById(id);
if(!el)return;
el.textContent=t;
el.className='status-box';
if(type==='error')el.className+=' error';
if(type==='success')el.className+=' success';
}
function switchTab(tab,updateURL=true){
document.querySelectorAll('.tab-btn').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
document.querySelectorAll('.panel').forEach(p=>p.classList.remove('active'));
const panel=document.getElementById('panel-'+tab);
if(panel)panel.classList.add('active');
if(updateURL){
syncURLState(tab);
}
}
function normalizeTab(value){
const tabs=['control','scan','peers','settings'];
return tabs.includes(value)?value:'control';
}
function getActiveTab(){
const active=document.querySelector('.tab-btn.active');
if(!active||!active.dataset||!active.dataset.tab)return 'control';
return normalizeTab(active.dataset.tab);
}
function getScanStateParams(){
const params=new URLSearchParams();
const preset=(document.getElementById('scanPreset')?.value||'').trim();
const network=(document.getElementById('scanNetwork')?.value||'').trim();
const port=(document.getElementById('scanPort')?.value||'').trim();
const timeout=(document.getElementById('scanTimeout')?.value||'').trim();
if(preset)params.set('scan_preset',preset);
if(network)params.set('scan_network',network);
if(port)params.set('scan_port',port);
if(timeout)params.set('scan_timeout',timeout);
return params;
}
function applyScanStateFromParams(params){
if(!params)return;
const preset=(params.get('scan_preset')||'').trim();
const network=(params.get('scan_network')||'').trim();
const port=(params.get('scan_port')||'').trim();
const timeout=(params.get('scan_timeout')||'').trim();
if(preset&&['fast','balanced','deep','custom'].includes(preset)){
document.getElementById('scanPreset').value=preset;
if(preset!=='custom'){
applyScanPreset(preset);
}
}
if(network){
document.getElementById('scanNetwork').value=network;
}
const parsedPort=parseInt(port);
if(Number.isFinite(parsedPort)&&parsedPort>=1&&parsedPort<=65535){
document.getElementById('scanPort').value=String(parsedPort);
}
const parsedTimeout=parseInt(timeout);
if(Number.isFinite(parsedTimeout)&&parsedTimeout>=1&&parsedTimeout<=10){
document.getElementById('scanTimeout').value=String(parsedTimeout);
}
}
function getUrlState(){
const merged=new URLSearchParams(window.location.search);
const hashRaw=(window.location.hash||'').replace(/^#/,'');
let tabRaw=hashRaw;
let hashQuery='';
const idx=hashRaw.indexOf('?');
if(idx>=0){
tabRaw=hashRaw.slice(0,idx);
hashQuery=hashRaw.slice(idx+1);
}
const hashParams=new URLSearchParams(hashQuery);
hashParams.forEach((value,key)=>merged.set(key,value));
return {tab:normalizeTab((tabRaw||'').trim().toLowerCase()),params:merged};
}
function syncURLState(tab){
const safeTab=normalizeTab(tab||getActiveTab());
const scanParams=getScanStateParams();
const scanQuery=scanParams.toString();
const query=scanQuery?('?'+scanQuery):'';
const hash=scanQuery?('#'+safeTab+'?'+scanQuery):('#'+safeTab);
history.replaceState(null,'',window.location.pathname+query+hash);
}
function applyScanPreset(preset){
const portInput=document.getElementById('scanPort');
const timeoutInput=document.getElementById('scanTimeout');
if(!portInput||!timeoutInput)return;
if(preset==='fast'){
portInput.value='8080';
timeoutInput.value='1';
}else if(preset==='balanced'){
portInput.value='8080';
timeoutInput.value='2';
}else if(preset==='deep'){
portInput.value='8080';
timeoutInput.value='4';
}
syncURLState(getActiveTab());
}
function applyTabFromHash(){
const state=getUrlState();
applyScanStateFromParams(state.params);
switchTab(state.tab,false);
syncURLState(state.tab);
}
async function refreshState(){
try{
const d=await api('/v1/ui/state');
document.getElementById('allowWake').checked=!!d.allow_wake_without_password;
document.getElementById('dryRun').checked=!!d.dry_run;
document.getElementById('safeModeEnabled').checked=!!d.safe_mode_enabled;
document.getElementById('safeModeCooldown').value=Number(d.safe_mode_cooldown_seconds)||0;
document.getElementById('advAddr').value=d.advertise_addr||'';
document.getElementById('bootPeers').value=(d.bootstrap_peers||[]).join(', ');
const detectedNetworks=(d.detected_networks||[]).filter(n=>typeof n==='string'&&n.trim()!=='');
const scanDetected=document.getElementById('scanDetected');
if(scanDetected){
if(detectedNetworks.length>0){
scanDetected.textContent='Detected networks: '+detectedNetworks.join(', ')+' (auto-scan uses all)';
}else{
scanDetected.textContent='No local networks detected yet. Enter CIDR manually if needed.';
}
}
const peersDiv=document.getElementById('peers');
const relayTargetSelect=document.getElementById('relayTarget');
const wakeMacSelect=document.getElementById('wakeMacSelect');
const relayMacSelect=document.getElementById('relayMacSelect');
const auditTrail=document.getElementById('auditTrail');
relayTargetSelect.innerHTML='<option value="">-- Select a peer --</option>';
wakeMacSelect.innerHTML='<option value="">-- Select from discovered MACs --</option>';
relayMacSelect.innerHTML='<option value="">-- Select from discovered MACs --</option>';
const macSet=new Set();
if(d.peers&&d.peers.length>0){
let html='';
d.peers.forEach(p=>{
const lastSeen=new Date(p.last_seen_at).toLocaleString();
html+='<div class="peer-item"><strong>'+p.agent_id+'</strong><div class="peer-address">📍 '+p.address+'</div><small>Last seen: '+lastSeen+'</small></div>';
relayTargetSelect.innerHTML+='<option value="'+p.agent_id+'" data-address="'+p.address+'">'+p.agent_id+' ('+p.address+')</option>';
if(p.interfaces&&p.interfaces.length>0){
p.interfaces.forEach(iface=>{
if(iface.mac&&!macSet.has(iface.mac)){
macSet.add(iface.mac);
const optText=iface.mac+' - '+p.agent_id+' ('+iface.name+')';
wakeMacSelect.innerHTML+='<option value="'+iface.mac+'">'+optText+'</option>';
relayMacSelect.innerHTML+='<option value="'+iface.mac+'">'+optText+'</option>'
}
})
}
});
peersDiv.innerHTML=html
}else{
peersDiv.innerHTML='<div class="empty-state"><div class="empty-state-icon">👥</div><div>No peers discovered yet. Use the network scanner to find agents.</div></div>'
}
if(d.audit&&d.audit.length>0){
let auditHtml='';
d.audit.forEach(entry=>{
const ts=entry.timestamp?new Date(entry.timestamp).toLocaleString():'Unknown time';
const result=entry.success?'success':'failed';
const target=entry.target?(' -> '+entry.target):'';
const mac=entry.mac?(' | MAC: '+entry.mac):'';
auditHtml+='<div class="peer-item"><div class="audit-row"><strong>'+entry.source+' / '+entry.action+target+'</strong><span class="audit-meta">'+result+'</span></div><small>'+ts+mac+' | '+(entry.message||'')+'</small></div>';
});
auditTrail.innerHTML=auditHtml;
}else{
auditTrail.innerHTML='<div class="empty-state"><div class="empty-state-icon">🧾</div><div>No audit entries yet. Run a local or relay action to populate history.</div></div>';
}
msg('✓ Connected to agent: '+d.agent_id+' | OS: '+d.os+' | Dry Run: '+(d.dry_run?'Enabled':'Disabled'),'success')
sectionMsg('localStatus','Device state refreshed. Ready for local commands.','success');
sectionMsg('relayStatus','Peer list refreshed. Ready for relay commands.','success');
sectionMsg('peerStatus','Peer data refreshed from agent state.','success');
sectionMsg('settingsStatus','Settings loaded from current runtime state.','success');
}catch(e){
msg('✗ Failed to refresh: '+e.message,'error')
sectionMsg('localStatus','Refresh failed: '+e.message,'error');
sectionMsg('relayStatus','Refresh failed: '+e.message,'error');
sectionMsg('peerStatus','Refresh failed: '+e.message,'error');
sectionMsg('settingsStatus','Refresh failed: '+e.message,'error');
}
}
function selectPeer(agentId){
if(!agentId)return;
const select=document.getElementById('relayTarget');
const option=select.options[select.selectedIndex];
const address=option.getAttribute('data-address');
document.getElementById('relayTargetManual').value=agentId;
if(address){
document.getElementById('relayTargetManual').placeholder='Using: '+address
}
}
async function runLocalPower(){
try{
const action=document.getElementById('localAction').value;
const actionName={'shutdown':'Shutdown','reboot':'Reboot','sleep':'Sleep'}[action];
if(!confirm('Are you sure you want to '+actionName+' this computer?'))return;
let d;
try{
d=await api('/v1/command/power','POST',{action},true);
}catch(e){
if(e.status===409&&e.data&&e.data.confirm_token){
if(!confirm('Safe mode confirmation required for '+actionName+'. Continue?')){return}
d=await api('/v1/command/power','POST',{action},true,{'X-Lumos-Confirm-Token':e.data.confirm_token});
}else{
throw e
}
}
msg('✓ '+d.message,'success')
sectionMsg('localStatus','Power action accepted: '+actionName+'.','success');
}catch(e){
msg('✗ Power command failed: '+e.message,'error')
sectionMsg('localStatus','Power command failed: '+e.message,'error');
}
}
async function runWake(){
try{
const mac=document.getElementById('wakeMac').value.trim().toUpperCase();
if(!mac){msg('✗ Please enter a MAC address','error');return}
if(!/^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$/.test(mac)){
msg('✗ Invalid MAC address format. Use AA:BB:CC:DD:EE:FF','error');return
}
const d=await api('/v1/command/wake','POST',{mac},true);
msg('✓ '+d.message+' to '+mac,'success')
sectionMsg('localStatus','Wake packet sent to '+mac+'.','success');
}catch(e){
msg('✗ Wake command failed: '+e.message,'error')
sectionMsg('localStatus','Wake command failed: '+e.message,'error');
}
}
async function runRelay(){
try{
const target_agent_id=document.getElementById('relayTarget').value||document.getElementById('relayTargetManual').value.trim();
const action=document.getElementById('relayAction').value;
const mac=document.getElementById('relayMac').value.trim().toUpperCase();
if(!target_agent_id){
msg('✗ Please select or enter a target peer','error');return
}
if(action==='wake'&&!mac){
msg('✗ MAC address required for wake action','error');return
}
const confirmText='Confirm relay action:\n\nTarget: '+target_agent_id+'\nAction: '+action.toUpperCase()+(action==='wake'?'\nMAC: '+mac:'');
if(!confirm(confirmText)){return}
const address='';
let d;
try{
d=await api('/v1/peer/relay','POST',{target_agent_id,address,action,mac},true);
}catch(e){
if(e.status===409&&e.data&&e.data.confirm_token){
if(!confirm('Safe mode confirmation required for relay '+action.toUpperCase()+'. Continue?')){return}
d=await api('/v1/peer/relay','POST',{target_agent_id,address,action,mac},true,{'X-Lumos-Confirm-Token':e.data.confirm_token});
}else{
throw e
}
}
msg('✓ '+d.message,'success')
sectionMsg('relayStatus','Relay sent: '+action+' on '+target_agent_id+'.','success');
}catch(e){
msg('✗ Relay command failed: '+e.message,'error')
sectionMsg('relayStatus','Relay command failed: '+e.message,'error');
}
}
async function upsertPeer(){
try{
const agent_id=document.getElementById('peerId').value.trim();
const address=document.getElementById('peerAddr').value.trim();
const password=document.getElementById('peerPassword').value;
if(!agent_id||!address){
msg('✗ Both agent ID and address are required','error');return
}
if(!password){
msg('✗ Peer password is required for registration','error');return
}
const d=await api('/v1/ui/peer/upsert','POST',{agent_id,address,password});
msg('✓ '+d.message,'success');
sectionMsg('peerStatus','Peer saved: '+agent_id+' ('+address+').','success');
document.getElementById('peerPassword').value='';
setTimeout(refreshState,500)
}catch(e){
msg('✗ Failed to add peer: '+e.message,'error')
sectionMsg('peerStatus','Failed to add peer: '+e.message,'error');
}
}
async function saveSettings(){
try{
const allow_wake_without_password=document.getElementById('allowWake').checked;
const dry_run=document.getElementById('dryRun').checked;
const safe_mode_enabled=document.getElementById('safeModeEnabled').checked;
const safe_mode_cooldown_seconds=Math.max(0,parseInt(document.getElementById('safeModeCooldown').value)||0);
const advertise_addr=document.getElementById('advAddr').value.trim();
const bootstrap_peers=document.getElementById('bootPeers').value;
const d=await api('/v1/ui/settings','POST',{allow_wake_without_password,dry_run,safe_mode_enabled,safe_mode_cooldown_seconds,advertise_addr,bootstrap_peers});
msg('✓ '+d.message,'success');
sectionMsg('settingsStatus','Settings saved. Restart agent if config-file persistence is required.','success');
setTimeout(refreshState,500)
}catch(e){
msg('✗ Failed to save settings: '+e.message,'error')
sectionMsg('settingsStatus','Failed to save settings: '+e.message,'error');
}
}
async function scanNetwork(){
const btn=document.getElementById('scanBtn');
const resultsDiv=document.getElementById('scanResults');
let progressTimer=null;
const startedAt=Date.now();
try{
btn.disabled=true;
btn.textContent='Scanning network...';
sectionMsg('scanStatus','Scanning network for Lumos agents. This may take a moment...');
progressTimer=setInterval(()=>{
const elapsed=((Date.now()-startedAt)/1000).toFixed(1);
sectionMsg('scanStatus','Scanning network for Lumos agents... elapsed '+elapsed+'s');
},500);
resultsDiv.innerHTML='';
const network=document.getElementById('scanNetwork').value.trim();
const port=parseInt(document.getElementById('scanPort').value)||8080;
const timeout=Math.min(10,Math.max(1,parseInt(document.getElementById('scanTimeout').value)||2));
const preset=document.getElementById('scanPreset').value||'custom';
syncURLState('scan');
const d=await api('/v1/ui/scan','POST',{network,port,timeout});
const hostsTotal=Number(d.hosts_total)||0;
const hostsReachable=Number(d.hosts_reachable)||0;
const durationMs=Number(d.duration_ms)||0;
const summary='Scanned '+hostsTotal+' host target(s), reachable '+hostsReachable+', duration '+durationMs+'ms';
if(d.results&&d.results.length>0){
let html='<div class="status-box success">✓ Found '+d.results.length+' Lumos agent(s) on '+d.scanned+'<br><small>'+summary+'</small></div>';
for(const r of d.results){
try{
const statusResp=await fetch('http://'+r.address+'/v1/status');
const status=await statusResp.json();
let macInfo='';
let primaryMac='';
if(status.interfaces&&status.interfaces.length>0){
macInfo='<div class="mac-list">';
status.interfaces.forEach(i=>{
macInfo+='<span class="mac-badge">'+i.mac+'</span>'
});
macInfo+='</div>';
primaryMac=status.interfaces[0].mac
}
html+='<div class="scan-result" onclick="addPeerFromScan(\''+r.agent_id+'\',\''+r.address+'\',\''+primaryMac+'\')"><strong>'+r.agent_id+'</strong><div><span class="info-badge">'+r.os+'</span><span class="info-badge">'+r.address+'</span></div>'+macInfo+'<small>💡 Click to add as peer and auto-fill MAC address</small></div>'
}catch(e){
html+='<div class="scan-result" onclick="addPeerFromScan(\''+r.agent_id+'\',\''+r.address+'\',\'\')"><strong>'+r.agent_id+'</strong><div><span class="info-badge">'+r.os+'</span><span class="info-badge">'+r.address+'</span></div><small>💡 Click to add as peer</small></div>'
}
}
resultsDiv.innerHTML=html
}else{
resultsDiv.innerHTML='<div class="empty-state"><div class="empty-state-icon">🔍</div><div>No Lumos agents found on '+d.scanned+'</div><div class="scan-empty-line">'+summary+'</div><div class="scan-empty-line-muted">Make sure agents are running and accessible on your network.</div></div>'
}
msg('✓ Network scan completed','success')
sectionMsg('scanStatus','Scan completed on '+d.scanned+' (preset: '+preset+', port: '+port+', timeout: '+timeout+'s). '+summary+'.','success');
}catch(e){
resultsDiv.innerHTML='<div class="status-box error">✗ Scan failed: '+e.message+'</div>';
msg('✗ Network scan failed: '+e.message,'error')
sectionMsg('scanStatus','Scan failed: '+e.message,'error');
}finally{
if(progressTimer){
clearInterval(progressTimer);
}
btn.disabled=false;
btn.textContent='Scan for Lumos Agents'
}
}
function addPeerFromScan(agentId,address,mac){
document.getElementById('peerId').value=agentId;
document.getElementById('peerAddr').value=address;
if(mac){
document.getElementById('wakeMac').value=mac;
document.getElementById('relayMac').value=mac;
const wakeMacSelect=document.getElementById('wakeMacSelect');
const relayMacSelect=document.getElementById('relayMacSelect');
let found=false;
for(let i=0;i<wakeMacSelect.options.length;i++){
if(wakeMacSelect.options[i].value===mac){
wakeMacSelect.selectedIndex=i;
relayMacSelect.selectedIndex=i;
found=true;
break
}
}
if(!found){
wakeMacSelect.innerHTML+='<option value="'+mac+'" selected>'+mac+' - '+agentId+'</option>';
relayMacSelect.innerHTML+='<option value="'+mac+'" selected>'+mac+' - '+agentId+'</option>'
}
msg('✓ Ready to add peer: '+agentId+' | MAC: '+mac,'success')
sectionMsg('peerStatus','Prefilled peer '+agentId+' with MAC '+mac+'.','success');
}else{
msg('✓ Ready to add peer: '+agentId,'success')
sectionMsg('peerStatus','Prefilled peer '+agentId+'.','success');
}
window.scrollTo({top:0,behavior:'smooth'})
}
refreshState();
setInterval(refreshState,30000);
applyTabFromHash();
window.addEventListener('hashchange',applyTabFromHash);
['scanPreset','scanNetwork','scanPort','scanTimeout'].forEach(id=>{
const el=document.getElementById(id);
if(!el)return;
const evt=id==='scanNetwork'?'input':'change';
el.addEventListener(evt,()=>syncURLState(getActiveTab()));
});
</script>
</body>
</html>`
