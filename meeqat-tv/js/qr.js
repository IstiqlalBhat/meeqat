/* ============================================
   Minimal QR Code Generator
   Self-contained, no external dependencies
   Supports versions 1-10, byte mode, EC level M
   ============================================ */

const QRGen = (() => {
  // Galois Field GF(2^8) with primitive polynomial 0x11d
  const EXP = new Uint8Array(512);
  const LOG = new Uint8Array(256);
  let x = 1;
  for (let i = 0; i < 255; i++) {
    EXP[i] = x;
    LOG[x] = i;
    x = (x << 1) ^ (x >= 128 ? 0x11d : 0);
  }
  for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];

  function gfMul(a, b) {
    return a === 0 || b === 0 ? 0 : EXP[LOG[a] + LOG[b]];
  }

  // Reed-Solomon generator polynomial of degree n
  function genPoly(n) {
    var g = [1];
    for (var i = 0; i < n; i++) {
      var ng = new Array(g.length + 1);
      for (var k = 0; k < ng.length; k++) ng[k] = 0;
      for (var j = 0; j < g.length; j++) {
        ng[j] ^= g[j];
        ng[j + 1] ^= gfMul(g[j], EXP[i]);
      }
      g = ng;
    }
    return g;
  }

  // RS encode: returns array of EC codewords
  function rsEncode(data, ecCount) {
    var gen = genPoly(ecCount);
    var msg = new Array(data.length + ecCount);
    var i, j;
    for (i = 0; i < msg.length; i++) msg[i] = i < data.length ? data[i] : 0;
    for (i = 0; i < data.length; i++) {
      var c = msg[i];
      if (c !== 0) {
        for (j = 0; j < gen.length; j++) msg[i + j] ^= gfMul(gen[j], c);
      }
    }
    return msg.slice(data.length);
  }

  // Version info table: [ecCodewordsPerBlock, [[group1Blocks, group1DataCW], [group2Blocks, group2DataCW]?]]
  // EC Level M only
  var VI = {
    1:  [10, [[1,16]]],
    2:  [16, [[1,28]]],
    3:  [26, [[1,44]]],
    4:  [18, [[2,32]]],
    5:  [24, [[2,43]]],
    6:  [16, [[4,27]]],
    7:  [18, [[4,31]]],
    8:  [22, [[2,38],[2,39]]],
    9:  [22, [[3,36],[2,37]]],
    10: [26, [[4,43],[1,44]]]
  };

  // Alignment pattern center positions per version
  var ALIGN = {
    2:[6,18], 3:[6,22], 4:[6,26], 5:[6,30], 6:[6,34],
    7:[6,22,38], 8:[6,24,42], 9:[6,26,46], 10:[6,28,50]
  };

  // Get total data codewords for a version
  function totalDataCW(v) {
    var info = VI[v], total = 0;
    for (var i = 0; i < info[1].length; i++) total += info[1][i][0] * info[1][i][1];
    return total;
  }

  // Find minimum version that fits the data
  function getVersion(byteLen) {
    for (var v = 1; v <= 10; v++) {
      var countBits = v < 10 ? 8 : 16;
      var needed = 4 + countBits + byteLen * 8;
      if (needed <= totalDataCW(v) * 8) return v;
    }
    return 10; // clamp
  }

  // Convert string to byte array (ASCII safe)
  function strToBytes(s) {
    var bytes = [];
    for (var i = 0; i < s.length; i++) {
      var code = s.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xC0 | (code >> 6), 0x80 | (code & 0x3F));
      } else {
        bytes.push(0xE0 | (code >> 12), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F));
      }
    }
    return bytes;
  }

  // Encode text into data codewords (byte mode, EC level M)
  function encodeData(text, version) {
    var maxBits = totalDataCW(version) * 8;
    var bits = [];

    function push(val, count) {
      for (var i = count - 1; i >= 0; i--) bits.push((val >> i) & 1);
    }

    // Mode indicator: byte mode = 0100
    push(4, 4);

    // Character count
    var countBits = version < 10 ? 8 : 16;
    var bytes = strToBytes(text);
    push(bytes.length, countBits);

    // Data bytes
    for (var i = 0; i < bytes.length; i++) push(bytes[i], 8);

    // Terminator
    var termLen = Math.min(4, maxBits - bits.length);
    push(0, termLen);

    // Pad to byte boundary
    while (bits.length % 8 !== 0) bits.push(0);

    // Pad codewords
    var pads = [0xEC, 0x11], pi = 0;
    while (bits.length < maxBits) {
      push(pads[pi % 2], 8);
      pi++;
    }

    // Convert bits to codewords
    var cw = [];
    for (var i = 0; i < bits.length; i += 8) {
      var b = 0;
      for (var j = 0; j < 8; j++) b = (b << 1) | bits[i + j];
      cw.push(b);
    }
    return cw;
  }

  // Split into blocks, add EC, interleave
  function addEC(dataCW, version) {
    var info = VI[version];
    var ecPB = info[0];
    var groups = info[1];
    var blocks = [];
    var offset = 0;

    for (var g = 0; g < groups.length; g++) {
      var count = groups[g][0], dcw = groups[g][1];
      for (var i = 0; i < count; i++) {
        var bd = dataCW.slice(offset, offset + dcw);
        var ec = rsEncode(bd, ecPB);
        blocks.push({ d: bd, e: ec });
        offset += dcw;
      }
    }

    // Interleave data
    var result = [];
    var maxD = 0;
    for (var i = 0; i < blocks.length; i++) if (blocks[i].d.length > maxD) maxD = blocks[i].d.length;

    for (var i = 0; i < maxD; i++) {
      for (var j = 0; j < blocks.length; j++) {
        if (i < blocks[j].d.length) result.push(blocks[j].d[i]);
      }
    }

    // Interleave EC
    for (var i = 0; i < ecPB; i++) {
      for (var j = 0; j < blocks.length; j++) {
        result.push(blocks[j].e[i]);
      }
    }

    return result;
  }

  // Create empty QR matrix with function patterns
  function createMatrix(version) {
    var size = 17 + 4 * version;
    var matrix = [], reserved = [];
    for (var r = 0; r < size; r++) {
      matrix.push(new Array(size));
      reserved.push(new Array(size));
      for (var c = 0; c < size; c++) { matrix[r][c] = 0; reserved[r][c] = 0; }
    }

    // Place finder pattern
    function finder(row, col) {
      for (var r = -1; r <= 7; r++) {
        for (var c = -1; c <= 7; c++) {
          var rr = row + r, cc = col + c;
          if (rr < 0 || rr >= size || cc < 0 || cc >= size) continue;
          var black = (r >= 0 && r <= 6 && (c === 0 || c === 6)) ||
                      (c >= 0 && c <= 6 && (r === 0 || r === 6)) ||
                      (r >= 2 && r <= 4 && c >= 2 && c <= 4);
          matrix[rr][cc] = black ? 1 : -1;
          reserved[rr][cc] = 1;
        }
      }
    }

    finder(0, 0);
    finder(0, size - 7);
    finder(size - 7, 0);

    // Timing patterns
    for (var i = 8; i < size - 8; i++) {
      var v = (i % 2 === 0) ? 1 : -1;
      if (!reserved[6][i]) { matrix[6][i] = v; reserved[6][i] = 1; }
      if (!reserved[i][6]) { matrix[i][6] = v; reserved[i][6] = 1; }
    }

    // Alignment patterns
    var ap = ALIGN[version];
    if (ap) {
      for (var ai = 0; ai < ap.length; ai++) {
        for (var aj = 0; aj < ap.length; aj++) {
          var ar = ap[ai], ac = ap[aj];
          if (reserved[ar][ac]) continue;
          for (var dr = -2; dr <= 2; dr++) {
            for (var dc = -2; dc <= 2; dc++) {
              var black = Math.abs(dr) === 2 || Math.abs(dc) === 2 || (dr === 0 && dc === 0);
              matrix[ar + dr][ac + dc] = black ? 1 : -1;
              reserved[ar + dr][ac + dc] = 1;
            }
          }
        }
      }
    }

    // Dark module
    matrix[size - 8][8] = 1;
    reserved[size - 8][8] = 1;

    // Reserve format info areas
    for (var i = 0; i < 8; i++) {
      reserved[8][i] = 1; reserved[8][size - 1 - i] = 1;
      reserved[i][8] = 1; reserved[size - 1 - i][8] = 1;
    }
    reserved[8][8] = 1;

    // Reserve version info areas (V7+)
    if (version >= 7) {
      for (var i = 0; i < 6; i++) {
        for (var j = 0; j < 3; j++) {
          reserved[i][size - 11 + j] = 1;
          reserved[size - 11 + j][i] = 1;
        }
      }
    }

    return { m: matrix, r: reserved, s: size };
  }

  // Place data bits into matrix
  function placeData(matrix, reserved, size, data) {
    var bits = [];
    for (var i = 0; i < data.length; i++) {
      for (var b = 7; b >= 0; b--) bits.push((data[i] >> b) & 1);
    }

    var idx = 0;
    var col = size - 1;
    var up = true;

    while (col >= 0) {
      if (col === 6) { col--; continue; }

      var rows = [];
      if (up) {
        for (var r = size - 1; r >= 0; r--) rows.push(r);
      } else {
        for (var r = 0; r < size; r++) rows.push(r);
      }

      for (var ri = 0; ri < rows.length; ri++) {
        var row = rows[ri];
        for (var dc = 0; dc >= -1; dc--) {
          var c = col + dc;
          if (c < 0 || c >= size || reserved[row][c]) continue;
          matrix[row][c] = (idx < bits.length && bits[idx]) ? 1 : -1;
          idx++;
        }
      }

      col -= 2;
      up = !up;
    }
  }

  // Mask functions
  var MASKS = [
    function(r,c) { return (r+c) % 2 === 0; },
    function(r,c) { return r % 2 === 0; },
    function(r,c) { return c % 3 === 0; },
    function(r,c) { return (r+c) % 3 === 0; },
    function(r,c) { return (Math.floor(r/2) + Math.floor(c/3)) % 2 === 0; },
    function(r,c) { return ((r*c)%2 + (r*c)%3) === 0; },
    function(r,c) { return ((r*c)%2 + (r*c)%3) % 2 === 0; },
    function(r,c) { return ((r+c)%2 + (r*c)%3) % 2 === 0; }
  ];

  function applyMask(matrix, reserved, size, maskNum) {
    var fn = MASKS[maskNum];
    var out = [];
    for (var r = 0; r < size; r++) {
      out.push(matrix[r].slice());
      for (var c = 0; c < size; c++) {
        if (!reserved[r][c] && fn(r, c)) {
          out[r][c] = out[r][c] === 1 ? -1 : 1;
        }
      }
    }
    return out;
  }

  // Penalty scoring (simplified but effective)
  function penalty(matrix, size) {
    var score = 0, r, c, count, v;

    // Rule 1: consecutive same-color in rows and columns
    for (r = 0; r < size; r++) {
      count = 1;
      for (c = 1; c < size; c++) {
        if (matrix[r][c] === matrix[r][c-1]) count++;
        else { if (count >= 5) score += count - 2; count = 1; }
      }
      if (count >= 5) score += count - 2;
    }
    for (c = 0; c < size; c++) {
      count = 1;
      for (r = 1; r < size; r++) {
        if (matrix[r][c] === matrix[r-1][c]) count++;
        else { if (count >= 5) score += count - 2; count = 1; }
      }
      if (count >= 5) score += count - 2;
    }

    // Rule 2: 2x2 blocks
    for (r = 0; r < size - 1; r++) {
      for (c = 0; c < size - 1; c++) {
        v = matrix[r][c];
        if (v === matrix[r][c+1] && v === matrix[r+1][c] && v === matrix[r+1][c+1]) score += 3;
      }
    }

    // Rule 4: dark/light proportion
    var dark = 0;
    for (r = 0; r < size; r++) for (c = 0; c < size; c++) if (matrix[r][c] === 1) dark++;
    var pct = (dark * 100) / (size * size);
    var p5 = Math.floor(pct / 5) * 5;
    score += Math.min(Math.abs(p5 - 50), Math.abs(p5 + 5 - 50)) * 2;

    return score;
  }

  // BCH encoding for format info
  function formatBits(ecLevel, mask) {
    var data = (ecLevel << 3) | mask;
    var bits = data << 10;
    for (var i = 14; i >= 10; i--) {
      if (bits & (1 << i)) bits ^= 0x537 << (i - 10); // generator: x^10+x^8+x^5+x^4+x^2+x+1
    }
    return ((data << 10) | bits) ^ 0x5412; // XOR mask
  }

  // Place format info
  function placeFormat(matrix, size, mask) {
    var bits = formatBits(0, mask); // EC level M = 0

    // Positions around top-left finder
    var p1 = [[8,0],[8,1],[8,2],[8,3],[8,4],[8,5],[8,7],[8,8],
              [7,8],[5,8],[4,8],[3,8],[2,8],[1,8],[0,8]];
    // Bottom-left and top-right
    var p2 = [[size-1,8],[size-2,8],[size-3,8],[size-4,8],[size-5,8],[size-6,8],[size-7,8],
              [8,size-8],[8,size-7],[8,size-6],[8,size-5],[8,size-4],[8,size-3],[8,size-2],[8,size-1]];

    for (var i = 0; i < 15; i++) {
      var v = ((bits >> i) & 1) ? 1 : -1;
      matrix[p1[i][0]][p1[i][1]] = v;
      matrix[p2[i][0]][p2[i][1]] = v;
    }
  }

  // BCH encoding for version info (V7+)
  function versionBits(version) {
    var bits = version << 12;
    for (var i = 17; i >= 12; i--) {
      if (bits & (1 << i)) bits ^= 0x1F25 << (i - 12); // generator polynomial
    }
    return (version << 12) | bits;
  }

  // Place version info (V7+)
  function placeVersion(matrix, size, version) {
    if (version < 7) return;
    var bits = versionBits(version);
    for (var i = 0; i < 18; i++) {
      var v = ((bits >> i) & 1) ? 1 : -1;
      var r = i % 3, c = Math.floor(i / 3);
      matrix[c][size - 11 + r] = v;
      matrix[size - 11 + r][c] = v;
    }
  }

  // Main: generate QR and draw to canvas
  function render(text, canvas, opts) {
    opts = opts || {};
    var bytes = strToBytes(text);
    var version = opts.version || getVersion(bytes.length);
    var size = 17 + 4 * version;
    var targetSize = opts.size || 280;
    var margin = opts.margin !== undefined ? opts.margin : 4;
    var scale = Math.floor(targetSize / (size + margin * 2));
    if (scale < 1) scale = 1;

    // Encode
    var dataCW = encodeData(text, version);
    var finalCW = addEC(dataCW, version);

    // Build matrix
    var info = createMatrix(version);
    placeData(info.m, info.r, info.s, finalCW);

    // Try all 8 masks, pick lowest penalty
    var bestMask = 0, bestScore = Infinity, bestMatrix = null;
    for (var m = 0; m < 8; m++) {
      var masked = applyMask(info.m, info.r, info.s, m);
      placeFormat(masked, info.s, m);
      placeVersion(masked, info.s, version);
      var s = penalty(masked, info.s);
      if (s < bestScore) { bestScore = s; bestMask = m; bestMatrix = masked; }
    }

    // Final format + version info
    placeFormat(bestMatrix, size, bestMask);
    placeVersion(bestMatrix, size, version);

    // Draw
    var total = (size + margin * 2) * scale;
    canvas.width = total;
    canvas.height = total;
    var ctx = canvas.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, total, total);
    ctx.fillStyle = '#000000';

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (bestMatrix[r][c] === 1) {
          ctx.fillRect((c + margin) * scale, (r + margin) * scale, scale, scale);
        }
      }
    }
  }

  return { render: render, getVersion: getVersion };
})();
