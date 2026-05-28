<script>
function activateTab(tabId, scrollTo) {
    // Show only the target tab page
    document.querySelectorAll('.tab-page').forEach(p => p.classList.remove('active'));
    const target = document.getElementById(tabId);
    if (target) target.classList.add('active');

    // Clear ALL active markers in sidebar
    document.querySelectorAll('.sidebar a').forEach(a => a.classList.remove('active'));
    document.querySelectorAll('.sidebar details').forEach(d => d.classList.remove('has-active'));
    document.querySelectorAll('.sidebar .pin-top').forEach(p => p.classList.remove('active'));

    // Mark the directly-clicked link as active
    const targetHash = scrollTo ? scrollTo : tabId;
    const lk = document.querySelector('.sidebar a[href="#' + targetHash + '"]');
    if (lk) {
        lk.classList.add('active');
        // If the active link is inside a <details>, mark that details has-active so the
        // summary line lights up too (so user sees BOTH "I'm on this sub-section" AND
        // "I'm on this stage")
        const det = lk.closest('details');
        if (det) {
            det.classList.add('has-active');
            det.open = true;  // auto-expand so user can see siblings
        }
        // If on the pin-top home link, light it up
        const pin = lk.closest('.pin-top');
        if (pin) pin.classList.add('active');
        // Scroll sidebar to keep the active item visible
        lk.scrollIntoView({block: 'nearest', behavior: 'smooth'});
    }

    if (scrollTo) {
        requestAnimationFrame(() => {
            const el = document.getElementById(scrollTo);
            if (el) el.scrollIntoView({behavior: 'smooth', block: 'start'});
        });
    } else {
        const mainEl = document.querySelector('main.content');
        if (mainEl) mainEl.scrollTo(0, 0);
        window.scrollTo(0, 0);
    }
}

function resolveAndActivate(hash) {
    if (!hash) { activateTab('home'); return; }
    const id = hash.startsWith('#') ? hash.slice(1) : hash;
    if (id === 'home') { activateTab('home'); return; }
    if (id.startsWith('stage-')) { activateTab(id); return; }
    if (id.startsWith('sec-')) {
        const sec = document.getElementById(id);
        const parent = sec ? sec.closest('section.tab-page') : null;
        if (parent) activateTab(parent.id, id);
        else activateTab('home');
        return;
    }
    activateTab('home');
}

document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.sidebar a').forEach(link => {
        link.addEventListener('click', e => {
            const href = link.getAttribute('href');
            if (!href || !href.startsWith('#')) return;
            e.preventDefault();
            const id = href.slice(1);
            if (id.startsWith('stage-') || id === 'home') {
                activateTab(id);
                history.replaceState(null, '', '#' + id);
            } else if (id.startsWith('sec-')) {
                const sec = document.getElementById(id);
                const parent = sec ? sec.closest('section.tab-page') : null;
                if (parent) {
                    activateTab(parent.id, id);
                    history.replaceState(null, '', '#' + id);
                }
            }
        });
    });
    window.addEventListener('hashchange', () => resolveAndActivate(location.hash));
    resolveAndActivate(location.hash);
});
</script>
