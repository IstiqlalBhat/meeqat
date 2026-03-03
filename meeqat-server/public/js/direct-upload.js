/**
 * Direct browser-to-Firebase-Storage uploads via REST API.
 * Bypasses Vercel's 4.5MB payload limit entirely — files go
 * straight to Firebase Storage at full quality.
 *
 * Flow:
 *  1. POST /admin/get-upload-url  → { accessToken, filePath, bucket }
 *  2. POST firebasestorage.googleapis.com (direct upload with Bearer token)
 *  3. Response includes downloadTokens → construct public URL
 */

/**
 * Upload a file directly to Firebase Storage.
 * @param {File} file
 * @param {string} category - 'profile' or 'announcements'
 * @returns {Promise<string>} The public download URL of the uploaded file
 */
async function uploadDirect(file, category) {
  // 1. Get upload credentials from our server (tiny JSON request)
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
    throw new Error(err.error || 'Failed to get upload credentials');
  }

  var data = await res.json();
  var accessToken = data.accessToken;
  var filePath = data.filePath;
  var bucketName = data.bucket;
  var contentType = data.contentType;

  // 2. Upload directly to Firebase Storage REST API (bypasses Vercel)
  var encodedPath = encodeURIComponent(filePath);
  var uploadUrl = 'https://firebasestorage.googleapis.com/v0/b/' + bucketName + '/o?uploadType=media&name=' + encodedPath;

  var uploadRes = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      'Content-Type': contentType,
      'Authorization': 'Bearer ' + accessToken
    },
    body: file
  });

  if (!uploadRes.ok) {
    var uploadErr = await uploadRes.text().catch(function() { return 'Unknown error'; });
    throw new Error('Upload to storage failed (' + uploadRes.status + '): ' + uploadErr);
  }

  var uploadData = await uploadRes.json();

  // 3. Construct the public download URL from the response
  var downloadToken = uploadData.downloadTokens;
  if (downloadToken) {
    return 'https://firebasestorage.googleapis.com/v0/b/' + bucketName + '/o/' + encodedPath + '?alt=media&token=' + downloadToken;
  }

  // Fallback: use alt=media URL (works if bucket allows public reads)
  return 'https://firebasestorage.googleapis.com/v0/b/' + bucketName + '/o/' + encodedPath + '?alt=media';
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
      // Upload file directly to storage
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
