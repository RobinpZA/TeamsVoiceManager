const ResourceAccountsPage={
    async render(c){
        c.innerHTML=`<div class="page-header"><h1>Resource Accounts</h1><p>Create and manage resource accounts for Auto Attendants and Call Queues</p></div>
<div class="toolbar"><div class="toolbar-left"><button class="btn btn-primary" id="bcra">+ Create Resource Account</button><button class="btn btn-secondary" id="brra">Refresh</button></div></div>
<div id="rtc"><div class="loading-spinner"><div class="spinner"></div><p>Loading...</p></div></div>`;
        document.getElementById('bcra').addEventListener('click',()=>this.showCreateModal());
        document.getElementById('brra').addEventListener('click',()=>this.load());
        await this.load();
    },
    async load(){
        try{
            const d=await API.getResourceAccounts();
            DataTable.render(document.getElementById('rtc'),{columns:[
                {key:'displayName',label:'Name'},
                {key:'userPrincipalName',label:'UPN'},
                {key:'type',label:'Type',render:v=>'<span class="badge badge-accent">'+esc(v||'\u2014')+'</span>'},
                {key:'hasLicense',label:'License',render:v=>v?'<span class="badge badge-success">Yes</span>':'<span class="badge badge-neutral">No</span>'},
                {key:'phoneNumber',label:'Phone',render:v=>v?'<span class="mono">'+esc(v)+'</span>':'<span class="text-muted">\u2014</span>'}
            ],data:d.accounts||[],
            actions:[
                {label:'License',class:'btn-secondary',onClick:r=>this.licenseRA(r)},
                {label:'Assign #',class:'btn-primary',onClick:r=>this.assignPhone(r)}
            ],emptyMessage:'No resource accounts. Create one to start.'});
        }catch(e){Toast.error(e.message)}
    },
    showCreateModal(){
        Modal.show('Create Resource Account',`
<div class="form-group"><label class="form-label">Display Name</label><input type="text" class="form-input" id="ra-dn" placeholder="RA_AA_MainLine"></div>
<div class="form-group"><label class="form-label">UPN</label><input type="text" class="form-input" id="ra-upn" placeholder="ra_aa_mainline@contoso.onmicrosoft.com"></div>
<div class="form-group"><label class="form-label">Type</label><select class="form-select" id="ra-type"><option value="AutoAttendant">Auto Attendant</option><option value="CallQueue">Call Queue</option></select></div>
<div class="form-group"><label class="form-label">Phone Number (optional)</label><input type="text" class="form-input" id="ra-phone" placeholder="+27xxxxxxxxx"></div>
<div class="form-toggle"><input type="checkbox" id="ra-lic" checked><label class="form-label" for="ra-lic">Assign RA License</label></div>`,
'<button class="btn btn-secondary" onclick="Modal.hide()">Cancel</button><button class="btn btn-primary" id="ra-go">Create</button>');
        document.getElementById('ra-go').addEventListener('click',async()=>{
            const b={displayName:document.getElementById('ra-dn').value,upn:document.getElementById('ra-upn').value,type:document.getElementById('ra-type').value,phoneNumber:document.getElementById('ra-phone').value||null,assignLicense:document.getElementById('ra-lic').checked};
            if(!b.displayName||!b.upn){Toast.warning('Name and UPN required');return}
            Toast.info('Creating resource account...');Modal.hide();
            try{const r=await API.createResourceAccount(b);r.success?Toast.success('Created '+b.displayName):Toast.error(r.error);await this.load()}catch(e){Toast.error(e.message)}
        });
    },
    async licenseRA(ra){
        if(ra.hasLicense){Toast.info(ra.displayName+' already licensed');return}
        try{const r=await API.setRALicense(ra.userPrincipalName,{});r.success?Toast.success('Licensed'):Toast.error(r.error);await this.load()}catch(e){Toast.error(e.message)}
    },
    assignPhone(ra){
        Modal.show('Assign Phone to '+ra.displayName,'<div class="form-group"><label class="form-label">Phone Number</label><input type="text" class="form-input" id="rap" placeholder="+27xxxxxxxxx"></div>',
        '<button class="btn btn-secondary" onclick="Modal.hide()">Cancel</button><button class="btn btn-primary" id="rap-go">Assign</button>');
        document.getElementById('rap-go').addEventListener('click',async()=>{
            const ph=document.getElementById('rap').value.trim();if(!ph){Toast.warning('Enter number');return}
            try{const r=await API.setRAPhone(ra.userPrincipalName,{phoneNumber:ph});r.success?Toast.success('Assigned'):Toast.error(r.error);Modal.hide();await this.load()}catch(e){Toast.error(e.message)}
        });
    }
};