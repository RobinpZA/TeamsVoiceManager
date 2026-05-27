// HTML-escape utility — use for all API-sourced text inserted into innerHTML
function esc(s) {
    if (s == null) return '';
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#x27;');
}

const API={
    baseUrl:'',
    async request(m,p,b=null){const o={method:m,headers:{'Content-Type':'application/json'}};if(b)o.body=JSON.stringify(b);try{const r=await fetch(this.baseUrl+p,o);const d=await r.json();if(!r.ok)throw new Error(d.error||'HTTP '+r.status);return d}catch(e){if(e.message==='Failed to fetch')Toast.show('Connection lost','error');throw e}},
    get(p){return this.request('GET',p)},post(p,b){return this.request('POST',p,b)},put(p,b){return this.request('PUT',p,b)},del(p,b){return this.request('DELETE',p,b)},

    getDashboard(){return this.get('/api/dashboard')},

    getDomains(){return this.get('/api/domains')},
    addDomain(n){return this.post('/api/domains',{domainName:n})},
    getDomainTxt(n){return this.get('/api/domains/'+encodeURIComponent(n)+'/txt')},
    verifyDomain(n){return this.post('/api/domains/'+encodeURIComponent(n)+'/verify')},
    createValidationUser(domainName,assignLicense){return this.post('/api/domains/validation-user',{domainName,assignLicense})},
    removeValidationUserLicense(upn){return this.post('/api/domains/validation-user/license',{upn})},

    getVoiceConfig(){return this.get('/api/voice-config')},
    setVoiceConfig(c){return this.post('/api/voice-config',c)},
    getNormalizationRules(){return this.get('/api/voice-config/normalization')},
    setNormalizationRules(r){return this.post('/api/voice-config/normalization',r)},

    getAuthStatus(){return this.get('/api/auth/status')},
    connect(){return this.post('/api/auth/connect',{})},
    disconnect(){return this.post('/api/auth/disconnect',{})},

    getUsers(s='',p=1,ps=50,withNumbers=false,withoutNumbers=false){let u='/api/users?search='+encodeURIComponent(s)+'&page='+p+'&pageSize='+ps;if(withNumbers)u+='&withNumbers=true';if(withoutNumbers)u+='&withoutNumbers=true';return this.get(u)},
    getUserVoice(id){return this.get('/api/users/'+encodeURIComponent(id)+'/voice')},
    setUserLicense(id,b){return this.post('/api/users/'+encodeURIComponent(id)+'/license',b)},
    setUserPhone(id,b){return this.post('/api/users/'+encodeURIComponent(id)+'/phone',b)},
    removeUserPhone(id,b){return this.del('/api/users/'+encodeURIComponent(id)+'/phone',b)},
    bulkAssignNumbers(a){return this.post('/api/users/bulk-assign',{assignments:a})},

    getNumberPool(){return this.get('/api/number-pool')},
    getAvailableNumbers(){return this.get('/api/number-pool/available')},
    syncNumberPool(){return this.post('/api/number-pool/sync',{})},
    importNumberPool(n){return this.post('/api/number-pool/import',{numbers:n})},
    exportNumberPool(){return this.get('/api/number-pool/export')},

    getResourceAccounts(){return this.get('/api/resource-accounts')},
    createResourceAccount(b){return this.post('/api/resource-accounts',b)},
    setRALicense(id,b){return this.post('/api/resource-accounts/'+encodeURIComponent(id)+'/license',b)},
    setRAPhone(id,b){return this.post('/api/resource-accounts/'+encodeURIComponent(id)+'/phone',b)},

    getAutoAttendants(){return this.get('/api/auto-attendants')},
    createAutoAttendant(b){return this.post('/api/auto-attendants',b)},
    updateAutoAttendant(id,b){return this.put('/api/auto-attendants/'+encodeURIComponent(id),b)},
    getAutoAttendantFlow(id){return this.get('/api/auto-attendants/'+encodeURIComponent(id)+'/flow')},

    getCallQueues(){return this.get('/api/call-queues')},
    createCallQueue(b){return this.post('/api/call-queues',b)},
    updateCallQueue(id,b){return this.put('/api/call-queues/'+encodeURIComponent(id),b)},

    setAssociation(b){return this.post('/api/associations',b)},
    uploadAudio(b){return this.post('/api/audio-files',b)},
    getLanguages(){return this.get('/api/languages')},
    getTimezones(){return this.get('/api/timezones')},
    getAuditLog(){return this.get('/api/audit-log')},
    exportAuditLog(){return this.get('/api/audit-log/export')},
    shutdown(){return this.post('/api/shutdown')}
};
