/**
 * Client-side image compression to stay under Vercel's 4.5MB payload limit.
 * Resizes images to max 1200px and compresses to JPEG ~0.8 quality.
 */

function compressImage(file, maxSize = 1200, quality = 0.8) {
  return new Promise((resolve) => {
    if (!file || !file.type.startsWith('image/')) {
      resolve(file);
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        let { width, height } = img;

        // Only resize if larger than maxSize
        if (width > maxSize || height > maxSize) {
          if (width > height) {
            height = Math.round((height * maxSize) / width);
            width = maxSize;
          } else {
            width = Math.round((width * maxSize) / height);
            height = maxSize;
          }
        }

        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;

        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, width, height);

        canvas.toBlob(
          (blob) => {
            // Build a new File with the original name
            const ext = file.name.lastIndexOf('.') >= 0 ? file.name.substring(file.name.lastIndexOf('.')) : '.jpg';
            const name = file.name.substring(0, file.name.lastIndexOf('.')) + ext;
            const compressed = new File([blob], name, { type: 'image/jpeg', lastModified: Date.now() });
            resolve(compressed);
          },
          'image/jpeg',
          quality
        );
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
  });
}

/**
 * Attach to any form with file uploads.
 * Intercepts submit, compresses the image, resubmits via FormData.
 */
function setupImageCompression(formEl, fileInputName = 'image') {
  let compressedFile = null;
  const fileInput = formEl.querySelector(`input[name="${fileInputName}"]`);

  if (!fileInput) return;

  // Compress on file select so user gets instant feedback
  fileInput.addEventListener('change', async () => {
    if (fileInput.files && fileInput.files[0]) {
      const original = fileInput.files[0];
      // Only compress if over 3MB (leave small images alone)
      if (original.size > 3 * 1024 * 1024) {
        compressedFile = await compressImage(original);
      } else {
        compressedFile = original;
      }
    } else {
      compressedFile = null;
    }
  });

  formEl.addEventListener('submit', async (e) => {
    // No file selected — let form submit normally
    if (!compressedFile) return;

    e.preventDefault();

    const submitBtn = formEl.querySelector('button[type="submit"]');
    const originalText = submitBtn ? submitBtn.textContent : '';
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.textContent = 'Uploading...';
    }

    const formData = new FormData(formEl);
    // Replace the file input with our compressed version
    formData.set(fileInputName, compressedFile);

    try {
      const res = await fetch(formEl.action, {
        method: 'POST',
        body: formData,
        redirect: 'follow',
      });

      if (res.redirected) {
        window.location.href = res.url;
      } else if (res.ok) {
        // Reload to show result
        window.location.reload();
      } else {
        const text = await res.text();
        // Try to show server-rendered error page
        document.open();
        document.write(text);
        document.close();
      }
    } catch (err) {
      alert('Upload failed. Please try again.');
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
      }
    }
  });
}
