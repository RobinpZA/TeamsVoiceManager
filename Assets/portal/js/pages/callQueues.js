const CallQueuesPage={
    ras:[],
    async render(c){
        c.innerHTML=`<div class="page-header"><h1>Call Queues</h1><p>Create and manage Call Queues with routing, agents, overflow, timeout, and no-agent handling</p></div>
<div class="toolbar"><div class="toolbar-left"><button class="btn btn-primary" id="bcc">+ Create Call Queue</button><button class="btn btn-secondary" id="brc">Refresh</button></div></div>
<div id="ctc"><div class="loading-spinner"><div class="spinner"></div><p>Loading...</p></div></div>`;
        document.getElementById('bcc').addEventListener('click',()=>this.showCreateForm());
        document.getElementById('brc').addEventListener('click',()=>this.load());
        await this.load();
    },
    async load(){
        try{
            const[cqData,raData]=await Promise.all([API.getCallQueues(),API.getResourceAccounts()]);
            if(cqData.error)Toast.error('Call Queues: '+cqData.error);
            this.ras=(raData.accounts||[]).filter(r=>r.type==='CallQueue');
            DataTable.render(document.getElementById('ctc'),{columns:[
                {key:'name',label:'Name'},
                {key:'routingMethod',label:'Routing'},
                {key:'agentCount',label:'Agents'},
                {key:'languageId',label:'Language'},
                {key:'overflowAction',label:'Overflow Action'},
                {key:'timeoutAction',label:'Timeout Action'},
                {key:'overflowThreshold',label:'Max Queue'},
                {key:'timeoutThreshold',label:'Timeout(s)'}
            ],data:cqData.callQueues||[],emptyMessage:'No call queues. Create one to start.',
            actions:[{label:'⟶ Flow',class:'btn-secondary',onClick:r=>CallFlowVisualizer.showCQ(r)}]});
        }catch(e){Toast.error(e.message)}
    },
    async showCreateForm(){
        try{const raData=await API.getResourceAccounts();this.ras=(raData.accounts||[]).filter(r=>r.type==='CallQueue')}catch(e){}
        const raOpts=this.ras.map(r=>`<option value="${esc(r.objectId)}">${esc(r.displayName)}</option>`).join('');
        Modal.show('Create Call Queue',`
<div style="background:var(--bg-overlay);border-left:3px solid var(--accent);padding:.6rem .8rem;border-radius:4px;margin-bottom:1rem;font-size:.85rem;color:var(--text-muted)">
  <strong style="color:var(--text-primary)">Before you start:</strong> Create and license a <strong>Resource Account</strong> (CQ type) on the Resource Accounts page first — you'll need its ObjectId to assign a phone number to this Call Queue.
</div>
<div class="form-row">
  <div class="form-group" style="flex:2"><label class="form-label">Name</label><input type="text" class="form-input" id="cq-name" placeholder="Support Queue"></div>
  <div class="form-group" style="flex:1"><label class="form-label">Language <span style="font-weight:400;color:var(--text-muted)">BCP 47 tag</span></label><input type="text" class="form-input" id="cq-lang" value="en-ZA" placeholder="e.g. en-ZA, en-US"></div>
</div>
<div class="form-group"><label class="form-label">Resource Account</label><select class="form-select" id="cq-ra"><option value="">None</option>${raOpts}</select></div>

<details open><summary>Agents</summary><div class="details-body">
  <div class="form-group"><label class="form-label">Agent Source</label>
    <select class="form-select" id="cq-agent-type" onchange="CallQueuesPage._toggleAgentFields()">
      <option value="users">Individual Users (ObjectIds)</option>
      <option value="groups">Distribution Lists / M365 Groups</option>
      <option value="channel">Teams Channel (Collaborative Calling)</option>
    </select>
  </div>
  <div id="cq-agents-users">
    <div class="form-group"><label class="form-label">User ObjectIds (comma-separated)</label><input type="text" class="form-input" id="cq-agents" placeholder="objectId1,objectId2,objectId3"></div>
  </div>
  <div id="cq-agents-groups" style="display:none">
    <div class="form-group"><label class="form-label">Group / DL ObjectIds (comma-separated)</label><input type="text" class="form-input" id="cq-dls" placeholder="groupObjectId1,groupObjectId2"></div>
  </div>
  <div id="cq-agents-channel" style="display:none">
    <div class="form-group"><label class="form-label">Teams Channel ID <span style="font-weight:400;color:var(--text-muted)">(from Get-TeamChannel)</span></label><input type="text" class="form-input" id="cq-ch-id" placeholder="Channel ID"></div>
    <div class="form-group"><label class="form-label">Channel Owner ObjectId <span style="font-weight:400;color:var(--text-muted)">(role=Owner)</span></label><input type="text" class="form-input" id="cq-ch-owner" placeholder="Owner user ObjectId"></div>
  </div>
</div></details>

<details open><summary>Routing</summary><div class="details-body">
  <div class="form-row">
    <div class="form-group"><label class="form-label">Routing Method</label>
      <select class="form-select" id="cq-rm">
        <option value="Attendant">Attendant (ring all simultaneously)</option>
        <option value="Serial">Serial (ring one at a time in order)</option>
        <option value="RoundRobin">Round Robin</option>
        <option value="LongestIdle">Longest Idle (recommended)</option>
      </select>
    </div>
    <div class="form-group"><label class="form-label">Agent Alert Time (s)</label><input type="number" class="form-input" id="cq-aat" value="30" min="15" max="180"></div>
  </div>
  <div class="form-row">
    <div class="form-toggle"><input type="checkbox" id="cq-pbr" checked><label class="form-label" for="cq-pbr">Presence-Based Routing</label></div>
    <div class="form-toggle"><input type="checkbox" id="cq-cm" checked><label class="form-label" for="cq-cm">Conference Mode</label></div>
    <div class="form-toggle"><input type="checkbox" id="cq-opt" checked><label class="form-label" for="cq-opt">Allow Agent Opt-Out</label></div>
  </div>
</div></details>

<details><summary>Greeting &amp; Music on Hold <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(optional — no greeting, default music on hold)</span></summary><div class="details-body">
  <div class="form-group"><label class="form-label">Welcome Greeting — Text-to-Speech</label><textarea class="form-textarea" id="cq-greet" rows="2" placeholder="Thank you for calling. Please hold while we connect you..."></textarea></div>
  <div class="form-group"><label class="form-label">Welcome Greeting — Audio File ID <span style="font-weight:400;color:var(--text-muted)">(overrides TTS if set)</span></label><input type="text" class="form-input" id="cq-greet-af" placeholder="Audio file ID from Import-PortalAudioFile"></div>
  <div class="form-toggle mb-2"><input type="checkbox" id="cq-defmusic" checked onchange="CallQueuesPage._toggleMusicField()"><label class="form-label" for="cq-defmusic">Use Default Music on Hold</label></div>
  <div class="form-group" id="cq-music-af-wrap" style="display:none">
    <label class="form-label">Custom Music on Hold — Audio File ID</label>
    <input type="text" class="form-input" id="cq-music-af" placeholder="Audio file ID from Import-PortalAudioFile">
  </div>
</div></details>

<details><summary>Overflow Handling <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(default: disconnect with busy after 50 queued calls)</span></summary><div class="details-body">
  <div class="form-row">
    <div class="form-group"><label class="form-label">Max Calls in Queue</label><input type="number" class="form-input" id="cq-ot" value="50" min="0" max="200"></div>
    <div class="form-group"><label class="form-label">Overflow Action</label>
      <select class="form-select" id="cq-oa" onchange="CallQueuesPage._toggleOverflowFields()">
        <option value="DisconnectWithBusy">Disconnect with Busy</option>
        <option value="Forward">Redirect to Target</option>
        <option value="SharedVoicemail">Shared Voicemail</option>
      </select>
    </div>
  </div>
  <div id="cq-of-target-wrap" style="display:none">
    <div class="form-group"><label class="form-label">Overflow Target (User/RA ObjectId or SIP)</label><input type="text" class="form-input" id="cq-of-target" placeholder="ObjectId or sip:user@domain.com"></div>
  </div>
  <div id="cq-of-vm-wrap" style="display:none">
    <div class="form-group"><label class="form-label">Shared Voicemail Group ObjectId</label><input type="text" class="form-input" id="cq-of-vm-target" placeholder="M365 Group ObjectId"></div>
    <div class="form-group"><label class="form-label">Voicemail Greeting (TTS)</label><textarea class="form-textarea" id="cq-of-vm-tts" rows="2" placeholder="We're sorry, all agents are busy. Please leave a message..."></textarea></div>
    <div class="form-toggle"><input type="checkbox" id="cq-of-vm-trans"><label class="form-label" for="cq-of-vm-trans">Enable Voicemail Transcription</label></div>
  </div>
</div></details>

<details><summary>Timeout Handling <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(default: disconnect after 20 min)</span></summary><div class="details-body">
  <div class="form-row">
    <div class="form-group"><label class="form-label">Timeout (s)</label><input type="number" class="form-input" id="cq-tt" value="1200" min="0" max="2700"></div>
    <div class="form-group"><label class="form-label">Timeout Action</label>
      <select class="form-select" id="cq-ta" onchange="CallQueuesPage._toggleTimeoutFields()">
        <option value="Disconnect">Disconnect</option>
        <option value="Forward">Redirect to Target</option>
        <option value="SharedVoicemail">Shared Voicemail</option>
      </select>
    </div>
  </div>
  <div id="cq-to-target-wrap" style="display:none">
    <div class="form-group"><label class="form-label">Timeout Target (User/RA ObjectId or SIP)</label><input type="text" class="form-input" id="cq-to-target" placeholder="ObjectId or sip:user@domain.com"></div>
  </div>
  <div id="cq-to-vm-wrap" style="display:none">
    <div class="form-group"><label class="form-label">Shared Voicemail Group ObjectId</label><input type="text" class="form-input" id="cq-to-vm-target" placeholder="M365 Group ObjectId"></div>
    <div class="form-group"><label class="form-label">Voicemail Greeting (TTS)</label><textarea class="form-textarea" id="cq-to-vm-tts" rows="2" placeholder="We're sorry to have kept you waiting..."></textarea></div>
    <div class="form-toggle"><input type="checkbox" id="cq-to-vm-trans"><label class="form-label" for="cq-to-vm-trans">Enable Voicemail Transcription</label></div>
  </div>
</div></details>

<details><summary>No Agents Handling <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(optional — when no agents are logged in)</span></summary><div class="details-body">
  <div class="form-group"><label class="form-label">No-Agents Action</label>
    <select class="form-select" id="cq-na" onchange="CallQueuesPage._toggleNoAgentFields()">
      <option value="">Queue (default — hold until agent available)</option>
      <option value="Disconnect">Disconnect</option>
      <option value="Forward">Redirect to Target</option>
      <option value="SharedVoicemail">Shared Voicemail</option>
    </select>
  </div>
  <div id="cq-na-target-wrap" style="display:none">
    <div class="form-group"><label class="form-label">No-Agents Target (User/RA ObjectId or SIP)</label><input type="text" class="form-input" id="cq-na-target" placeholder="ObjectId or sip:user@domain.com"></div>
  </div>
  <div id="cq-na-vm-wrap" style="display:none">
    <div class="form-group"><label class="form-label">Shared Voicemail Group ObjectId</label><input type="text" class="form-input" id="cq-na-vm-target" placeholder="M365 Group ObjectId"></div>
    <div class="form-group"><label class="form-label">Voicemail Greeting (TTS)</label><textarea class="form-textarea" id="cq-na-vm-tts" rows="2" placeholder="No agents are available right now..."></textarea></div>
    <div class="form-toggle"><input type="checkbox" id="cq-na-vm-trans"><label class="form-label" for="cq-na-vm-trans">Enable Voicemail Transcription</label></div>
  </div>
</div></details>

<details><summary>Advanced <span style="font-weight:400;font-size:.8rem;color:var(--text-muted)">(optional)</span></summary><div class="details-body">
  <div class="form-group"><label class="form-label">Service Level Threshold (seconds, 0–2400) <span style="font-weight:400;color:var(--text-muted)">— leave blank to disable</span></label><input type="number" class="form-input" id="cq-slt" placeholder="e.g. 30" min="0" max="2400"></div>
  <div class="form-group"><label class="form-label">OBO Resource Account IDs for Outbound Caller ID <span style="font-weight:400;color:var(--text-muted)">(comma-separated)</span></label><input type="text" class="form-input" id="cq-obo" placeholder="resourceAccountId1,resourceAccountId2"></div>
</div></details>`,
'<button class="btn btn-secondary" onclick="Modal.hide()">Cancel</button><button class="btn btn-primary" id="cq-go">Create</button>');

        document.getElementById('cq-go').addEventListener('click',async()=>{
            const name=document.getElementById('cq-name').value;
            if(!name){Toast.warning('Name required');return;}
            const agentType=document.getElementById('cq-agent-type').value;
            const body={
                name,languageId:document.getElementById('cq-lang').value,
                resourceAccountId:document.getElementById('cq-ra').value||null,
                routingMethod:document.getElementById('cq-rm').value,
                agentAlertTime:parseInt(document.getElementById('cq-aat').value),
                allowOptOut:document.getElementById('cq-opt').checked,
                presenceRouting:document.getElementById('cq-pbr').checked,
                conferenceMode:document.getElementById('cq-cm').checked,
                overflowThreshold:parseInt(document.getElementById('cq-ot').value),
                overflowAction:document.getElementById('cq-oa').value,
                timeoutThreshold:parseInt(document.getElementById('cq-tt').value),
                timeoutAction:document.getElementById('cq-ta').value
            };
            // Agents
            if(agentType==='users'){const a=document.getElementById('cq-agents').value.split(',').map(s=>s.trim()).filter(Boolean);if(a.length)body.agentIds=a;}
            else if(agentType==='groups'){const d=document.getElementById('cq-dls').value.split(',').map(s=>s.trim()).filter(Boolean);if(d.length)body.distributionListIds=d;}
            else if(agentType==='channel'){body.channelId=document.getElementById('cq-ch-id').value.trim();body.channelUserObjectId=document.getElementById('cq-ch-owner').value.trim();}
            // Greeting
            const greetAf=document.getElementById('cq-greet-af').value.trim();
            const greetTts=document.getElementById('cq-greet').value.trim();
            if(greetAf)body.welcomeGreetingAudioFileId=greetAf;
            else if(greetTts)body.welcomeGreetingText=greetTts;
            // Music on hold
            const defMusic=document.getElementById('cq-defmusic').checked;
            body.useDefaultMusic=defMusic;
            if(!defMusic){const maf=document.getElementById('cq-music-af').value.trim();if(maf)body.musicOnHoldAudioFileId=maf;}
            // Overflow
            const ofa=body.overflowAction;
            if(ofa==='Forward')body.overflowActionTarget=document.getElementById('cq-of-target').value.trim();
            else if(ofa==='SharedVoicemail'){body.overflowActionTarget=document.getElementById('cq-of-vm-target').value.trim();body.overflowSharedVoicemailText=document.getElementById('cq-of-vm-tts').value.trim()||null;body.enableOverflowSharedVoicemailTranscription=document.getElementById('cq-of-vm-trans').checked;}
            // Timeout
            const ta=body.timeoutAction;
            if(ta==='Forward')body.timeoutActionTarget=document.getElementById('cq-to-target').value.trim();
            else if(ta==='SharedVoicemail'){body.timeoutActionTarget=document.getElementById('cq-to-vm-target').value.trim();body.timeoutSharedVoicemailText=document.getElementById('cq-to-vm-tts').value.trim()||null;body.enableTimeoutSharedVoicemailTranscription=document.getElementById('cq-to-vm-trans').checked;}
            // No-agents
            const naAction=document.getElementById('cq-na').value;
            if(naAction){body.noAgentAction=naAction;
                if(naAction==='Forward')body.noAgentActionTarget=document.getElementById('cq-na-target').value.trim();
                else if(naAction==='SharedVoicemail'){body.noAgentActionTarget=document.getElementById('cq-na-vm-target').value.trim();body.noAgentSharedVoicemailText=document.getElementById('cq-na-vm-tts').value.trim()||null;body.enableNoAgentSharedVoicemailTranscription=document.getElementById('cq-na-vm-trans').checked;}
            }
            // Advanced
            const slt=document.getElementById('cq-slt').value;
            if(slt!=='')body.serviceLevelThresholdSeconds=parseInt(slt);
            const obo=document.getElementById('cq-obo').value.split(',').map(s=>s.trim()).filter(Boolean);
            if(obo.length)body.oboResourceAccountIds=obo;
            Toast.info('Creating CQ...');Modal.hide();
            try{const r=await API.createCallQueue(body);r.success?Toast.success('Created: '+name):Toast.error(r.error);await this.load();}catch(e){Toast.error(e.message);}
        });
    },
    _toggleAgentFields(){
        const v=document.getElementById('cq-agent-type').value;
        document.getElementById('cq-agents-users').style.display=v==='users'?'':'none';
        document.getElementById('cq-agents-groups').style.display=v==='groups'?'':'none';
        document.getElementById('cq-agents-channel').style.display=v==='channel'?'':'none';
    },
    _toggleMusicField(){
        document.getElementById('cq-music-af-wrap').style.display=document.getElementById('cq-defmusic').checked?'none':'';
    },
    _toggleOverflowFields(){
        const v=document.getElementById('cq-oa').value;
        document.getElementById('cq-of-target-wrap').style.display=v==='Forward'?'':'none';
        document.getElementById('cq-of-vm-wrap').style.display=v==='SharedVoicemail'?'':'none';
    },
    _toggleTimeoutFields(){
        const v=document.getElementById('cq-ta').value;
        document.getElementById('cq-to-target-wrap').style.display=v==='Forward'?'':'none';
        document.getElementById('cq-to-vm-wrap').style.display=v==='SharedVoicemail'?'':'none';
    },
    _toggleNoAgentFields(){
        const v=document.getElementById('cq-na').value;
        document.getElementById('cq-na-target-wrap').style.display=v==='Forward'?'':'none';
        document.getElementById('cq-na-vm-wrap').style.display=v==='SharedVoicemail'?'':'none';
    }
};