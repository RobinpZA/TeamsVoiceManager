const UsersPage={
    users:[],
    async render(c){
        c.innerHTML=`<div class="page-header"><h1>Users</h1><p>Manage Teams Phone licenses and phone number assignments</p></div>
<div class="toolbar"><div class="toolbar-left"><div class="search-bar" style="margin-bottom:0"><input type="text" class="form-input" id="us" placeholder="Search by name or UPN..." style="width:300px"><button class="btn btn-secondary" id="bsu">Search</button></div></div>
<div class="toolbar-right"><button class="btn btn-secondary" id="bwn">Users with Numbers</button><button class="btn btn-secondary" id="bwon">Users without Numbers</button><button class="btn btn-secondary" id="bbl">Bulk License</button><button class="btn btn-primary" id="bba">Bulk Number Assign</button></div></div>
<div id="utc"><div class="empty-state"><div class="empty-icon">&#x1F465;</div><h3>Search for users above</h3></div></div>`;
        document.getElementById('bsu').addEventListener('click',()=>this.search());
        document.getElementById('us').addEventListener('keydown',e=>{if(e.key==='Enter')this.search()});
        document.getElementById('bwn').addEventListener('click',()=>this.loadWithNumbers());
        document.getElementById('bwon').addEventListener('click',()=>this.loadWithoutNumbers());
        document.getElementById('bba').addEventListener('click',()=>this.showBulkAssignModal());
        document.getElementById('bbl').addEventListener('click',()=>this.showBulkLicenseModal());
    },
    async search(){
        const s=document.getElementById('us').value.trim();
        await this._renderUsers(()=>API.getUsers(s),'No users matching "'+s+'"');
    },
    async loadWithNumbers(){
        await this._renderUsers(()=>API.getUsers('',1,1000,true,false),'No users with phone numbers found');
    },
    async loadWithoutNumbers(){
        await this._renderUsers(()=>API.getUsers('',1,1000,false,true),'No users without phone numbers found');
    },
    async _renderUsers(fetchFn,emptyMsg){
        const tc=document.getElementById('utc');
        tc.innerHTML='<div class="loading-spinner"><div class="spinner"></div><p>Loading...</p></div>';
        try{
            const d=await fetchFn();this.users=d.users||[];
            DataTable.render(tc,{columns:[
                {key:'displayName',label:'Name'},
                {key:'userPrincipalName',label:'UPN'},
                {key:'hasPhoneLicense',label:'License',render:v=>v?'<span class="badge badge-success">Licensed</span>':'<span class="badge badge-neutral">No</span>'},
                {key:'phoneNumber',label:'Phone',render:v=>v?'<span class="mono">'+esc(v)+'</span>':'<span class="text-muted">\u2014</span>'},
                {key:'voiceRoutingPolicy',label:'Policy',render:v=>v?esc(v):'<span class="text-muted">\u2014</span>'},
                {key:'dialPlan',label:'Dial Plan',render:v=>v?'<span class="badge badge-info">'+esc(v)+'</span>':'<span class="text-muted">\u2014</span>'}
            ],data:this.users,
            actions:[
                {label:'License',class:'btn-secondary',onClick:r=>this.toggleLicense(r)},
                {label:'Assign #',class:'btn-primary',onClick:r=>this.assignPhone(r)},
                {label:'Remove #',class:'btn-danger',onClick:r=>this.removePhone(r)}
            ],emptyMessage:emptyMsg});
        }catch(e){Toast.error(e.message)}
    },
    toggleLicense(user){
        const action=user.hasPhoneLicense?'remove':'assign';
        const label=action==='assign'?'Assign Teams Phone Standard license to':'Remove license from';
        Modal.confirm(action==='assign'?'Assign License':'Remove License',label+' <strong>'+esc(user.displayName)+'</strong>?',async()=>{
            try{const r=await API.setUserLicense(user.userPrincipalName,{action,skuPartNumber:'MCOEV'});r.success?Toast.success('License '+action+'ed for '+user.displayName):Toast.error(r.error);await this.search()}catch(e){Toast.error(e.message)}
        });
    },
    async assignPhone(user){
        // Build modal with a loading state while fetching available numbers
        const bodyHtml='<p class="text-muted mb-2">Assigning to: <strong>'+esc(user.displayName)+'</strong> ('+esc(user.userPrincipalName)+')</p><div id="ap-pool-wrap"><div class="loading-spinner" style="padding:8px 0"><div class="spinner"></div></div></div>';
        Modal.show('Assign Phone Number',bodyHtml,'<button class="btn btn-secondary" onclick="Modal.hide()">Cancel</button><button class="btn btn-primary" id="bap" disabled>Assign</button>');
        let available=[];
        try{const d=await API.getNumberPool();available=(d.numbers||[]).filter(n=>n.status==='Available')}catch(e){/* ignore, fall back to manual */}
        const wrap=document.getElementById('ap-pool-wrap');
        if(available.length>0){
            const opts=available.map(n=>'<option value="'+esc(n.phoneNumber)+'">'+(n.description?esc(n.description)+' — ':'')+esc(n.phoneNumber)+'</option>').join('');
            wrap.innerHTML='<div class="form-group"><label class="form-label">Available Number</label><select class="form-input" id="ap"><option value="">— Select a number —</option>'+opts+'</select></div>';
        }else{
            wrap.innerHTML='<div class="form-group"><label class="form-label">Phone Number (E.164)</label><input type="text" class="form-input" id="ap" placeholder="+27xxxxxxxxx"><p class="text-muted" style="font-size:0.8em;margin-top:4px">No available numbers in pool — enter manually</p></div>';
        }
        const btn=document.getElementById('bap');btn.disabled=false;
        btn.addEventListener('click',async()=>{
            const ph=document.getElementById('ap').value.trim();if(!ph){Toast.warning('Select or enter a number');return}
            try{const r=await API.setUserPhone(user.userPrincipalName,{phoneNumber:ph});r.success?Toast.success('Assigned '+ph+' to '+user.displayName):Toast.error(r.error);Modal.hide();await this.search()}catch(e){Toast.error(e.message)}
        });
    },
    removePhone(user){
        if(!user.phoneNumber){Toast.warning(user.displayName+' has no phone number');return}
        Modal.confirm('Remove Phone Number','Remove <strong>'+esc(user.phoneNumber)+'</strong> from '+esc(user.displayName)+'?',async()=>{
            try{const r=await API.removeUserPhone(user.userPrincipalName,{phoneNumber:user.phoneNumber});r.success?Toast.success('Removed'):Toast.error(r.error);await this.search()}catch(e){Toast.error(e.message)}
        });
    },
    showBulkAssignModal(){
        Modal.show('Bulk Number Assignment','<p class="mb-2">Upload a CSV with columns: <strong>UserPrincipalName, PhoneNumber</strong></p><div id="ba-upload"></div><div id="ba-preview" class="mt-2"></div>',
        '<button class="btn btn-secondary" onclick="Modal.hide()">Cancel</button><button class="btn btn-primary hidden" id="bba-go">Assign All</button>');
        let parsed=[];
        FileUpload.render(document.getElementById('ba-upload'),{label:'Drop CSV (UserPrincipalName, PhoneNumber)',onParsed:(rows)=>{
            parsed=rows;document.getElementById('bba-go').classList.remove('hidden');
            document.getElementById('ba-preview').innerHTML='<p>'+rows.length+' assignments ready.</p>';
        }});
        document.getElementById('bba-go').addEventListener('click',async()=>{
            Toast.info('Processing '+parsed.length+' assignments...');Modal.hide();
            try{const r=await API.bulkAssignNumbers(parsed);Toast.success('Done: '+r.succeeded+' succeeded, '+r.failed+' failed');await this.search()}catch(e){Toast.error(e.message)}
        });
    },
    showBulkLicenseModal(){
        Modal.confirm('Bulk License Assignment','This will assign Teams Phone Standard license to all selected users. Search for users first, then use this action.<br><br>Assign to all '+this.users.length+' currently displayed users?',async()=>{
            let ok=0,fail=0;
            for(const u of this.users){
                if(!u.hasPhoneLicense){try{await API.setUserLicense(u.userPrincipalName,{action:'assign',skuPartNumber:'MCOEV'});ok++}catch(e){fail++}}
            }
            Toast.success('Licensed '+ok+' users'+(fail?' ('+fail+' failed)':''));await this.search();
        });
    }
};