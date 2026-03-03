/* ============================================
   Meeqat TV - Main Application Controller
   ============================================ */

const MeeqatTV = (() => {
  // ---- State ----
  let deviceId = '';
  let pairCode = '';
  let masjidId = null;
  let masjidData = null;
  let prayerData = null;
  let announcementsData = [];
  let jumuahData = null;
  let currentPrayer = null;
  let isOnline = navigator.onLine;
  let pairingPollInterval = null;
  let clockInterval = null;
  let dataRefreshInterval = null;
  let tickerAnimFrame = null;

  const PRAYERS = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  const PRAYER_ARABIC = {
    fajr: '\u0627\u0644\u0641\u062C\u0631',
    dhuhr: '\u0627\u0644\u0638\u0647\u0631',
    asr: '\u0627\u0644\u0639\u0635\u0631',
    maghrib: '\u0627\u0644\u0645\u063A\u0631\u0628',
    isha: '\u0627\u0644\u0639\u0634\u0627\u0621'
  };

  // ---- Initialization ----
  function init() {
    // Register service worker
    registerServiceWorker();

    // Setup online/offline handlers
    window.addEventListener('online', () => { isOnline = true; updateConnectionStatus(); });
    window.addEventListener('offline', () => { isOnline = false; updateConnectionStatus(); });

    // Request fullscreen
    requestFullscreen();

    // Check for existing device config
    deviceId = localStorage.getItem('meeqat_tv_device_id') || generateDeviceId();
    localStorage.setItem('meeqat_tv_device_id', deviceId);

    masjidId = localStorage.getItem('meeqat_tv_masjid_id');
    const savedBackend = localStorage.getItem('meeqat_tv_backend_url');

    if (savedBackend) {
      MeeqatAPI.setBackendUrl(savedBackend);
    }

    if (masjidId && savedBackend) {
      // Already paired - go to main display
      showMainDisplay();
    } else {
      // Need to configure backend URL first, then show pairing
      promptBackendUrl();
    }

    // Start clock
    startClock();

    // Keep screen awake
    keepScreenAwake();
  }

  // ---- Service Worker Registration ----
  function registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      // Clear all old caches first to ensure fresh files
      caches.keys().then(keys => {
        keys.forEach(key => {
          if (key.includes('v1')) {
            caches.delete(key);
          }
        });
      });

      navigator.serviceWorker.register('sw.js').then(reg => {
        // Force update check
        reg.update();
        console.log('Service Worker registered:', reg.scope);
      }).catch(err => {
        console.warn('Service Worker registration failed:', err);
      });
    }
  }

  // ---- Fullscreen ----
  function requestFullscreen() {
    const el = document.documentElement;
    const requestFs = el.requestFullscreen || el.webkitRequestFullscreen || el.mozRequestFullScreen || el.msRequestFullscreen;
    if (requestFs) {
      // Fullscreen requires a user gesture - listen for first click/tap
      document.addEventListener('click', () => {
        try { requestFs.call(el).catch(() => {}); } catch (e) {}
      }, { once: true });
    }
  }

  // ---- Keep Screen Awake ----
  function keepScreenAwake() {
    if ('wakeLock' in navigator) {
      navigator.wakeLock.request('screen').catch(() => {});
    }
    // Fallback: play silent video to prevent sleep
    try {
      const video = document.createElement('video');
      video.setAttribute('playsinline', '');
      video.setAttribute('muted', '');
      video.setAttribute('loop', '');
      video.style.position = 'fixed';
      video.style.opacity = '0';
      video.style.width = '1px';
      video.style.height = '1px';
      video.src = 'data:video/mp4;base64,AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAu1tZGF0AAACrQYF//+p3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE1MiByMjg1NCBlOWE1OTAzIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAxNyAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTMgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTEgc2NlbmVjdXQ9NDAgaW50cmFfcmVmcmVzaD0wIHJjX2xvb2thaGVhZD00MCByYz1jcmYgbWJ0cmVlPTEgY3JmPTIzLjAgcWNvbXA9MC42MCBxcG1pbj0wIHFwbWF4PTY5IHFwc3RlcD00IGlwX3JhdGlvPTEuNDAgYXE9MToxLjAwAIAAAAAwZYiEAD//8m+P5OXfBeLGOfKE3wvXjMf+MMyDwAAAwAAAAwAAACkhEiAABMAAmKAAAAvRtb292AAAAbG12aGQAAAAAAAAAAAAAAAAAAAPoAAAABAABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAGGlvZHMAAAAAEICAgAcAT////v7/AAACQ3RyYWsAAABcdGtoZAAAAAMAAAAAAAAAAAAAAAEAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAgAAAAIAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAAAAgAAAAAAAEAAAAAAbttZGlhAAAAIG1kaGQAAAAAAAAAAAAAAAAAADIAAAABAFXEAAAAAAAtaGRscgAAAAAAAAAAdmlkZQAAAAAAAAAAAAAAAFZpZGVvSGFuZGxlcgAAAAFsbWluZgAAABR2bWhkAAAAAQAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAABLHN0YmwAAACYc3RzZAAAAAAAAAABAAAAiGF2YzEAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAACAAIAAABIAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGP//AAAAM2F2Y0MBZAAB/+EAGGdkAAGz/p4J+Wf3AAAAAMAaAAAADABA0JA4YMAAGcAAABVFBoBhgGBAgCAAAAARc3R0cwAAAAAAAAAAAAAACHN0c3oAAAAAAAAAAAAAAAEAAAAVc3RjbwAAAAAAAAABAAAALAAAABpzZ3BkAQAAAHJvbGwAAAACAAAAAAAAABRzYnBkAAAAAAAAACAAAAA=';
      video.play().catch(() => {});
      document.body.appendChild(video);
    } catch (e) {}
  }

  // ---- Device ID Generation ----
  function generateDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let id = 'tv_';
    for (let i = 0; i < 12; i++) {
      id += chars[Math.floor(Math.random() * chars.length)];
    }
    return id;
  }

  function generatePairCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  // ---- Backend URL Setup ----
  function promptBackendUrl() {
    // Check URL parameters first (e.g. ?server=https://api.example.com)
    const params = new URLSearchParams(window.location.search);
    const urlParam = params.get('server') || params.get('backend');

    if (urlParam) {
      MeeqatAPI.setBackendUrl(urlParam);
      showPairingScreen();
      return;
    }

    // Check saved backend URL
    const saved = MeeqatAPI.getBackendUrl();
    if (saved) {
      showPairingScreen();
      return;
    }

    // On localhost, default to port 3000
    if (window.location.origin.includes('localhost') || window.location.origin.includes('127.0.0.1')) {
      MeeqatAPI.setBackendUrl('http://localhost:3000');
      showPairingScreen();
      return;
    }

    // On production, default to the Meeqat server
    MeeqatAPI.setBackendUrl('https://clemsonmasjid.vercel.app');
    showPairingScreen();
  }

  // ---- Pairing Screen ----
  function showPairingScreen() {
    document.getElementById('pairing-screen').classList.add('active');
    document.getElementById('main-screen').classList.remove('active');

    pairCode = generatePairCode();
    document.getElementById('pair-code-value').textContent = pairCode;

    // Generate QR code
    generateQRCode();

    // Register device with backend
    registerAndPoll();
  }

  function generateQRCode() {
    var target = document.getElementById('qr-target');
    if (!target) return;

    var pairUrl = MeeqatAPI.getBackendUrl() + '/api/tv/pair?code=' + pairCode;

    // Clear previous content
    target.innerHTML = '';

    try {
      // Generate QR code locally on canvas
      var canvas = document.createElement('canvas');
      QRGen.render(pairUrl, canvas, { size: 560, margin: 4 });

      // Verify canvas has content (not all white)
      var ctx = canvas.getContext('2d');
      var pixel = ctx.getImageData(20, 20, 1, 1).data;
      console.log('QR canvas size:', canvas.width, 'x', canvas.height, 'sample pixel:', pixel[0], pixel[1], pixel[2]);

      // Convert to data URL and display as img (most compatible across browsers)
      var dataUrl = canvas.toDataURL('image/png');
      var img = document.createElement('img');
      img.src = dataUrl;
      img.alt = 'Scan to pair';
      img.style.display = 'block';
      img.style.width = '280px';
      img.style.height = '280px';
      target.appendChild(img);
      console.log('QR code generated locally, data URL length:', dataUrl.length);
    } catch (err) {
      console.warn('QR generation failed:', err);
      // Fallback: show pair code as text
      target.innerHTML = '<p style="color:#2c1810;font-size:40px;font-weight:900;letter-spacing:8px;line-height:280px;text-align:center;">' + pairCode + '</p>';
    }
  }

  let registerRetryCount = 0;

  async function registerAndPoll() {
    const statusEl = document.getElementById('pairing-status');
    const backend = MeeqatAPI.getBackendUrl();

    // No backend configured - show pairing code only, no polling
    if (!backend) {
      statusEl.textContent = 'Scan QR code or enter pair code in the Meeqat app';
      return;
    }

    try {
      await MeeqatAPI.registerDevice(deviceId, pairCode);
      statusEl.textContent = 'Waiting for connection...';
      registerRetryCount = 0;
    } catch (err) {
      registerRetryCount++;
      // Exponential backoff: 5s, 10s, 20s, 30s max
      const delay = Math.min(5000 * Math.pow(2, registerRetryCount - 1), 30000);
      statusEl.textContent = 'Could not reach server. Retrying...';
      console.warn('Backend unreachable, retry in', delay / 1000, 's');
      setTimeout(registerAndPoll, delay);
      return;
    }

    // Poll for pairing
    if (pairingPollInterval) clearInterval(pairingPollInterval);
    pairingPollInterval = setInterval(async () => {
      try {
        const { data } = await MeeqatAPI.checkConfig(deviceId);
        if (data.paired && data.masjid) {
          clearInterval(pairingPollInterval);
          pairingPollInterval = null;

          masjidId = data.masjid.id;
          masjidData = data.masjid;
          localStorage.setItem('meeqat_tv_masjid_id', masjidId);

          showMainDisplay();
        }
      } catch (err) {
        // Continue polling
      }
    }, 3000);
  }

  // ---- Main Display ----
  async function showMainDisplay() {
    document.getElementById('pairing-screen').classList.remove('active');
    document.getElementById('main-screen').classList.add('active');

    if (pairingPollInterval) {
      clearInterval(pairingPollInterval);
      pairingPollInterval = null;
    }

    // Load masjid info
    await loadMasjidInfo();

    // Load prayer times
    await loadPrayerTimes();

    // Load announcements
    await loadAnnouncements();

    // Check if Friday
    await checkJumuah();

    // Start data refresh cycle
    startDataRefresh();

    // Update display immediately
    updateDisplay();
  }

  async function loadMasjidInfo() {
    try {
      const { data } = await MeeqatAPI.fetchMasjidDetails(masjidId);
      masjidData = data.masjid;
      updateMasjidDisplay();
    } catch (err) {
      console.warn('Failed to load masjid info:', err);
    }
  }

  async function loadPrayerTimes() {
    try {
      const today = new Date().toISOString().split('T')[0];
      const { data } = await MeeqatAPI.fetchPrayerTimes(masjidId, today);
      prayerData = data;
      updatePrayerDisplay();
    } catch (err) {
      console.warn('Failed to load prayer times:', err);
    }
  }

  async function loadAnnouncements() {
    try {
      const { data } = await MeeqatAPI.fetchAnnouncements(masjidId);
      announcementsData = data.announcements || [];
      updateTickerDisplay();
    } catch (err) {
      console.warn('Failed to load announcements:', err);
    }
  }

  async function checkJumuah() {
    const today = new Date();
    if (today.getDay() === 5) { // Friday
      try {
        const { data } = await MeeqatAPI.fetchJumuah(masjidId);
        jumuahData = data.jumuah;
        if (jumuahData) {
          const dhuhrRow = document.querySelector('[data-prayer="dhuhr"]');
          if (dhuhrRow) dhuhrRow.classList.add('jumuah');
        }
      } catch (err) {
        console.warn('Failed to load Jumuah times:', err);
      }
    }
  }

  // ---- Data Refresh ----
  function startDataRefresh() {
    if (dataRefreshInterval) clearInterval(dataRefreshInterval);

    // Refresh prayer times every 5 minutes
    dataRefreshInterval = setInterval(async () => {
      await loadPrayerTimes();
      await loadAnnouncements();
      updateDisplay();
    }, 5 * 60 * 1000);

    // Also refresh at midnight for new day
    scheduleMidnightRefresh();
  }

  function scheduleMidnightRefresh() {
    const now = new Date();
    const midnight = new Date(now);
    midnight.setHours(24, 0, 5, 0); // 5 seconds past midnight
    const msUntilMidnight = midnight - now;

    setTimeout(async () => {
      await loadPrayerTimes();
      await loadAnnouncements();
      await checkJumuah();
      updateDisplay();
      scheduleMidnightRefresh(); // Schedule next
    }, msUntilMidnight);
  }

  // ---- Clock ----
  function startClock() {
    updateClock();
    if (clockInterval) clearInterval(clockInterval);
    clockInterval = setInterval(() => {
      updateClock();
      updateCurrentPrayer();
      updateCountdown();
    }, 1000);
  }

  function updateClock() {
    const now = new Date();

    // Time
    let hours = now.getHours();
    const minutes = now.getMinutes();
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12 || 12;

    const timeStr = `${hours}:${minutes.toString().padStart(2, '0')}`;
    document.getElementById('current-time').textContent = timeStr;
    document.getElementById('current-ampm').textContent = ampm;

    // Gregorian date
    const days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const dateStr = `${days[now.getDay()]}, ${months[now.getMonth()]} ${now.getDate().toString().padStart(2, '0')}`;
    document.getElementById('current-date').textContent = dateStr;

    // Hijri date
    try {
      const hijriFormatter = new Intl.DateTimeFormat('en-US-u-ca-islamic-umalqura', {
        day: 'numeric',
        month: 'long'
      });
      const parts = hijriFormatter.formatToParts(now);
      const hijriMonth = parts.find(p => p.type === 'month')?.value?.toUpperCase() || '';
      const hijriDay = parts.find(p => p.type === 'day')?.value || '';
      document.getElementById('hijri-date').textContent = `${hijriDay} ${hijriMonth}`;
    } catch {
      document.getElementById('hijri-date').textContent = '';
    }
  }

  // ---- Display Updates ----
  function updateMasjidDisplay() {
    if (!masjidData) return;

    const name = masjidData.name || 'Masjid';
    document.getElementById('masjid-name').textContent = name;
    document.getElementById('ticker-masjid-name').textContent = name.toUpperCase();

    // If masjid has an image, show it
    if (masjidData.image_url) {
      const container = document.getElementById('masjid-logo-container');
      container.innerHTML = `<img src="${masjidData.image_url}" alt="${name}" style="width:100%;height:100%;object-fit:contain;border-radius:50%;">`;
    }
  }

  function updatePrayerDisplay() {
    if (!prayerData || !prayerData.times) return;

    const times = prayerData.times;

    // Update sunrise and sunset
    if (times.sunrise) {
      document.getElementById('sunrise-time').innerHTML = formatTimeDisplay(times.sunrise.athan);
    }
    if (times.sunset) {
      document.getElementById('sunset-time').innerHTML = formatTimeDisplay(times.sunset.athan);
    }

    // Update prayer rows
    PRAYERS.forEach(prayer => {
      const row = document.querySelector(`[data-prayer="${prayer}"]`);
      if (!row || !times[prayer]) return;

      const t = times[prayer];
      const startsEl = row.querySelector('[data-field="starts"]');
      const athanEl = row.querySelector('[data-field="athan"]');
      const iqamahEl = row.querySelector('[data-field="iqamah"]');

      startsEl.innerHTML = formatTimeDisplay(t.athan);
      athanEl.innerHTML = formatTimeDisplay(t.athan);
      iqamahEl.innerHTML = t.iqamah ? formatTimeDisplay(t.iqamah) : '--';
    });

    updateCurrentPrayer();
    updateCountdown();
  }

  function updateCurrentPrayer() {
    if (!prayerData || !prayerData.times) return;

    const now = new Date();
    const times = prayerData.times;
    let current = null;
    let next = null;

    // Determine current and next prayer
    for (let i = PRAYERS.length - 1; i >= 0; i--) {
      const prayer = PRAYERS[i];
      const t = times[prayer];
      if (!t || !t.athan) continue;

      const prayerTime = parseTime(t.athan);
      if (prayerTime && now >= prayerTime) {
        current = prayer;
        next = i < PRAYERS.length - 1 ? PRAYERS[i + 1] : null;
        break;
      }
    }

    // If no current prayer found, we're before Fajr - next is Fajr
    if (!current) {
      next = 'fajr';
    }

    // Update active row highlighting
    document.querySelectorAll('.prayer-row').forEach(row => {
      row.classList.remove('active');
    });

    if (current) {
      const activeRow = document.querySelector(`[data-prayer="${current}"]`);
      if (activeRow) activeRow.classList.add('active');
    }

    // Update current prayer card
    const arabicEl = document.getElementById('current-prayer-arabic');
    const englishEl = document.getElementById('current-prayer-english');
    const detailsEl = document.getElementById('current-prayer-details');
    const card = document.getElementById('current-prayer-card');

    if (current) {
      card.classList.remove('between-prayers');
      arabicEl.textContent = PRAYER_ARABIC[current] || '';
      englishEl.textContent = current.toUpperCase();

      const t = times[current];
      if (t) {
        const starts = formatTime12(t.athan);
        const iqamah = t.iqamah ? formatTime12(t.iqamah) : '--';
        detailsEl.textContent = `STARTS: ${starts} | ATHAN: ${starts} | IQAMAH: ${iqamah}`;
      }
    } else {
      card.classList.add('between-prayers');
      arabicEl.textContent = '--';
      englishEl.textContent = 'BETWEEN PRAYERS';
      detailsEl.textContent = '';
    }

    currentPrayer = current;
  }

  function updateCountdown() {
    if (!prayerData || !prayerData.times) return;

    const now = new Date();
    const times = prayerData.times;
    let nextIqamahTime = null;

    // Find next upcoming iqamah
    for (const prayer of PRAYERS) {
      const t = times[prayer];
      if (!t || !t.iqamah) continue;

      const iqamahDt = parseTime(t.iqamah);
      if (iqamahDt && iqamahDt > now) {
        nextIqamahTime = iqamahDt;
        break;
      }
    }

    const hoursEl = document.getElementById('countdown-hours');
    const minutesEl = document.getElementById('countdown-minutes');

    if (nextIqamahTime) {
      const diff = nextIqamahTime - now;
      const totalMinutes = Math.ceil(diff / 60000);
      const hours = Math.floor(totalMinutes / 60);
      const mins = totalMinutes % 60;

      hoursEl.textContent = hours;
      minutesEl.textContent = mins.toString().padStart(2, '0');
    } else {
      hoursEl.textContent = '0';
      minutesEl.textContent = '00';
    }
  }

  function updateTickerDisplay() {
    const tickerEl = document.getElementById('ticker-content');

    if (!announcementsData || announcementsData.length === 0) {
      tickerEl.innerHTML = '<span class="ticker-placeholder">No announcements</span>';
      tickerEl.style.animation = 'none';
      return;
    }

    // Build ticker content - duplicate for seamless loop
    let content = '';
    const items = announcementsData.map(a => {
      let text = a.title;
      if (a.body) text += ': ' + a.body;
      return text;
    });

    const itemsHtml = items.map(text =>
      `<span class="ticker-item">${escapeHtml(text)}</span>`
    ).join('<span class="ticker-separator"></span>');

    // Duplicate for seamless scrolling
    tickerEl.innerHTML = itemsHtml + '<span class="ticker-separator"></span>' + itemsHtml;

    // Adjust animation speed based on content length
    const totalLength = items.join('').length;
    const speed = Math.max(20, totalLength * 0.3); // seconds
    tickerEl.style.animationDuration = `${speed}s`;
    tickerEl.style.animation = `ticker-scroll ${speed}s linear infinite`;
  }

  function updateDisplay() {
    updatePrayerDisplay();
    updateCurrentPrayer();
    updateCountdown();
    updateConnectionStatus();
  }

  function updateConnectionStatus() {
    let indicator = document.querySelector('.connection-status');
    if (!indicator) {
      indicator = document.createElement('div');
      indicator.className = 'connection-status';
      document.body.appendChild(indicator);
    }
    indicator.className = `connection-status ${isOnline ? 'online' : 'offline'}`;
  }

  // ---- Time Utilities ----
  function parseTime(timeStr) {
    if (!timeStr) return null;
    // Handle "HH:MM" format (24h) or "HH:MM (TZ)" from Aladhan
    const clean = timeStr.replace(/\s*\(.*\)/, '').trim();
    const [h, m] = clean.split(':').map(Number);
    if (isNaN(h) || isNaN(m)) return null;

    const now = new Date();
    const dt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, m, 0);
    return dt;
  }

  function formatTime12(timeStr) {
    if (!timeStr) return '--';
    const clean = timeStr.replace(/\s*\(.*\)/, '').trim();
    const [h, m] = clean.split(':').map(Number);
    if (isNaN(h) || isNaN(m)) return timeStr;

    const ampm = h >= 12 ? 'PM' : 'AM';
    const hour12 = h % 12 || 12;
    return `${hour12}:${m.toString().padStart(2, '0')}${ampm}`;
  }

  function formatTimeDisplay(timeStr) {
    if (!timeStr) return '--';
    const clean = timeStr.replace(/\s*\(.*\)/, '').trim();
    const [h, m] = clean.split(':').map(Number);
    if (isNaN(h) || isNaN(m)) return timeStr;

    const ampm = h >= 12 ? 'PM' : 'AM';
    const hour12 = h % 12 || 12;
    return `${hour12}:${m.toString().padStart(2, '0')}<span class="time-suffix">${ampm}</span>`;
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // ---- Start ----
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  return { init };
})();
