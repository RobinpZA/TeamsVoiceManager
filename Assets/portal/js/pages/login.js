const LoginPage = {
    async render(c) {
        c.innerHTML = `
<div style="display:flex;align-items:center;justify-content:center;height:calc(100vh - 4rem)">
<div class="card" style="max-width:460px;width:100%;text-align:center;padding:2.5rem 2rem">
    <div style="font-size:3.5rem;margin-bottom:1.25rem">&#x1F512;</div>
    <h2 style="font-size:1.35rem;font-weight:700;margin-bottom:.5rem">Sign in to Microsoft 365</h2>
    <p class="text-muted" style="font-size:.875rem;margin-bottom:1.75rem;line-height:1.5">
        A Microsoft sign-in window will open in your browser.<br>
        Complete authentication to access TeamsVoiceManager.
    </p>
    <button class="btn btn-primary" id="btnSignIn" style="width:100%;justify-content:center;padding:.75rem 1rem;font-size:.95rem">
        &#x1F511;&nbsp; Sign in with Microsoft
    </button>
    <div id="loginStatus" class="mt-2" style="min-height:1.75rem;font-size:.85rem"></div>
</div>
</div>`;
        document.getElementById('btnSignIn').addEventListener('click', () => this.signIn());
    },

    async signIn() {
        const btn    = document.getElementById('btnSignIn');
        const status = document.getElementById('loginStatus');
        btn.disabled = true;
        btn.innerHTML = '<div class="spinner" style="width:16px;height:16px;border-width:2px;margin-right:.5rem;display:inline-block;vertical-align:middle"></div> Waiting for sign-in\u2026';
        status.innerHTML = '<span class="text-muted">A sign-in window has opened \u2014 complete authentication to continue.</span>';
        try {
            const r = await API.connect();
            if (r.success) {
                status.innerHTML = '<span class="text-success">&#x2713; Connected as ' + (r.adminUpn || '') + '</span>';
                document.getElementById('btnLogout').classList.remove('hidden');
                await App.navigateTo('dashboard');
            } else {
                status.innerHTML = '<span class="text-error">' + (r.error || 'Authentication failed') + '</span>';
                btn.disabled = false;
                btn.innerHTML = '&#x1F511;&nbsp; Sign in with Microsoft';
            }
        } catch (e) {
            status.innerHTML = '<span class="text-error">' + e.message + '</span>';
            btn.disabled = false;
            btn.innerHTML = '&#x1F511;&nbsp; Sign in with Microsoft';
        }
    }
};
