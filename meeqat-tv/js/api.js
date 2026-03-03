/* ============================================
   Meeqat TV - API Client with Caching
   ============================================ */

const MeeqatAPI = (() => {
  const CACHE_PREFIX = 'meeqat_cache_';
  const CACHE_DURATION = {
    times: 5 * 60 * 1000,        // 5 minutes for prayer times
    announcements: 2 * 60 * 1000, // 2 minutes for announcements
    config: 30 * 1000,            // 30 seconds for TV config (pairing check)
    masjid: 60 * 60 * 1000        // 1 hour for masjid details
  };

  let backendUrl = '';

  function setBackendUrl(url) {
    backendUrl = url.replace(/\/$/, '');
    localStorage.setItem('meeqat_tv_backend_url', backendUrl);
  }

  function getBackendUrl() {
    if (!backendUrl) {
      backendUrl = localStorage.getItem('meeqat_tv_backend_url') || '';
    }
    return backendUrl;
  }

  // ---- Cache Helpers ----
  function getCached(key) {
    try {
      const raw = localStorage.getItem(CACHE_PREFIX + key);
      if (!raw) return null;
      const { data, expiry } = JSON.parse(raw);
      if (Date.now() > expiry) {
        localStorage.removeItem(CACHE_PREFIX + key);
        return null;
      }
      return data;
    } catch {
      return null;
    }
  }

  function setCache(key, data, duration) {
    try {
      localStorage.setItem(CACHE_PREFIX + key, JSON.stringify({
        data,
        expiry: Date.now() + duration
      }));
    } catch {
      // Storage full - clear old caches
      clearOldCaches();
    }
  }

  function clearOldCaches() {
    const keys = Object.keys(localStorage).filter(k => k.startsWith(CACHE_PREFIX));
    keys.forEach(k => localStorage.removeItem(k));
  }

  // ---- HTTP Helpers ----
  async function fetchJSON(path, options = {}) {
    const url = getBackendUrl() + path;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        }
      });
      clearTimeout(timeout);

      if (!response.ok) {
        const err = await response.json().catch(() => ({ error: response.statusText }));
        throw new Error(err.error || `HTTP ${response.status}`);
      }
      return await response.json();
    } catch (err) {
      clearTimeout(timeout);
      throw err;
    }
  }

  // Network-first with cache fallback strategy
  async function fetchWithCache(path, cacheKey, duration) {
    try {
      const data = await fetchJSON(path);
      setCache(cacheKey, data, duration);
      return { data, fromCache: false };
    } catch (err) {
      const cached = getCached(cacheKey);
      if (cached) {
        return { data: cached, fromCache: true };
      }
      throw err;
    }
  }

  // ---- TV Device Endpoints ----
  async function registerDevice(deviceId, pairCode) {
    return fetchJSON('/api/tv/register', {
      method: 'POST',
      body: JSON.stringify({ device_id: deviceId, pair_code: pairCode })
    });
  }

  async function checkConfig(deviceId) {
    const cacheKey = `config_${deviceId}`;
    return fetchWithCache(`/api/tv/${deviceId}/config`, cacheKey, CACHE_DURATION.config);
  }

  async function unpairDevice(deviceId) {
    return fetchJSON(`/api/tv/${deviceId}/unpair`, { method: 'POST' });
  }

  // ---- Prayer Data Endpoints ----
  async function fetchPrayerTimes(masjidId, date) {
    const dateStr = date || new Date().toISOString().split('T')[0];
    const cacheKey = `times_${masjidId}_${dateStr}`;
    return fetchWithCache(
      `/api/masjids/${masjidId}/times?date=${dateStr}`,
      cacheKey,
      CACHE_DURATION.times
    );
  }

  async function fetchAnnouncements(masjidId) {
    const cacheKey = `announcements_${masjidId}`;
    return fetchWithCache(
      `/api/masjids/${masjidId}/announcements`,
      cacheKey,
      CACHE_DURATION.announcements
    );
  }

  async function fetchJumuah(masjidId) {
    const cacheKey = `jumuah_${masjidId}`;
    return fetchWithCache(
      `/api/masjids/${masjidId}/jumuah`,
      cacheKey,
      CACHE_DURATION.masjid
    );
  }

  async function fetchMasjidDetails(masjidId) {
    const cacheKey = `masjid_${masjidId}`;
    return fetchWithCache(
      `/api/masjids/${masjidId}`,
      cacheKey,
      CACHE_DURATION.masjid
    );
  }

  return {
    setBackendUrl,
    getBackendUrl,
    registerDevice,
    checkConfig,
    unpairDevice,
    fetchPrayerTimes,
    fetchAnnouncements,
    fetchJumuah,
    fetchMasjidDetails,
    clearOldCaches
  };
})();
