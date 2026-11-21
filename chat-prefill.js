// Nexora AI Chat (owner, 21 Nov): the signed-in user's name, mobile and email go into the chat's form by
// themselves (the account's details, kept by our server), and the form is sent once, so the user goes
// straight to the chat. Runs at the start of every page of the chat's own site (ChatFragment adds it for
// https://apis.wereplyx.com only). If the chat refuses a detail, its message shows and the user can change it.
(function () {
  if (location.hostname !== 'apis.wereplyx.com' || window.__nexoraPrefill) return;
  window.__nexoraPrefill = true;
  var U = __NEXORA_USER__;
  if (!U || !U.name) return;
  var mobile = (U.mobile || '').replace(/\D/g, '');
  if (mobile.length === 10) mobile = '+91 ' + mobile.slice(0, 5) + ' ' + mobile.slice(5);
  var vals = { 'wereply-lead-name': U.name, 'wereply-lead-email': U.email || '', 'wereply-lead-mobile': mobile };
  var startedOnce = false;
  function shown(el) { return !!(el && (el.offsetWidth || el.offsetHeight)); }
  function put(el, v) {
    if (!el || !v || el.value === v) return;
    el.removeAttribute('readonly');
    // The chat empties its fields when the form opens unless they are marked as filled in.
    el.setAttribute('data-touched', '1');
    var d = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
    d.set.call(el, v);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  function tick() {
    var name = document.getElementById('wereply-lead-name');
    if (shown(name)) {
      if (!name.getAttribute('data-nexora')) {
        // A new form (the chat draws it again each time): fill it, then send it once.
        name.setAttribute('data-nexora', 'filling');
        name.setAttribute('data-nexora-at', String(Date.now()));
      }
      Object.keys(vals).forEach(function (id) { if (name.getAttribute('data-nexora') === 'filling') put(document.getElementById(id), vals[id]); });
      var at = +name.getAttribute('data-nexora-at');
      if (name.getAttribute('data-nexora') === 'filling' && Date.now() - at > 700) {
        name.setAttribute('data-nexora', 'sent');
        var mob = document.getElementById('wereply-lead-mobile');
        if (name.value && mob && mob.value) {
          var form = name.form, btn = document.getElementById('wereply-lead-submit');
          if (btn) btn.click(); else if (form && form.requestSubmit) form.requestSubmit();
          console.log('[nexora] form sent');
        }
      }
      return;
    }
    // The chat's start page (no open conversation): start one once, so the chat opens straight away.
    var start = document.getElementById('wereply-btn-new-chat');
    if (!startedOnce && shown(start)) { startedOnce = true; start.click(); }
  }
  setInterval(tick, 250);
})();
