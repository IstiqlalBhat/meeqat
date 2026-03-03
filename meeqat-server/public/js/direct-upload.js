/**
 * Direct browser-to-Firebase-Storage uploads via signed URLs.
 * Bypasses Vercel's 4.5MB payload limit entirely — files go
 * straight to Google Cloud Storage at full quality.
 *
 * Flow:
 *  1. POST /admin/get-upload-url  → { uploadUrl, filePath }
 *  2. PUT  uploadUrl (direct to GCS, bypasses Vercel)
 *  3. POST /admin/finalize-upload → { url }  (makes file public)
 */

/**
 * Upload a file directly to Firebase Storage.
 * @param {File} file
 * @param {string} category - 'profile' or 'announcements'
 * @returns {Promise<string>} The public/signed URL of the uploaded file
 */
async function uploadDirect(file, category) {
  // 1. Get a signed upload URL from our server (tiny JSON request)
  var res = await fetch('/admin/get-upload-url', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: file.name,
      contentType: file.type || 'application/octet-stream',
      category: category
    })
  });

  if (!res.ok) {
    var err = await res.json().catch(function() { return { error: 'Server error' }; });
    throw new Error(err.error || 'Failed to get upload URL');
  }

  var data = await res.json();
  var uploadUrl = data.uploadUrl;
  var filePath = data.filePath;

  // 2. Upload file directly to Google Cloud Storage (bypasses Vercel)
  var uploadRes = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': file.type || 'application/octet-stream' },
    body: file
  });

  if (!uploadRes.ok) {
    throw new Error('Upload to storage failed (' + uploadRes.status + ')');
  }

  // 3. Finalize: make the file publicly accessible
  var finalRes = await fetch('/admin/finalize-upload', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ filePath: filePath })
  });

  if (!finalRes.ok) {
    throw new Error('Failed to finalize upload');
  }

  var finalData = await finalRes.json();
  return finalData.url;
}

/**
 * Attach direct upload to a form with file input.
 * Intercepts submit: uploads file to storage first, then submits
 * the form with just the URL (tiny payload, no file).
 *
 * @param {HTMLFormElement} formEl
 * @param {string} fileInputName - name attr of the file input (default: 'image')
 * @param {string} category - 'profile' or 'announcements'
 */
function setupDirectUpload(formEl, fileInputName, category) {
  if (!fileInputName) fileInputName = 'image';
  if (!category) category = 'profile';

  var pendingFile = null;
  var fileInput = formEl.querySelector('input[name="' + fileInputName + '"]');
  if (!fileInput) return;

  // Track file selection
  fileInput.addEventListener('change', function() {
    pendingFile = (fileInput.files && fileInput.files[0]) ? fileInput.files[0] : null;
  });

  formEl.addEventListener('submit', async function(e) {
    // No file selected — let form submit normally
    if (!pendingFile) return;

    e.preventDefault();

    var submitBtn = formEl.querySelector('button[type="submit"]');
    var originalText = submitBtn ? submitBtn.textContent : '';
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.textContent = 'Uploading...';
    }

    try {
      // Upload file directly to storage + finalize
      var imageUrl = await uploadDirect(pendingFile, category);

      // Build FormData WITHOUT the file — just text fields + the URL
      var formData = new FormData(formEl);
      formData.delete(fileInputName);  // remove the file
      formData.set('image_url', imageUrl);  // add the URL instead

      var res = await fetch(formEl.action, {
        method: 'POST',
        body: formData,
        redirect: 'follow'
      });

      if (res.redirected) {
        window.location.href = res.url;
      } else if (res.ok) {
        window.location.reload();
      } else {
        var text = await res.text();
        document.open();
        document.write(text);
        document.close();
      }
    } catch (err) {
      alert('Upload failed: ' + err.message);
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
      }
    }
  });
}
