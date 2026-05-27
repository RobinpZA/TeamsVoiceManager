const VoiceConfigPage={
    currentConfig:null,
    normRules:[],
    async render(c){
        c.innerHTML=`<div class="page-header"><h1>Voice Routing Configuration</h1><p>Configure SBC gateways, PSTN usages, voice routes, and normalization rules</p></div>
<div class="info-box">Click "Retrieve Current Config" to view existing tenant configuration grouped by voice route. Use the editor below to create or update configuration.</div>
<div class="toolbar"><div class="toolbar-left"><button class="btn btn-secondary" id="brc">Retrieve Current Config</button></div><div class="toolbar-right"><button class="btn btn-primary" id="bac">Apply Configuration</button></div></div>
<div id="routeOverview" class="hidden"></div>
<div class="card"><div class="card-header"><h2>SBC Gateways</h2></div><div class="form-row"><div class="form-group"><label class="form-label">SBC FQDN 1</label><input type="text" class="form-input" id="sf1" placeholder="customer.mtb.msdr.teams.vodacom.co.za"></div><div class="form-group"><label class="form-label">SBC FQDN 2</label><input type="text" class="form-input" id="sf2" placeholder="customer.cfo.msdr.teams.vodacom.co.za"></div><div class="form-group"><label class="form-label">SIP Port</label><input type="number" class="form-input" id="sp" value="5061"></div></div></div>
<div class="card"><div class="card-header"><h2>PSTN Usage</h2></div><div class="form-group"><label class="form-label">Usage Name</label><input type="text" class="form-input" id="pu" value="PSTN Usage for Teams DR VODA-HA-01-VR"></div></div>
<div class="card"><div class="card-header"><h2>Voice Route</h2></div><div class="form-row"><div class="form-group"><label class="form-label">Route Identity</label><input type="text" class="form-input" id="ri" value="Default-Voice-RouteVODA-HA-01-VR"></div><div class="form-group"><label class="form-label">Number Pattern</label><input type="text" class="form-input" id="rp" value=".*"></div><div class="form-group"><label class="form-label">Priority</label><input type="number" class="form-input" id="rpr" value="1"></div></div></div>
<div class="card"><div class="card-header"><h2>Voice Routing Policy</h2></div><div class="form-group"><label class="form-label">Policy Identity</label><input type="text" class="form-input" id="pi" value="Global"></div></div>
<div class="card"><div class="card-header"><h2>Normalization Rules</h2><button class="btn btn-sm btn-secondary" id="bar">+ Add Rule</button></div><div id="nrt"></div></div>
<div id="apply-results" class="hidden"></div>`;
        this.loadDefaults();
        document.getElementById('brc').addEventListener('click',()=>this.retrieveConfig());
        document.getElementById('bac').addEventListener('click',()=>this.applyConfig());
        document.getElementById('bar').addEventListener('click',()=>this.addRule());
        this.renderRules();
    },
    loadDefaults(){
        this.normRules=[
            {name:'ZA-TollFree',pattern:'^0(80\\d{7})\\d*$',translation:'+27$1'},
            {name:'ZA-Premium',pattern:'^0(86[24-9]\\d{6})$',translation:'+27$1'},
            {name:'ZA-Mobile',pattern:'^0(([7]\\d{8}|8[1-5]\\d{7}))$',translation:'+27$1'},
            {name:'ZA-National',pattern:'^0(([1-5]\\d\\d|8[789]\\d|86[01])\\d{6})\\d*(\\D+\\d+)?$',translation:'+27$1'},
            {name:'ZA-Service',pattern:'^(1\\d{2,4})$',translation:'$1'},
            {name:'ZA-International',pattern:'^(?:\\+|00)(1|7|2[07]|3[0-46]|39\\d|4[013-9]|5[1-8]|6[0-6]|8[1246]|9[0-58]|2[1235689]\\d|24[013-9]|242\\d|3[578]\\d|42\\d|5[09]\\d|6[789]\\d|8[035789]\\d|9[679]\\d)(?:0)?(\\d{6,14})(\\D+\\d+)?$',translation:'+$1$2'}
        ];
    },
    renderRules(){
        const ct=document.getElementById('nrt');
        if(!this.normRules.length){ct.innerHTML='<p class="text-muted">No rules. Click Add Rule.</p>';return}
        let h='<div class="table-container"><table><thead><tr><th>Name</th><th>Pattern</th><th>Translation</th><th>Actions</th></tr></thead><tbody>';
        this.normRules.forEach((r,i)=>{
            h+=`<tr><td><input class="form-input" value="${esc(r.name)}" data-i="${i}" data-f="name" style="width:150px"></td><td><input class="form-input mono" value="${esc(r.pattern)}" data-i="${i}" data-f="pattern"></td><td><input class="form-input mono" value="${esc(r.translation)}" data-i="${i}" data-f="translation" style="width:120px"></td><td><button class="btn btn-sm btn-danger" data-del="${i}">Remove</button></td></tr>`;
        });
        h+='</tbody></table></div>';
        ct.innerHTML=h;
        ct.querySelectorAll('input[data-i]').forEach(inp=>inp.addEventListener('change',()=>{
            const i=parseInt(inp.dataset.i);this.normRules[i][inp.dataset.f]=inp.value;
        }));
        ct.querySelectorAll('[data-del]').forEach(btn=>btn.addEventListener('click',()=>{
            this.normRules.splice(parseInt(btn.dataset.del),1);this.renderRules();
        }));
    },
    addRule(){this.normRules.push({name:'New-Rule',pattern:'^(.*)$',translation:'$1'});this.renderRules()},
    _renderRouteOverview(data){
        const panel=document.getElementById('routeOverview');
        if(!panel)return;
        const routes=data.routes||[];
        if(!routes.length){panel.classList.add('hidden');return;}
        panel.classList.remove('hidden');
        const pickerHtml=routes.length>1
            ?`<select class="form-input" id="routePicker" style="max-width:380px;font-size:.875rem">${routes.map((r,i)=>`<option value="${i}">${esc(r.identity)}</option>`).join('')}</select>`
            :`<span class="badge badge-info" style="font-size:.875rem">${esc(routes[0].identity)}</span>`;
        panel.innerHTML=`<div class="card"><div class="card-header" style="display:flex;align-items:center;gap:1rem;flex-wrap:wrap"><h2 style="margin:0">Current Configuration</h2>${pickerHtml}</div><div id="routeDetail"></div></div>`;
        if(routes.length>1){
            document.getElementById('routePicker').addEventListener('change',e=>this._showRoute(parseInt(e.target.value),data));
        }
        this._showRoute(0,data);
    },
    _showRoute(idx,data){
        const d=data||this.currentConfig;
        const route=d.routes[idx];
        if(!route)return;
        const allGw=d.gateways||[];
        const allPol=d.routingPolicies||[];
        // Resolve full gateway details for each FQDN in the route's gateway list
        const routeUsages=route.pstnUsages||[];
        const routeGw=(route.gatewayList||[]).map(fqdn=>{
            const found=allGw.find(g=>g.fqdn.toLowerCase()===fqdn.toLowerCase());
            return found||{fqdn,sipPort:5061,enabled:true,mediaBypass:false};
        });
        // Policies that reference any of this route's PSTN usages
        const relPolicies=allPol.filter(p=>(p.pstnUsages||[]).some(u=>routeUsages.includes(u)));
        const gwRows=routeGw.length
            ?routeGw.map(g=>`<tr><td class="mono">${esc(g.fqdn)}</td><td>${esc(String(g.sipPort||5061))}</td><td><span class="badge ${g.enabled?'badge-success':'badge-error'}">${g.enabled?'Enabled':'Disabled'}</span></td><td>${g.mediaBypass?'Yes':'No'}</td></tr>`).join('')
            :`<tr><td colspan="4" class="text-muted" style="padding:.75rem">No gateways assigned to this route</td></tr>`;
        const usageTags=routeUsages.length
            ?routeUsages.map(u=>`<span class="badge badge-info" style="margin:.15rem .15rem .15rem 0">${esc(u)}</span>`).join('')
            :`<span class="text-muted">None</span>`;
        const polRows=relPolicies.length
            ?relPolicies.map(p=>`<tr><td>${esc((p.identity||'').replace(/^Tag:/,''))}</td><td class="mono" style="font-size:.8rem">${esc((p.pstnUsages||[]).join(', '))}</td></tr>`).join('')
            :`<tr><td colspan="2" class="text-muted" style="padding:.75rem">No policies reference this route\u2019s PSTN usages</td></tr>`;
        document.getElementById('routeDetail').innerHTML=`
<div style="padding:1rem">
  <div class="form-row" style="margin-bottom:1.25rem;align-items:flex-end">
    <div style="flex:2"><span class="form-label">Route Identity</span><div class="mono" style="padding:.35rem 0;font-weight:500">${esc(route.identity)}</div></div>
    <div style="flex:2"><span class="form-label">Number Pattern</span><div class="mono" style="padding:.35rem 0">${esc(route.numberPattern||'.*')}</div></div>
    <div style="flex:1"><span class="form-label">Priority</span><div style="padding:.35rem 0">${route.priority||1}</div></div>
    <div style="flex:1;display:flex;align-items:center;padding-bottom:.1rem"><button class="btn btn-secondary btn-sm" id="btnLoadEditor" style="white-space:nowrap">Load to Editor &#x2193;</button></div>
  </div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:1.5rem">
    <div>
      <div style="font-size:.75rem;font-weight:700;letter-spacing:.06em;color:var(--text-muted);margin-bottom:.5rem">SBC GATEWAYS</div>
      <div class="table-container"><table><thead><tr><th>FQDN</th><th>Port</th><th>Status</th><th>Bypass</th></tr></thead><tbody>${gwRows}</tbody></table></div>
    </div>
    <div>
      <div style="font-size:.75rem;font-weight:700;letter-spacing:.06em;color:var(--text-muted);margin-bottom:.5rem">PSTN USAGES</div>
      <div style="margin-bottom:1.25rem">${usageTags}</div>
      <div style="font-size:.75rem;font-weight:700;letter-spacing:.06em;color:var(--text-muted);margin-bottom:.5rem">VOICE ROUTING POLICIES</div>
      <div class="table-container"><table><thead><tr><th>Policy</th><th>PSTN Usages</th></tr></thead><tbody>${polRows}</tbody></table></div>
    </div>
  </div>
</div>`;
        document.getElementById('btnLoadEditor').addEventListener('click',()=>this._loadRouteToEditor(route,routeGw));
    },
    _loadRouteToEditor(route,gw){
        if(gw[0])document.getElementById('sf1').value=gw[0].fqdn;
        if(gw[1])document.getElementById('sf2').value=gw[1].fqdn;
        if(gw[0]?.sipPort)document.getElementById('sp').value=gw[0].sipPort;
        if(route.pstnUsages?.[0])document.getElementById('pu').value=route.pstnUsages[0];
        document.getElementById('ri').value=route.identity||'';
        document.getElementById('rp').value=route.numberPattern||'.*';
        document.getElementById('rpr').value=route.priority||1;
        document.getElementById('pi').value=(route.identity||'Global');
        document.getElementById('sf1').closest('.card').scrollIntoView({behavior:'smooth'});
        Toast.info('Route loaded to editor');
    },
    async retrieveConfig(){
        Toast.info('Retrieving current config...');
        try{
            const d=await API.getVoiceConfig();
            this.currentConfig=d;
            this._renderRouteOverview(d);
            if(d.dialPlan?.normalizationRules){this.normRules=d.dialPlan.normalizationRules;this.renderRules();}
            Toast.success('Config loaded from tenant');
        }catch(e){Toast.error(e.message);}
    },
    async applyConfig(){
        const config={
            pstnUsage:document.getElementById('pu').value,
            routeIdentity:document.getElementById('ri').value,
            numberPattern:document.getElementById('rp').value,
            priority:parseInt(document.getElementById('rpr').value),
            gatewayList:[document.getElementById('sf1').value,document.getElementById('sf2').value].filter(Boolean),
            policyIdentity:document.getElementById('pi').value,
            dialPlanIdentity:'Global',
            normalizationRules:this.normRules
        };
        Modal.confirm('Apply Voice Configuration','This will create/update PSTN usage, voice route, routing policy, and normalization rules. Continue?',async()=>{
            Toast.info('Applying configuration...');
            try{
                const r=await API.setVoiceConfig(config);
                const rc=document.getElementById('apply-results');rc.classList.remove('hidden');
                let h='<div class="card"><div class="card-header"><h2>Apply Results</h2></div>';
                if(r.steps){r.steps.forEach(s=>{
                    const cls={Success:'badge-success',Error:'badge-error',Skipped:'badge-neutral'}[s.status]||'badge-info';
                    h+=`<div style="padding:.4rem 0;border-bottom:1px solid var(--border-light)"><span class="badge ${cls}">${s.status}</span> <strong>${s.step}</strong> - ${s.detail||''}</div>`;
                })}
                h+='</div>';rc.innerHTML=h;
                r.success?Toast.success('Configuration applied!'):Toast.warning('Some steps failed. Check results.');
            }catch(e){Toast.error(e.message);}
        });
    }
};
