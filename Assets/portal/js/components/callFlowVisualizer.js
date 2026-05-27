/**
 * CallFlowVisualizer — renders SVG call-flow diagrams for Auto Attendants and Call Queues.
 *
 * Approach: build a levels/edges JSON descriptor, then render as an inline SVG.
 * Adapted from the CA-BaselineAuditor renderFlowSvg pattern.
 *
 * Usage:
 *   CallFlowVisualizer.showAA(aaFlowData);  // data from GET /api/auto-attendants/:id/flow
 *   CallFlowVisualizer.showCQ(cqRowData);   // data from the call queues list
 */
const CallFlowVisualizer = {

    // ─── Public entry points ────────────────────────────────────────────

    showAA(aa) {
        if (aa.error) { Toast.error('Flow error: ' + aa.error); return; }
        this._show('Call Flow — ' + aa.name, this._renderFlowSvg(this._buildAAFlow(aa)));
    },

    showCQ(cq) {
        this._show('Call Flow — ' + cq.name, this._renderFlowSvg(this._buildCQFlow(cq)));
    },

    // ─── Overlay management ─────────────────────────────────────────────

    _show(title, svgHtml) {
        const existing = document.getElementById('cfv-overlay');
        if (existing) existing.remove();

        const div = document.createElement('div');
        div.id = 'cfv-overlay';
        div.className = 'cfv-overlay';
        div.innerHTML =
            '<div class="cfv-panel">' +
                '<div class="cfv-header">' +
                    '<span class="cfv-title">' + esc(title) + '</span>' +
                    '<button class="cfv-close" aria-label="Close">&times;</button>' +
                '</div>' +
                '<div class="cfv-canvas"><div class="cfv-svg-wrap">' + svgHtml + '</div></div>' +
            '</div>';

        div.querySelector('.cfv-close').addEventListener('click', () => div.remove());
        div.addEventListener('click', e => { if (e.target === div) div.remove(); });
        document.addEventListener('keydown', function onKey(e) {
            if (e.key === 'Escape') { div.remove(); document.removeEventListener('keydown', onKey); }
        });
        document.body.appendChild(div);
    },

    // ─── Call Queue flow descriptor builder ─────────────────────────────

    _buildCQFlow(cq) {
        const levels = [], edges = [];

        // Level 0: CQ root node
        const routingLabel = { Attendant: 'Attendant (parallel)', Serial: 'Serial', RoundRobin: 'Round Robin', LongestIdle: 'Longest Idle' };
        const agentStr = (cq.agentCount || 0) + ' Agent' + ((cq.agentCount || 0) !== 1 ? 's' : '');
        levels.push([{ type: 'cq', tl: this._wrap(cq.name, 26), items: [routingLabel[cq.routingMethod] || cq.routingMethod || '—', agentStr] }]);

        let prevL = 0;

        // Level 1: Welcome greeting (optional)
        if (cq.welcomeTtsPrompt || cq.welcomeMusicAudioFileId) {
            const greetText = cq.welcomeMusicAudioFileId ? 'Audio file' : this._trunc(cq.welcomeTtsPrompt, 36);
            levels.push([{ type: 'greeting', tl: ['Welcome Greeting'], items: [greetText] }]);
            edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: 0 });
            prevL++;
        }

        // Level N: Queue settings
        const qItems = ['Agent alert: ' + (cq.agentAlertTime || 30) + 's'];
        if (cq.conferenceMode)  qItems.push('Conference Mode on');
        if (cq.presenceRouting) qItems.push('Presence Routing on');
        if (cq.allowOptOut)     qItems.push('Agent Opt-Out on');
        if (cq.serviceLevelThresholdSeconds) qItems.push('SLA: ' + cq.serviceLevelThresholdSeconds + 's');
        levels.push([{ type: 'queue', tl: ['Queue'], items: qItems }]);
        edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: 0 });
        prevL++;

        // Level N+1: Handlers fan-out
        const handlers = [];
        if (cq.overflowAction) {
            const trig = cq.overflowThreshold != null ? '> ' + cq.overflowThreshold + ' calls' : 'When full';
            const items = [trig, this._actionLabel(cq.overflowAction)];
            const ovfTarget = cq.overflowActionTargetName || this._shortId(cq.overflowActionTarget);
            if (ovfTarget) items.push(ovfTarget);
            handlers.push({ type: 'overflow', tl: ['Overflow'], items });
        }
        if (cq.timeoutAction) {
            const trig = cq.timeoutThreshold != null ? '> ' + cq.timeoutThreshold + 's wait' : 'On timeout';
            const items = [trig, this._actionLabel(cq.timeoutAction)];
            const toTarget = cq.timeoutActionTargetName || this._shortId(cq.timeoutActionTarget);
            if (toTarget) items.push(toTarget);
            handlers.push({ type: 'timeout', tl: ['Timeout'], items });
        }
        if (cq.noAgentAction) {
            const items = ['No agents available', this._actionLabel(cq.noAgentAction)];
            const naTarget = cq.noAgentActionTargetName || this._shortId(cq.noAgentActionTarget);
            if (naTarget) items.push(naTarget);
            handlers.push({ type: 'noagent', tl: ['No Agents'], items });
        }
        if (handlers.length) {
            levels.push(handlers);
            for (let i = 0; i < handlers.length; i++) {
                edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: i });
            }
        }

        return { levels, edges };
    },

    // ─── Auto Attendant flow descriptor builder ──────────────────────────

    _buildAAFlow(aa) {
        const levels = [], edges = [];

        // Level 0: AA root node
        const tz  = (aa.timeZone || '').replace(' Standard Time', ' ST');
        const subItems = [aa.language, tz].filter(Boolean);
        levels.push([{ type: 'aa', tl: this._wrap(aa.name, 26), items: subItems }]);

        const df = aa.defaultFlow || {};
        const ah = aa.afterHoursFlow || null;

        if (ah) {
            // Schedule check node
            const schedSub = aa.scheduleHours ? this._schedSummary(aa.scheduleHours) : '';
            levels.push([{ type: 'schedule', tl: ['Business Hours Check'], items: schedSub ? [schedSub] : [] }]);
            edges.push({ fl: 0, fi: 0, tl: 1, ti: 0 });

            // Two branch-summary nodes side by side
            levels.push([
                { type: 'bh', tl: ['\u2600\uFE0F Business Hours'], items: this._flowBranchItems(df) },
                { type: 'ah', tl: ['\uD83C\uDF19 After Hours'],    items: this._flowBranchItems(ah) }
            ]);
            edges.push({ fl: 1, fi: 0, tl: 2, ti: 0 });
            edges.push({ fl: 1, fi: 0, tl: 2, ti: 1 });
        } else {
            // Inline full flow (greeting → menu → options)
            this._appendFlowLevels(df, levels, edges);
        }

        let prevL = levels.length - 1;

        // Holiday summary node
        const holidays = aa.holidayFlows || [];
        if (holidays.length) {
            const names = holidays.slice(0, 4).map(h => (h.scheduleName || 'Holiday') + (h.enabled === false ? ' ⚠️' : ''));
            if (holidays.length > 4) names.push('+' + (holidays.length - 4) + ' more');
            levels.push([{ type: 'holiday', tl: [holidays.length + ' Holiday Flow' + (holidays.length !== 1 ? 's' : '')], items: names }]);
            edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: 0 });
            prevL++;
        }

        // Operator node
        if (aa.operator) {
            const opItems = [];
            const opId = this._shortId(aa.operator.identity);
            if (opId) opItems.push(opId);
            levels.push([{ type: 'operator', tl: ['Operator: ' + (aa.operator.type || 'User')], items: opItems }]);
            edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: 0 });
        }

        return { levels, edges };
    },

    // Appends greeting → menu → options nodes to the existing levels/edges arrays
    _appendFlowLevels(flow, levels, edges) {
        let prevL = levels.length - 1;

        if (!flow) {
            levels.push([{ type: 'disconnect', tl: ['No Flow'], items: ['Not configured'] }]);
            edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: 0 });
            return;
        }

        // Greeting
        if (flow.greetingType && flow.greetingType !== 'None') {
            const greetText = flow.greetingType === 'AudioFile' ? 'Audio file' : this._trunc(flow.greetingText, 36);
            levels.push([{ type: 'greeting', tl: ['Greeting'], items: [greetText] }]);
            edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: 0 });
            prevL++;
        }

        // Menu / Announcement
        const hasOpts = flow.menuOptions && flow.menuOptions.length > 0;
        const menuTitle = hasOpts ? 'Menu' : (flow.menuPromptText ? 'Announcement' : 'Disconnect');
        const menuItems = [];
        if (flow.menuPromptText) menuItems.push(this._trunc(flow.menuPromptText, 36));
        if (flow.enableDialByName) menuItems.push('Dial-by-Name (' + (flow.directoryMethod || 'ByName') + ')');
        levels.push([{ type: 'menu', tl: [menuTitle], items: menuItems }]);
        edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: 0 });
        prevL++;

        // Option nodes (fan-out, capped at 6)
        if (hasOpts) {
            const cap = Math.min(flow.menuOptions.length, 6);
            const optNodes = flow.menuOptions.slice(0, cap).map(opt => {
                const items = [this._actionLabel(opt.action)];
                const dest = opt.targetName || this._shortId(opt.targetId);
                if (dest) items.push(dest);
                return { type: 'option', tl: ['Key ' + (opt.dtmfResponse || '?')], items };
            });
            if (flow.menuOptions.length > cap) {
                optNodes.push({ type: 'option', tl: ['…more'], items: ['+' + (flow.menuOptions.length - cap) + ' options'] });
            }
            levels.push(optNodes);
            for (let i = 0; i < optNodes.length; i++) {
                edges.push({ fl: prevL, fi: 0, tl: prevL + 1, ti: i });
            }
        }
    },

    // Returns a compact text-item summary of a flow branch (used in two-column AA view)
    _flowBranchItems(flow) {
        if (!flow) return ['No flow configured'];
        const items = [];
        if (flow.greetingType && flow.greetingType !== 'None') {
            items.push('Greeting: ' + (flow.greetingType === 'AudioFile' ? 'Audio file' : this._trunc(flow.greetingText, 28)));
        }
        const hasOpts = flow.menuOptions && flow.menuOptions.length > 0;
        if (hasOpts) {
            items.push(flow.menuOptions.length + ' menu option' + (flow.menuOptions.length !== 1 ? 's' : ''));
            flow.menuOptions.slice(0, 3).forEach(opt => {
                const dest = opt.targetName || this._shortId(opt.targetId);
                items.push((opt.dtmfResponse || '?') + ' \u2192 ' + this._actionLabel(opt.action) + (dest ? ': ' + dest : ''));
            });
            if (flow.menuOptions.length > 3) items.push('+' + (flow.menuOptions.length - 3) + ' more\u2026');
        } else if (flow.menuPromptText) {
            items.push('Announcement: ' + this._trunc(flow.menuPromptText, 28));
        } else {
            items.push('Disconnect');
        }
        if (flow.enableDialByName) items.push('Dial-by-Name enabled');
        return items;
    },

    // ─── SVG renderer (adapted from CA-BaselineAuditor renderFlowSvg) ────

    _renderFlowSvg(data) {
        var NW = 200, PAD = 12, LBL_H = 18, DIV_H = 8, TTL_H = 18, ITEM_H = 16, GAP_Y = 52, GAP_X = 18, SIDE = 24;
        var CC = '#4b5563';  // connector / arrowhead colour
        var C = {
            aa:         ['#1a2140', '#4f6ef7', '#93a8fd'],
            cq:         ['#0f1d38', '#3b82f6', '#93c5fd'],
            schedule:   ['#1e1040', '#9333ea', '#c084fc'],
            greeting:   ['#0c2231', '#0891b2', '#22d3ee'],
            menu:       ['#1f1a08', '#b45309', '#f59e0b'],
            option:     ['#0f1e0a', '#4d7c0f', '#a3e635'],
            queue:      ['#1e1040', '#9333ea', '#c084fc'],
            overflow:   ['#2a1508', '#c2410c', '#fb923c'],
            timeout:    ['#2a1508', '#c2410c', '#fb923c'],
            noagent:    ['#2a1508', '#c2410c', '#fb923c'],
            bh:         ['#0a1e0a', '#16a34a', '#4ade80'],
            ah:         ['#12103a', '#6366f1', '#818cf8'],
            holiday:    ['#0a1e10', '#15803d', '#4ade80'],
            operator:   ['#0c2231', '#0891b2', '#22d3ee'],
            disconnect: ['#2a0a0a', '#dc2626', '#f87171'],
        };
        var LBL = {
            aa: 'AUTO ATTENDANT', cq: 'CALL QUEUE',
            schedule: 'SCHEDULE',  greeting: 'GREETING',
            menu: 'MENU',          option: 'OPTION',
            queue: 'QUEUE',        overflow: 'OVERFLOW',
            timeout: 'TIMEOUT',    noagent: 'NO AGENTS',
            bh: 'BUSINESS HOURS',  ah: 'AFTER HOURS',
            holiday: 'HOLIDAYS',   operator: 'OPERATOR',
            disconnect: 'DISCONNECT',
        };
        var FONT = 'Poppins,system-ui,sans-serif';
        var levels = data.levels, edges = data.edges;

        function escX(s) {
            return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        }
        function nodeH(tl, items) {
            return PAD + LBL_H + DIV_H + tl.length * TTL_H + (items.length > 0 ? 10 + items.length * ITEM_H : 8) + PAD;
        }

        var lvlH = levels.map(function(l) {
            return Math.max.apply(null, l.map(function(n) { return nodeH(n.tl, n.items); }));
        });
        var lvlW = levels.map(function(l) {
            return l.length * NW + Math.max(0, l.length - 1) * GAP_X;
        });
        var W = Math.max.apply(null, lvlW) + 2 * SIDE;
        var lvlY = [], cy = SIDE;
        for (var i = 0; i < levels.length; i++) { lvlY.push(cy); cy += lvlH[i] + GAP_Y; }
        var H = cy - GAP_Y + SIDE;

        var nx = levels.map(function(l, li) {
            var sw = (W - lvlW[li]) / 2;
            return l.map(function(_, ni) { return sw + ni * (NW + GAP_X); });
        });
        var ncx = function(li, ni) { return nx[li][ni] + NW / 2; };
        var nby = function(li) { return lvlY[li] + lvlH[li]; };
        var nty = function(li) { return lvlY[li]; };

        var svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + W + ' ' + H + '" width="' + W + '" height="' + H + '" style="display:block">'];
        svg.push('<defs><marker id="cfxArr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto"><path d="M0,1.5 L8.5,5 L0,8.5 Z" fill="' + CC + '"/></marker></defs>');

        // Group edges by (fromLevel, toLevel) pair for bus routing
        var eG = {};
        edges.forEach(function(e) { var k = e.fl + ',' + e.tl; (eG[k] = eG[k] || []).push(e); });

        Object.keys(eG).forEach(function(k) {
            var grp = eG[k], FL = grp[0].fl, TL = grp[0].tl;
            var fis = grp.map(function(e) { return e.fi; }).filter(function(v, i, a) { return a.indexOf(v) === i; });
            var tis = grp.map(function(e) { return e.ti; }).filter(function(v, i, a) { return a.indexOf(v) === i; });
            var midY = nby(FL) + GAP_Y / 2;
            if (fis.length === 1 && tis.length === 1) {
                var fx = ncx(FL, fis[0]), tx = ncx(TL, tis[0]);
                if (Math.abs(fx - tx) < 1) {
                    svg.push('<line x1="' + fx + '" y1="' + nby(FL) + '" x2="' + tx + '" y2="' + nty(TL) + '" stroke="' + CC + '" stroke-width="1.5" marker-end="url(#cfxArr)"/>');
                } else {
                    svg.push('<path d="M' + fx + ',' + nby(FL) + ' V' + midY + ' H' + tx + ' V' + nty(TL) + '" fill="none" stroke="' + CC + '" stroke-width="1.5" marker-end="url(#cfxArr)"/>');
                }
            } else if (fis.length === 1) {
                var fx2 = ncx(FL, fis[0]);
                var xs  = tis.map(function(i) { return ncx(TL, i); });
                svg.push('<line x1="' + fx2 + '" y1="' + nby(FL) + '" x2="' + fx2 + '" y2="' + midY + '" stroke="' + CC + '" stroke-width="1.5"/>');
                svg.push('<line x1="' + Math.min.apply(null, xs) + '" y1="' + midY + '" x2="' + Math.max.apply(null, xs) + '" y2="' + midY + '" stroke="' + CC + '" stroke-width="1.5"/>');
                xs.forEach(function(tx) { svg.push('<line x1="' + tx + '" y1="' + midY + '" x2="' + tx + '" y2="' + nty(TL) + '" stroke="' + CC + '" stroke-width="1.5" marker-end="url(#cfxArr)"/>'); });
            } else {
                var fxs = fis.map(function(i) { return ncx(FL, i); }), tx2 = ncx(TL, tis[0]);
                var mx  = fxs.reduce(function(s, x) { return s + x; }, 0) / fxs.length;
                fxs.forEach(function(fx) { svg.push('<line x1="' + fx + '" y1="' + nby(FL) + '" x2="' + fx + '" y2="' + midY + '" stroke="' + CC + '" stroke-width="1.5"/>'); });
                svg.push('<line x1="' + Math.min.apply(null, fxs) + '" y1="' + midY + '" x2="' + Math.max.apply(null, fxs) + '" y2="' + midY + '" stroke="' + CC + '" stroke-width="1.5"/>');
                svg.push('<path d="M' + mx + ',' + midY + ' H' + tx2 + ' V' + nty(TL) + '" fill="none" stroke="' + CC + '" stroke-width="1.5" marker-end="url(#cfxArr)"/>');
            }
        });

        // Render nodes
        levels.forEach(function(lvl, li) {
            lvl.forEach(function(node, ni) {
                var x = nx[li][ni], y = lvlY[li], h = lvlH[li];
                var col = C[node.type] || C.cq, bg = col[0], border = col[1], lblCol = col[2];
                var lbl = LBL[node.type] || node.type.toUpperCase();
                svg.push('<rect x="' + x + '" y="' + y + '" width="' + NW + '" height="' + h + '" rx="10" fill="' + bg + '" stroke="' + border + '" stroke-width="1.5"/>');
                svg.push('<text x="' + (x + NW / 2) + '" y="' + (y + PAD + 13) + '" text-anchor="middle" fill="' + lblCol + '" font-size="8.5" font-weight="800" letter-spacing="1.3" font-family="' + FONT + '">' + escX(lbl) + '</text>');
                svg.push('<line x1="' + (x + 10) + '" y1="' + (y + PAD + LBL_H) + '" x2="' + (x + NW - 10) + '" y2="' + (y + PAD + LBL_H) + '" stroke="' + border + '" stroke-width="0.75" opacity="0.4"/>');
                var ty = y + PAD + LBL_H + DIV_H;
                node.tl.forEach(function(line) {
                    ty += TTL_H;
                    svg.push('<text x="' + (x + NW / 2) + '" y="' + ty + '" text-anchor="middle" fill="#e5e7eb" font-size="12" font-weight="600" font-family="' + FONT + '">' + escX(line) + '</text>');
                });
                if (node.items.length > 0) {
                    ty += 10;
                    node.items.forEach(function(item) {
                        ty += ITEM_H;
                        var s = item.length > 30 ? item.slice(0, 29) + '\u2026' : item;
                        svg.push('<text x="' + (x + NW / 2) + '" y="' + ty + '" text-anchor="middle" fill="#9ca3af" font-size="10" font-family="' + FONT + '">' + escX(s) + '</text>');
                    });
                }
            });
        });

        svg.push('</svg>');
        return svg.join('');
    },

    // ─── Helpers ─────────────────────────────────────────────────────────

    _actionLabel(action) {
        const map = {
            TransferCallToTarget:    'Transfer \u2192',
            TransferCallToOperator:  'Transfer to Operator',
            DisconnectCall:          'Disconnect',
            Disconnect:              'Disconnect',
            DisconnectWithBusy:      'Busy / Disconnect',
            Forward:                 'Forward \u2192',
            SharedVoicemail:         'Shared Voicemail',
            Voicemail:               'Voicemail',
            Announcement:            'Announcement',
        };
        return map[action] || action || '\u2014';
    },

    _shortId(id) {
        if (!id) return '';
        if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
            return id.substring(0, 8) + '\u2026';
        }
        return id.length > 32 ? id.substring(0, 32) + '\u2026' : id;
    },

    _schedSummary(hours) {
        if (!hours) return '';
        const days   = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
        const labels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        const active = days.filter(d => hours[d] && hours[d].length > 0);
        if (!active.length) return 'Always open';
        const sample = hours[active[0]][0] || '';
        return active.map(d => labels[days.indexOf(d)]).join(', ') + (sample ? ' \u00b7 ' + sample : '');
    },

    _trunc(s, n) {
        if (!s) return '';
        return s.length > n ? s.substring(0, n) + '\u2026' : s;
    },

    _wrap(txt, max) {
        if (!txt) return [''];
        if (txt.length <= max) return [txt];
        var words = txt.split(' '), lines = [], cur = '';
        for (var i = 0; i < words.length; i++) {
            var w = words[i], test = cur ? cur + ' ' + w : w;
            if (test.length > max && cur) { lines.push(cur); cur = w; } else { cur = test; }
        }
        if (cur) lines.push(cur);
        if (lines.length > 2) { lines = lines.slice(0, 2); lines[1] = lines[1].replace(/\s+\S+$/, '\u2026'); }
        return lines;
    },
};
