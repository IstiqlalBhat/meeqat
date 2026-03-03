/**
 * Iqamah rule helpers — shared between API and admin routes.
 */

/**
 * Add minutes to an "HH:MM" time string.
 * Strips Aladhan timezone suffixes like " (EST)" before parsing.
 * Returns "HH:MM" or null on invalid input.
 */
function addMinutesToTime(timeStr, minutes) {
  if (!timeStr || minutes == null) return null;
  // Strip timezone suffix e.g. "05:30 (EST)" -> "05:30"
  const clean = String(timeStr).replace(/\s*\(.*\)/, '').trim();
  const parts = clean.split(':');
  if (parts.length < 2) return null;

  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  if (isNaN(h) || isNaN(m)) return null;

  const total = h * 60 + m + parseInt(minutes, 10);
  const newH = Math.floor(((total % 1440) + 1440) % 1440 / 60);
  const newM = ((total % 1440) + 1440) % 1440 % 60;
  return String(newH).padStart(2, '0') + ':' + String(newM).padStart(2, '0');
}

/**
 * Calculate iqamah time from a rule + the day's API times.
 *
 * @param {Object} rule  - { rule_type, value, reference_prayer }
 * @param {Object} apiTimes - { fajr, sunrise, dhuhr, asr, sunset, maghrib, isha }
 * @param {string} prayer - the prayer this rule is for (used for after_adhan)
 * @returns {string|null} "HH:MM" or null
 */
function calculateIqamahFromRule(rule, apiTimes, prayer) {
  if (!rule) return null;

  switch (rule.rule_type) {
    case 'fixed':
      return rule.value || null;

    case 'after_adhan': {
      const adhan = apiTimes && apiTimes[prayer];
      if (!adhan) return null;
      return addMinutesToTime(adhan, parseInt(rule.value, 10));
    }

    case 'after_reference': {
      const ref = rule.reference_prayer;
      const refTime = apiTimes && ref ? apiTimes[ref] : null;
      if (!refTime) return null;
      return addMinutesToTime(refTime, parseInt(rule.value, 10));
    }

    default:
      return null;
  }
}

module.exports = { addMinutesToTime, calculateIqamahFromRule };
