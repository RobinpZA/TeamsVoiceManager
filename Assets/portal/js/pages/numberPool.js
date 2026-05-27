const NumberPoolPage={
    _showAvailableOnly:false,
    async render(c){
        c.innerHTML=`<div class="page-header"><h1>Number Pool</h1><p>Manage and assign Direct Routing phone numbers. Use "Sync from Teams" to discover all numbers assigned to your tenant.</p></div>
<div class="card"><div class="card-header"><h2>Upload Phone Numbers</h2></div><div id="nuz"></div></div>
<div class="card"><div class="card-header"><h2>Number Pool</h2><div class="btn-group"><button class="btn btn-sm btn-secondary" id="bnr">Refresh</button><button class="btn btn-sm btn-accent" id="bns" title="Fetch all Direct Routing numbers from Teams and update pool status">Sync from Teams</button><button class="btn btn-sm btn-secondary" id="bnavail" title="Toggle showing only available numbers">Available Only</button><button class="btn btn-sm btn-secondary" id="bne">Export</button></div></div>
<div id="nps" class="mb-2"></div><div id="npt"></div></div>`;
        FileUpload.render(document.getElementById('nuz'),{label:'Drop CSV with PhoneNumber column (E.164, e.g. +27xxxxxxxxx)',onParsed:async(rows)=>{
            try{const r=await API.importNumberPool(rows);Toast.success('Imported: '+r.added+' added, '+r.skipped+' skipped');await this.loadPool()}catch(e){Toast.error(e.message)}
        }});
        document.getElementById('bnr').addEventListener('click',()=>this.loadPool());
        document.getElementById('bne').addEventListener('click',async()=>{try{const r=await API.exportNumberPool();Toast.success('Pool exported ('+r.numbers.length+' numbers)')}catch(e){Toast.error(e.message)}});
        document.getElementById('bnavail').addEventListener('click',()=>{
            this._showAvailableOnly=!this._showAvailableOnly;
            const btn=document.getElementById('bnavail');
            btn.classList.toggle('btn-primary',this._showAvailableOnly);
            btn.classList.toggle('btn-secondary',!this._showAvailableOnly);
            this.loadPool();
        });
        document.getElementById('bns').addEventListener('click',()=>this.syncFromTeams());
        await this.loadPool();
    },
    async syncFromTeams(){
        const btn=document.getElementById('bns');
        btn.disabled=true;btn.textContent='Syncing...';
        try{
            const r=await API.syncNumberPool();
            if(r.success){
                Toast.success('Synced from Teams — '+r.added+' added, '+r.updated+' updated');
                await this.loadPool();
            }else{
                Toast.error('Sync failed: '+(r.error||'Unknown error'));
            }
        }catch(e){Toast.error(e.message)}
        finally{btn.disabled=false;btn.textContent='Sync from Teams'}
    },
    async loadPool(){
        try{
            const d=await API.getNumberPool();const s=d.stats||{};
            document.getElementById('nps').innerHTML=`<div class="flex gap-1"><span class="badge badge-info">Total: ${s.total||0}</span><span class="badge badge-success">Available: ${s.available||0}</span><span class="badge badge-accent">Assigned: ${s.assigned||0}</span><span class="badge badge-warning">Reserved: ${s.reserved||0}</span></div>`;
            const numbers=this._showAvailableOnly?(d.numbers||[]).filter(n=>n.status==='Available'):(d.numbers||[]);
            DataTable.render(document.getElementById('npt'),{columns:[
                {key:'phoneNumber',label:'Phone Number',render:v=>'<span class="mono">'+esc(v)+'</span>'},
                {key:'description',label:'Description'},
                {key:'status',label:'Status',render:v=>{const m={Available:'badge-success',Assigned:'badge-accent',Reserved:'badge-warning'};return '<span class="badge '+(m[v]||'badge-neutral')+'">'+esc(v)+'</span>'}},
                {key:'assignedTo',label:'Assigned To',render:v=>v?esc(v):'<span class="text-muted">\u2014</span>'},
                {key:'assignedDate',label:'Date'}
            ],data:numbers,
            actions:[{label:'Quick Assign',class:'btn-primary',onClick:r=>this.quickAssign(r)}],
            emptyMessage:this._showAvailableOnly?'No available numbers in pool.':'No numbers in pool. Click "Sync from Teams" or upload a CSV above.'});
        }catch(e){Toast.error(e.message)}
    },
    quickAssign(num){
        if(num.status==='Assigned'){Toast.warning('Already assigned to '+num.assignedTo);return}
        Modal.show('Assign '+num.phoneNumber,'<div class="form-group"><label class="form-label">User (UPN)</label><input type="text" class="form-input" id="qa-upn" placeholder="user@contoso.com"></div>',
        '<button class="btn btn-secondary" onclick="Modal.hide()">Cancel</button><button class="btn btn-primary" id="qa-go">Assign</button>');
        document.getElementById('qa-go').addEventListener('click',async()=>{
            const upn=document.getElementById('qa-upn').value.trim();if(!upn){Toast.warning('Enter UPN');return}
            try{const r=await API.setUserPhone(upn,{phoneNumber:num.phoneNumber});r.success?Toast.success('Assigned'):Toast.error(r.error);Modal.hide();await this.loadPool()}catch(e){Toast.error(e.message)}
        });
    }
};