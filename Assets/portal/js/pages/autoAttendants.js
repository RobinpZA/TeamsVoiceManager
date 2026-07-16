const AutoAttendantsPage={
    ras:[],languages:[],timezones:[],
    _menuOpts:[],_ahMenuOpts:[],_holidays:[],
    async render(c){
        c.innerHTML=`<div class="page-header"><h1>Auto Attendants</h1><p>Create and manage Auto Attendants with business hours, menus, holidays and call flows</p></div>
<div class="toolbar"><div class="toolbar-left"><button class="btn btn-primary" id="bca">+ Create Auto Attendant</button><button class="btn btn-secondary" id="bra">Refresh</button></div></div>
<div id="atc"><div class="loading-spinner"><div class="spinner"></div><p>Loading...</p></div></div>`;
        document.getElementById('bca').addEventListener('click',()=>this.showCreateWizard());
        document.getElementById('bra').addEventListener('click',()=>this.load());
        await this.load();
    },
    async load(){
        try{
            const[aaData,raData]=await Promise.all([API.getAutoAttendants(),API.getResourceAccounts()]);
            this.ras=(raData.accounts||[]).filter(r=>r.type==='AutoAttendant');
            DataTable.render(document.getElementById('atc'),{columns:[
                {key:'name',label:'Name'},
                {key:'language',label:'Language'},
                {key:'timeZone',label:'Time Zone'},
                {key:'voiceResponseEnabled',label:'Voice',render:v=>v?'<span class="badge badge-success">Yes</span>':'<span class="badge badge-neutral">No</span>'},
                {key:'hasAfterHours',label:'After Hours',render:v=>v?'<span class="badge badge-info">Yes</span>':'<span class="badge badge-neutral">No</span>'},
                {key:'holidayCount',label:'Holidays'},
                {key:'operator',label:'Operator',render:v=>v?`<span class="badge badge-accent">${esc(v.type)}</span>`:'<span class="badge badge-neutral">None</span>'}
            ],data:aaData.autoAttendants||[],emptyMessage:'No auto attendants. Create one to start.',
            actions:[{label:'⟶ Flow',class:'btn-secondary',onClick:async r=>{Toast.info('Loading flow…');try{CallFlowVisualizer.showAA(await API.getAutoAttendantFlow(r.id));}catch(e){Toast.error(e.message);}}}]});
        }catch(e){Toast.error(e.message)}
    },
    async showCreateWizard(){
        try{
            const[l,t,raData]=await Promise.all([API.getLanguages(),API.getTimezones(),API.getResourceAccounts()]);
            this.languages=l.languages||[];this.timezones=t.timezones||[];
            this.ras=(raData.accounts||[]).filter(r=>r.type==='AutoAttendant');
        }catch(e){}
        this._menuOpts=[];this._ahMenuOpts=[];this._holidays=[];
        const langOpts=this.languages.map(l=>`<option value="${esc(l.id)}" ${l.id==='en-ZA'?'selected':''}>${esc(l.displayName)}</option>`).join('');
        const tzOpts=this.timezones.map(t=>`<option value="${esc(t.id)}" ${t.id==='South Africa Standard Time'?'selected':''}>${esc(t.displayName)}</option>`).join('');
        const raOpts=this.ras.map(r=>`<option value="${esc(r.objectId)}">${esc(r.displayName)} (${esc(r.userPrincipalName)})</option>`).join('');
        Modal.show('Create Auto Attendant',`
<div style="background:var(--bg-overlay);border-left:3px solid var(--accent);padding:.6rem .8rem;border-radius:4px;margin-bottom:1rem;font-size:.85rem;color:var(--text-muted)">
  <strong style="color:var(--text-primary)">Before you start:</strong> Create and license a <strong>Resource Account</strong> (AA type) on the Resource Accounts page first — you'll need its ObjectId to assign a phone number to this Auto Attendant.
</div>
<div class="form-group"><label class="form-label">Name</label><input type="text" class="form-input" id="aa-name" placeholder="Main Line AA"></div>
<div class="form-row">
  <div class="form-group"><label class="form-label">Language</label><select class="form-select" id="aa-lang">${langOpts}</select></div>
  <div class="form-group"><label class="form-label">Time Zone</label><select class="form-select" id="aa-tz">${tzOpts}</select></div>
</div>
<div class="form-group"><label class="form-label">Resource Account</label><select class="form-select" id="aa-ra"><option value="">None</option>${raOpts}</select></div>

<details><summary>Operator <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(optional)</span></summary><div class="details-body">
  <div class="form-row">
    <div class="form-group"><label class="form-label">Operator Type</label>
      <select class="form-select" id="aa-op-type">
        <option value="">None</option>
        <option value="User">User</option>
        <option value="ApplicationEndpoint">Resource Account / AA / CQ</option>
        <option value="ExternalPstn">External Phone Number</option>
      </select>
    </div>
    <div class="form-group"><label class="form-label">Operator Identity (ObjectId or SIP)</label><input type="text" class="form-input" id="aa-op-id" placeholder="e.g. sip:user@domain.com"></div>
  </div>
</div></details>

<details open><summary>Business Hours Call Flow <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(required — runs during business hours, or always if no After Hours schedule is set)</span></summary><div class="details-body">
  <p class="text-muted" style="margin-bottom:.75rem;font-size:.85rem">Configure the greeting and menu callers hear when they reach this Auto Attendant during business hours. Add DTMF key options below to route callers — if no options are added, callers are disconnected.</p>
  <div class="form-group"><label class="form-label">Greeting (Text-to-Speech)</label><textarea class="form-textarea" id="aa-greet" rows="2" placeholder="Welcome to our company..."></textarea></div>
  <div class="form-group"><label class="form-label">Menu Prompt (Text-to-Speech) <span style="font-weight:400;color:var(--text-muted)">— read after greeting to list options</span></label><textarea class="form-textarea" id="aa-menu-prompt" rows="2" placeholder="Press 1 for Sales, press 2 for Support..."></textarea></div>
  <div class="form-row" style="align-items:center;margin-bottom:.75rem">
    <div class="form-toggle"><input type="checkbox" id="aa-dbn"><label class="form-label" for="aa-dbn">Enable Dial-by-Name</label></div>
    <div class="form-group" id="aa-dbn-method-wrap" style="display:none;margin-bottom:0">
      <label class="form-label">Directory Search Method</label>
      <select class="form-select" id="aa-dbn-method"><option value="ByName">By Name</option><option value="ByExtension">By Extension</option></select>
    </div>
  </div>
  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.5rem">
    <strong style="font-size:.9rem">Menu Options</strong>
    <button class="btn btn-sm btn-secondary" id="aa-add-opt">+ Add Option</button>
  </div>
  <div id="aa-opts"></div>
</div></details>

<details><summary>After Hours <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(optional)</span></summary><div class="details-body">
  <p class="text-muted" style="margin-bottom:.75rem;font-size:.85rem">Define business hours per day. Calls outside these times use the After Hours flow.</p>
  <table style="width:100%;margin-bottom:1rem;font-size:.85rem">
    <thead><tr><th style="text-align:left;padding:.3rem .5rem;color:var(--text-muted)">Day</th><th style="padding:.3rem .5rem;color:var(--text-muted)">Active</th><th style="padding:.3rem .5rem;color:var(--text-muted)">Start</th><th style="padding:.3rem .5rem;color:var(--text-muted)">End</th></tr></thead>
    <tbody id="aa-bh-rows"></tbody>
  </table>
  <div class="form-group"><label class="form-label">After-Hours Greeting (TTS)</label><textarea class="form-textarea" id="aa-ah-greet" rows="2" placeholder="Our office is currently closed..."></textarea></div>
  <div class="form-group"><label class="form-label">After-Hours Menu Prompt (TTS)</label><textarea class="form-textarea" id="aa-ah-menu-prompt" rows="2" placeholder="Press 1 to leave a voicemail..."></textarea></div>
  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.5rem">
    <strong style="font-size:.9rem">After-Hours Menu Options</strong>
    <button class="btn btn-sm btn-secondary" id="aa-ah-add-opt">+ Add Option</button>
  </div>
  <div id="aa-ah-opts"></div>
</div></details>

<details><summary>Holidays <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(optional)</span></summary><div class="details-body">
  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.5rem">
    <span class="text-muted" style="font-size:.85rem">Add date ranges with a custom greeting for each holiday.</span>
    <button class="btn btn-sm btn-secondary" id="aa-add-hol">+ Add Holiday</button>
  </div>
  <div id="aa-hols"></div>
</div></details>

<details><summary>Dial Scope <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(optional — for Dial-by-Name)</span></summary><div class="details-body">
  <div class="form-group"><label class="form-label">Inclusion Scope — AAD Group IDs (comma-separated)</label><input type="text" class="form-input" id="aa-incl" placeholder="groupObjectId1,groupObjectId2"></div>
  <div class="form-group"><label class="form-label">Exclusion Scope — AAD Group IDs (comma-separated)</label><input type="text" class="form-input" id="aa-excl" placeholder="groupObjectId1,groupObjectId2"></div>
</div></details>

<details><summary>Advanced</summary><div class="details-body">
  <div class="form-toggle mb-2"><input type="checkbox" id="aa-vr"><label class="form-label" for="aa-vr">Enable Voice Response (speech recognition for menu input)</label></div>
  <div class="form-group"><label class="form-label">Dial-by-Name Disambiguation <span style="font-weight:400;color:var(--text-muted)">— appended to name when duplicates exist</span></label>
    <select class="form-select" id="aa-une">
      <option value="">None (name only)</option>
      <option value="Office">Append Office</option>
      <option value="Department">Append Department</option>
    </select>
  </div>
</div></details>`,
'<button class="btn btn-secondary" onclick="Modal.hide()">Cancel</button><button class="btn btn-primary" id="aa-go">Create</button>');

        document.getElementById('aa-dbn').addEventListener('change',e=>{
            document.getElementById('aa-dbn-method-wrap').style.display=e.target.checked?'':'none';
        });
        this._renderBHRows();
        document.getElementById('aa-add-opt').addEventListener('click',()=>{
            this._menuOpts.push({key:String(this._menuOpts.length+1),action:'DisconnectCall',targetType:'ApplicationEndpoint',targetId:'',announcementText:'',enableTranscription:false});
            this._renderOpts('aa-opts',this._menuOpts,'menuOpts');
        });
        document.getElementById('aa-ah-add-opt').addEventListener('click',()=>{
            this._ahMenuOpts.push({key:String(this._ahMenuOpts.length+1),action:'DisconnectCall',targetType:'ApplicationEndpoint',targetId:'',announcementText:'',enableTranscription:false});
            this._renderOpts('aa-ah-opts',this._ahMenuOpts,'ahMenuOpts');
        });
        document.getElementById('aa-add-hol').addEventListener('click',()=>{
            this._holidays.push({name:'Holiday '+(this._holidays.length+1),dateRanges:[{start:'',end:''}],flow:{greetingText:'',menuPromptText:''}});
            this._renderHolidays();
        });
        document.getElementById('aa-go').addEventListener('click',async()=>{
            const name=document.getElementById('aa-name').value;
            if(!name){Toast.warning('Name required');return;}
            const body={
                name,language:document.getElementById('aa-lang').value,timeZone:document.getElementById('aa-tz').value,
                resourceAccountId:document.getElementById('aa-ra').value||null,
                enableVoiceResponse:document.getElementById('aa-vr').checked,
                userNameExtension:document.getElementById('aa-une').value||null,
                defaultFlow:{
                    greetingText:document.getElementById('aa-greet').value||null,
                    menuPromptText:document.getElementById('aa-menu-prompt').value||null,
                    menuOptions:this._menuOpts,
                    enableDialByName:document.getElementById('aa-dbn').checked,
                    directorySearchMethod:document.getElementById('aa-dbn-method').value
                }
            };
            // Operator
            const opId=document.getElementById('aa-op-id').value.trim();
            const opType=document.getElementById('aa-op-type').value;
            if(opId&&opType){body.operatorId=opId;body.operatorType=opType;}
            // After-hours
            const bhRows=document.querySelectorAll('#aa-bh-rows tr');
            const days=['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
            const businessHours={};
            bhRows.forEach((row,i)=>{
                const active=row.querySelector('.bh-active');
                if(active&&active.checked)businessHours[days[i]]={start:row.querySelector('.bh-start').value,end:row.querySelector('.bh-end').value};
            });
            const ahGreet=document.getElementById('aa-ah-greet').value;
            const ahMenuPrompt=document.getElementById('aa-ah-menu-prompt').value;
            if(Object.keys(businessHours).length||ahGreet||this._ahMenuOpts.length){
                body.afterHours={businessHours,flow:{greetingText:ahGreet||null,menuPromptText:ahMenuPrompt||null,menuOptions:this._ahMenuOpts}};
            }
            // Holidays
            if(this._holidays.length)body.holidays=this._holidays;
            // Dial scope
            const inclRaw=document.getElementById('aa-incl').value;
            const exclRaw=document.getElementById('aa-excl').value;
            if(inclRaw)body.inclusionScopeGroupIds=inclRaw.split(',').map(s=>s.trim()).filter(Boolean);
            if(exclRaw)body.exclusionScopeGroupIds=exclRaw.split(',').map(s=>s.trim()).filter(Boolean);
            Toast.info('Creating AA...');Modal.hide();
            try{const r=await API.createAutoAttendant(body);r.success?Toast.success('Created: '+name):Toast.error(r.error);await this.load();}catch(e){Toast.error(e.message);}
        });
        this._renderOpts('aa-opts',this._menuOpts,'menuOpts');
        this._renderOpts('aa-ah-opts',this._ahMenuOpts,'ahMenuOpts');
        this._renderHolidays();
    },
    _renderBHRows(){
        const days=[['monday','Mon'],['tuesday','Tue'],['wednesday','Wed'],['thursday','Thu'],['friday','Fri'],['saturday','Sat'],['sunday','Sun']];
        const defaultActive=['monday','tuesday','wednesday','thursday','friday'];
        const tbody=document.getElementById('aa-bh-rows');
        if(!tbody)return;
        tbody.innerHTML=days.map(([day,label])=>`<tr>
  <td style="padding:.3rem .5rem"><strong>${label}</strong></td>
  <td style="padding:.3rem .5rem;text-align:center"><input type="checkbox" class="bh-active" ${defaultActive.includes(day)?'checked':''}></td>
  <td style="padding:.3rem .5rem"><input type="time" class="form-input bh-start" value="08:00" style="padding:.25rem .4rem;font-size:.85rem"></td>
  <td style="padding:.3rem .5rem"><input type="time" class="form-input bh-end" value="17:00" style="padding:.25rem .4rem;font-size:.85rem"></td>
</tr>`).join('');
    },
    _renderOpts(containerId,optsList,listName){
        const ct=document.getElementById(containerId);
        if(!ct)return;
        if(!optsList.length){ct.innerHTML='<p class="text-muted" style="font-size:.85rem">No options configured — callers will be disconnected by default. Click <strong>+ Add Option</strong> to add DTMF key actions (e.g. Press 1 for Sales).</p>';return;}
        const dtmfKeys=['0','1','2','3','4','5','6','7','8','9','*','#'];
        const targetTypes=[['ApplicationEndpoint','AA / CQ (App Endpoint)'],['User','User'],['ExternalPstn','External PSTN'],['SharedVoicemail','Shared Voicemail']];
        ct.innerHTML=optsList.map((o,i)=>`
<div class="card" style="padding:.6rem;margin-bottom:.5rem;background:var(--bg-overlay)">
  <div class="form-row" style="align-items:flex-end;gap:.5rem">
    <div class="form-group" style="flex:0 0 80px;margin-bottom:0">
      <label class="form-label">Key</label>
      <select class="form-select" onchange="AutoAttendantsPage._updateOpt('${listName}',${i},'key',this.value)">
        ${dtmfKeys.map(k=>`<option ${o.key===k?'selected':''} value="${k}">${k}</option>`).join('')}
      </select>
    </div>
    <div class="form-group" style="flex:1;margin-bottom:0">
      <label class="form-label">Action</label>
      <select class="form-select" onchange="AutoAttendantsPage._updateOpt('${listName}',${i},'action',this.value);AutoAttendantsPage._renderOpts('${containerId}',AutoAttendantsPage._getOptsList('${listName}'),'${listName}')">
        <option ${o.action==='DisconnectCall'?'selected':''} value="DisconnectCall">Disconnect</option>
        <option ${o.action==='TransferCallToOperator'?'selected':''} value="TransferCallToOperator">Transfer to Operator</option>
        <option ${o.action==='TransferCallToTarget'?'selected':''} value="TransferCallToTarget">Transfer to Target</option>
        <option ${o.action==='Announcement'?'selected':''} value="Announcement">Announcement (play message)</option>
      </select>
    </div>
    <div style="flex:0 0 auto;align-self:flex-end;padding-bottom:.05rem">
      <button class="btn btn-sm btn-danger" onclick="AutoAttendantsPage._removeOpt('${listName}',${i});AutoAttendantsPage._renderOpts('${containerId}',AutoAttendantsPage._getOptsList('${listName}'),'${listName}')">✕</button>
    </div>
  </div>
  ${o.action==='TransferCallToTarget'?`
  <div class="form-row" style="margin-top:.4rem;gap:.5rem">
    <div class="form-group" style="flex:1;margin-bottom:0">
      <label class="form-label">Target Type</label>
      <select class="form-select" onchange="AutoAttendantsPage._updateOpt('${listName}',${i},'targetType',this.value);AutoAttendantsPage._renderOpts('${containerId}',AutoAttendantsPage._getOptsList('${listName}'),'${listName}')">
        ${targetTypes.map(([v,l])=>`<option ${o.targetType===v?'selected':''} value="${v}">${l}</option>`).join('')}
      </select>
    </div>
    <div class="form-group" style="flex:2;margin-bottom:0">
      <label class="form-label">Target Identity (ObjectId / SIP)</label>
      <input type="text" class="form-input" value="${o.targetId||''}" onchange="AutoAttendantsPage._updateOpt('${listName}',${i},'targetId',this.value)" placeholder="ObjectId or sip:user@domain.com">
    </div>
    ${o.targetType==='SharedVoicemail'?`
    <div class="form-group" style="flex:0 0 auto;margin-bottom:0">
      <label class="form-label">Transcription</label>
      <div class="form-toggle"><input type="checkbox" ${o.enableTranscription?'checked':''} onchange="AutoAttendantsPage._updateOpt('${listName}',${i},'enableTranscription',this.checked)"><label class="form-label">On</label></div>
    </div>`:''}
  </div>`:''}
  ${o.action==='Announcement'?`
  <div class="form-group" style="margin-top:.4rem;margin-bottom:0">
    <label class="form-label">Announcement Text (TTS)</label>
    <textarea class="form-textarea" rows="2" onchange="AutoAttendantsPage._updateOpt('${listName}',${i},'announcementText',this.value)">${o.announcementText||''}</textarea>
  </div>`:''}
</div>`).join('');
    },
    _updateOpt(listName,i,key,value){const list=this._getOptsList(listName);if(list[i])list[i][key]=value;},
    _removeOpt(listName,i){this._getOptsList(listName).splice(i,1);},
    _getOptsList(listName){return listName==='menuOpts'?this._menuOpts:listName==='ahMenuOpts'?this._ahMenuOpts:[];},
    _renderHolidays(){
        const ct=document.getElementById('aa-hols');
        if(!ct)return;
        if(!this._holidays.length){ct.innerHTML='<p class="text-muted" style="font-size:.85rem">No holidays. Click + Add Holiday to add one.</p>';return;}
        ct.innerHTML=this._holidays.map((h,i)=>`
<div class="card" style="padding:.6rem;margin-bottom:.5rem;background:var(--bg-overlay)">
  <div class="form-row" style="align-items:flex-end;gap:.5rem">
    <div class="form-group" style="flex:2;margin-bottom:0">
      <label class="form-label">Holiday Name</label>
      <input type="text" class="form-input" value="${h.name}" onchange="AutoAttendantsPage._holidays[${i}].name=this.value">
    </div>
    <div class="form-group" style="flex:1;margin-bottom:0">
      <label class="form-label">Start Date</label>
      <input type="date" class="form-input" value="${h.dateRanges[0].start||''}" onchange="AutoAttendantsPage._holidays[${i}].dateRanges[0].start=this.value">
    </div>
    <div class="form-group" style="flex:1;margin-bottom:0">
      <label class="form-label">End Date</label>
      <input type="date" class="form-input" value="${h.dateRanges[0].end||''}" onchange="AutoAttendantsPage._holidays[${i}].dateRanges[0].end=this.value">
    </div>
    <div style="flex:0 0 auto;align-self:flex-end;padding-bottom:.05rem">
      <button class="btn btn-sm btn-danger" onclick="AutoAttendantsPage._holidays.splice(${i},1);AutoAttendantsPage._renderHolidays()">✕</button>
    </div>
  </div>
  <div class="form-group" style="margin-top:.4rem;margin-bottom:0">
    <label class="form-label">Holiday Greeting (TTS)</label>
    <textarea class="form-textarea" rows="2" onchange="AutoAttendantsPage._holidays[${i}].flow.greetingText=this.value">${(h.flow&&h.flow.greetingText)||''}</textarea>
  </div>
  <div class="form-group" style="margin-top:.4rem;margin-bottom:0">
    <label class="form-label">Holiday Menu Prompt (TTS) <span style="font-weight:400;color:var(--text-muted)">— optional, read after greeting to present options</span></label>
    <textarea class="form-textarea" rows="2" onchange="AutoAttendantsPage._holidays[${i}].flow.menuPromptText=this.value">${(h.flow&&h.flow.menuPromptText)||''}</textarea>
  </div>
</div>`).join('');
    }
};