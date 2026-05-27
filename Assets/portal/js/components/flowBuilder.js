/**
 * FlowBuilder — reusable call-flow editor component.
 *
 * Usage:
 *   const builder = FlowBuilder.create(containerEl, { title: 'Business Hours Flow' });
 *   const flow = builder.getValue();   // returns { greetingText, menuOptions: [...] }
 *   builder.setValue(existingFlow);    // populate from saved data
 */
const FlowBuilder = {
    _nextId: 1,

    /**
     * Creates a FlowBuilder inside the given DOM element.
     * @param {HTMLElement} container
     * @param {Object}      opts        Optional { title }
     * @returns {{ getValue, setValue, getElement }}
     */
    create(container, opts = {}) {
        const title = opts.title || 'Call Flow';
        const uid   = 'fb_' + (this._nextId++);

        container.innerHTML = `
<div class="flow-builder" id="${uid}">
  <h4 class="flow-builder-title">${title}</h4>

  <div class="form-group">
    <label class="form-label">Greeting</label>
    <div class="flow-greeting-tabs mb-1">
      <button type="button" class="btn btn-sm btn-secondary active" data-tab="tts">Text-to-Speech</button>
      <button type="button" class="btn btn-sm btn-secondary ml-1" data-tab="audio">Audio File</button>
    </div>
    <div data-panel="tts">
      <textarea class="form-input form-textarea flow-greeting-tts" rows="2"
                placeholder="Enter greeting text…"></textarea>
    </div>
    <div data-panel="audio" class="hidden">
      <div class="file-upload-zone flow-audio-drop">
        <div class="upload-icon">🎵</div>
        <p>Drop .wav / .mp3 or click to select</p>
        <input type="file" accept=".wav,.mp3" class="hidden flow-audio-input">
      </div>
      <p class="flow-audio-name text-muted mt-1"></p>
    </div>
  </div>

  <div class="form-group">
    <div class="toolbar">
      <label class="form-label mb-0">Menu Options</label>
      <button type="button" class="btn btn-sm btn-secondary flow-add-option">+ Add Option</button>
    </div>
    <div class="flow-options-list mt-1"></div>
    <p class="flow-empty-hint text-muted" style="font-size:.8rem">
      No menu options — caller will hear the greeting and the call will end.
    </p>
  </div>
</div>`;

        const root      = container.querySelector('#' + uid);
        const optsList  = root.querySelector('.flow-options-list');
        const emptyHint = root.querySelector('.flow-empty-hint');

        // --- Greeting tab switching ---
        root.querySelectorAll('[data-tab]').forEach(btn => {
            btn.addEventListener('click', () => {
                root.querySelectorAll('[data-tab]').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                const panel = btn.dataset.tab;
                root.querySelectorAll('[data-panel]').forEach(p => {
                    p.classList.toggle('hidden', p.dataset.panel !== panel);
                });
            });
        });

        // --- Audio file drop zone ---
        const dropZone  = root.querySelector('.flow-audio-drop');
        const fileInput = root.querySelector('.flow-audio-input');
        const fileName  = root.querySelector('.flow-audio-name');

        dropZone.addEventListener('click', () => fileInput.click());
        dropZone.addEventListener('dragover', e => { e.preventDefault(); dropZone.classList.add('drag-over'); });
        dropZone.addEventListener('dragleave', () => dropZone.classList.remove('drag-over'));
        dropZone.addEventListener('drop', e => {
            e.preventDefault();
            dropZone.classList.remove('drag-over');
            const file = e.dataTransfer.files[0];
            if (file) { root._audioFile = file; fileName.textContent = file.name; }
        });
        fileInput.addEventListener('change', () => {
            const file = fileInput.files[0];
            if (file) { root._audioFile = file; fileName.textContent = file.name; }
        });

        // --- Add option button ---
        root.querySelector('.flow-add-option').addEventListener('click', () => {
            addOption(optsList, emptyHint);
        });

        function syncEmptyHint() {
            emptyHint.style.display = optsList.children.length === 0 ? 'block' : 'none';
        }
        syncEmptyHint();

        function addOption(list, hint, data = {}) {
            const row = document.createElement('div');
            row.className = 'flow-option-row';
            row.innerHTML = `
<div class="flow-option-grid">
  <select class="form-select form-select-sm flow-opt-key" title="Key press">
    ${['Automatic','0','1','2','3','4','5','6','7','8','9','*','#'].map(k =>
        `<option value="${k}" ${data.key === k ? 'selected' : ''}>${k}</option>`
    ).join('')}
  </select>
  <select class="form-select form-select-sm flow-opt-action" title="Action">
    <option value="DisconnectCall"          ${data.action === 'DisconnectCall'          ? 'selected' : ''}>Disconnect</option>
    <option value="TransferCallToOperator"  ${data.action === 'TransferCallToOperator'  ? 'selected' : ''}>Transfer to Operator</option>
    <option value="TransferCallToTarget"    ${data.action === 'TransferCallToTarget'    ? 'selected' : ''}>Transfer to Target</option>
  </select>
  <div class="flow-opt-target-wrap">
    <select class="form-select form-select-sm flow-opt-target-type" title="Target type">
      <option value="ApplicationEndpoint" ${data.targetType === 'ApplicationEndpoint' ? 'selected' : ''}>Queue / Attendant</option>
      <option value="User"                ${data.targetType === 'User'                ? 'selected' : ''}>User</option>
      <option value="ExternalPstn"        ${data.targetType === 'ExternalPstn'        ? 'selected' : ''}>External PSTN</option>
    </select>
    <input type="text" class="form-input form-input-sm flow-opt-target-id" placeholder="Object ID / phone"
           value="${data.targetId || ''}">
  </div>
  <button type="button" class="btn btn-sm btn-danger flow-opt-remove" title="Remove">✕</button>
</div>`;

            const actionSel  = row.querySelector('.flow-opt-action');
            const targetWrap = row.querySelector('.flow-opt-target-wrap');
            function syncTarget() {
                const needsTarget = actionSel.value === 'TransferCallToTarget';
                targetWrap.style.display = needsTarget ? '' : 'none';
            }
            actionSel.addEventListener('change', syncTarget);
            syncTarget();

            row.querySelector('.flow-opt-remove').addEventListener('click', () => {
                row.remove();
                syncEmptyHint();
            });

            list.appendChild(row);
            syncEmptyHint();
        }

        // --- Public API ---
        function getValue() {
            const activeTab     = root.querySelector('[data-tab].active')?.dataset.tab;
            const greetingText  = activeTab === 'tts'
                ? root.querySelector('.flow-greeting-tts').value.trim()
                : null;
            const audioFile     = root._audioFile || null;

            const menuOptions = Array.from(optsList.querySelectorAll('.flow-option-row')).map(row => ({
                key:        row.querySelector('.flow-opt-key').value,
                action:     row.querySelector('.flow-opt-action').value,
                targetType: row.querySelector('.flow-opt-target-type').value,
                targetId:   row.querySelector('.flow-opt-target-id').value.trim(),
            }));

            return { greetingText, audioFile, menuOptions };
        }

        function setValue(flow) {
            if (!flow) { return; }
            if (flow.greetingText) {
                root.querySelector('.flow-greeting-tts').value = flow.greetingText;
            }
            optsList.innerHTML = '';
            (flow.menuOptions || []).forEach(opt => addOption(optsList, emptyHint, opt));
            syncEmptyHint();
        }

        return { getValue, setValue, getElement: () => root };
    },
};
