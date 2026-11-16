(() => {
  const form = document.querySelector('[data-scrape-form]');
  const submit = form?.querySelector('[data-submit]');
  const formStatus = form?.querySelector('[data-form-status]');
  const initialButton = submit?.innerHTML;

  form?.addEventListener('submit', () => {
    submit.disabled = true;
    submit.textContent = 'Inspecting…';
    form.setAttribute('aria-busy', 'true');
    formStatus.hidden = false;
    formStatus.textContent = 'Fetching the page and extracting its data. Image detail lookups may take a little longer.';
  });

  window.addEventListener('pageshow', () => {
    if (!form) return;
    submit.disabled = false;
    submit.innerHTML = initialButton;
    form.removeAttribute('aria-busy');
    formStatus.hidden = true;
  });

  document.querySelectorAll('[data-remote-image]').forEach((image) => {
    const showFallback = () => {
      image.hidden = true;
      const fallback = image.nextElementSibling;
      if (fallback?.hasAttribute('data-image-fallback')) fallback.hidden = false;
    };
    image.addEventListener('error', showFallback);
    if (image.complete && image.naturalWidth === 0) showFallback();
  });

  const json = document.querySelector('#json-export');
  if (!json) return;
  const copy = document.querySelector('[data-copy-json]');
  const download = document.querySelector('[data-download-json]');
  const status = document.querySelector('[data-export-status]');
  const announce = (message) => {
    status.hidden = false;
    status.textContent = message;
  };

  if (navigator.clipboard?.writeText) {
    copy.hidden = false;
    copy.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(json.textContent.trim());
        announce('JSON copied to clipboard.');
      } catch {
        announce('Clipboard access is unavailable. You can select the JSON below or download it.');
      }
    });
  }

  download.hidden = false;
  download.addEventListener('click', () => {
    const file = new Blob([json.textContent.trim() + '\n'], { type: 'application/json' });
    const url = URL.createObjectURL(file);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'metainspector.json';
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    announce('JSON download started.');
  });
})();
