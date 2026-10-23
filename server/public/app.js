// Connect to Socket.io
const socket = io();
const CONVOY_CODE = 'RIDERS101';

// Current simulated user
const myRider = {
  id: 'web-rider-' + Math.floor(Math.random() * 1000),
  name: 'My Bike',
  callsign: 'Rider-Alpha',
  role: 'pack',
  lat: 32.2450,
  lng: 77.1920,
  speed: 60,
  heading: 45,
  battery: 85,
  isTransmitting: false,
  isSosActive: false
};

// Map setup
const map = L.map('map', {
  zoomControl: false,
  attributionControl: false
}).setView([32.2510, 77.1970], 14);

L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 19
}).addTo(map);

// Markers store
const riderMarkers = new Map();
const waypointMarkers = new Map();

// Audio Synthesizer for Radio PTT and SOS tones
const audioCtx = new (window.AudioContext || window.webkitAudioContext)();

function playTone(freq, type, durationMs) {
  try {
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
    gain.gain.setValueAtTime(0.15, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + durationMs / 1000);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + durationMs / 1000);
  } catch (e) {}
}

function playPttChirp() {
  playTone(880, 'sine', 80);
  setTimeout(() => playTone(1200, 'sine', 100), 70);
}

function playRogerBeep() {
  playTone(1000, 'sine', 120);
}

function playSosAlarm() {
  let count = 0;
  const interval = setInterval(() => {
    playTone(1400, 'sawtooth', 150);
    count++;
    if (count > 6) clearInterval(interval);
  }, 220);
}

// Join convoy
socket.emit('join-convoy', {
  convoyCode: CONVOY_CODE,
  rider: myRider
});

// UI Elements
const pttButton = document.getElementById('ptt-button');
const speakerIndicator = document.getElementById('speaker-indicator');
const speakerText = document.getElementById('speaker-text');
const rosterList = document.getElementById('roster-list');
const separationAlert = document.getElementById('separation-alert');
const separationText = document.getElementById('separation-text');
const sosBanner = document.getElementById('sos-banner');
const sosRiderName = document.getElementById('sos-rider-name');
const sosReasonText = document.getElementById('sos-reason-text');
const leadSpeedEl = document.getElementById('lead-speed');
const riderCountEl = document.getElementById('rider-count');
const drawerToggle = document.getElementById('drawer-toggle');

// Distance calculation in meters
function getDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ/2) * Math.sin(Δλ/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// Handle riders telemetry updates
socket.on('convoy-riders-update', (riders) => {
  riderCountEl.innerText = `${riders.length} Active`;

  let leadRider = null;
  let maxLagRider = null;
  let maxLagDist = 0;

  // Find leader
  for (const r of riders) {
    if (r.role === 'leader') {
      leadRider = r;
      leadSpeedEl.innerText = `${Math.round(r.speed)} km/h`;
      break;
    }
  }

  // Check separation
  if (leadRider) {
    for (const r of riders) {
      if (r.id !== leadRider.id && r.lat) {
        const dist = getDistanceMeters(leadRider.lat, leadRider.lng, r.lat, r.lng);
        if (dist > 500 && dist > maxLagDist) {
          maxLagDist = dist;
          maxLagRider = r;
        }
      }
    }
  }

  if (maxLagRider) {
    separationText.innerText = `⚠️ ${maxLagRider.name} (${maxLagRider.callsign}) is lagging ${(maxLagDist / 1000).toFixed(1)}km behind leader!`;
    separationAlert.classList.remove('hidden');
  } else {
    separationAlert.classList.add('hidden');
  }

  // Update map markers
  riders.forEach(rider => {
    let marker = riderMarkers.get(rider.id);
    let pinClass = 'pin-pack';
    let iconName = 'fa-motorcycle';

    if (rider.isSosActive) {
      pinClass = 'pin-distress';
      iconName = 'fa-triangle-exclamation';
    } else if (rider.role === 'leader') {
      pinClass = 'pin-leader';
      iconName = 'fa-star';
    } else if (rider.role === 'sweeper') {
      pinClass = 'pin-sweeper';
      iconName = 'fa-shield';
    }

    const html = `
      <div class="rider-map-marker">
        <div class="rider-marker-pin ${pinClass}">
          <i class="fa-solid ${iconName}"></i>
        </div>
        <div class="rider-marker-label">${rider.callsign} (${Math.round(rider.speed)}km/h)</div>
      </div>
    `;

    const customIcon = L.divIcon({
      className: 'custom-rider-div-icon',
      html: html,
      iconSize: [60, 48],
      iconAnchor: [30, 24]
    });

    if (!marker) {
      marker = L.marker([rider.lat, rider.lng], { icon: customIcon }).addTo(map);
      riderMarkers.set(rider.id, marker);
    } else {
      marker.setLatLng([rider.lat, rider.lng]);
      marker.setIcon(customIcon);
    }
  });

  // Render squad roster
  renderRoster(riders, leadRider);
});

function renderRoster(riders, leadRider) {
  rosterList.innerHTML = '';
  riders.forEach(r => {
    let distText = '0.0 km';
    if (leadRider && r.id !== leadRider.id && r.lat && leadRider.lat) {
      const d = getDistanceMeters(leadRider.lat, leadRider.lng, r.lat, r.lng);
      distText = (d / 1000).toFixed(1) + ' km';
    }

    const item = document.createElement('div');
    item.className = `roster-item ${r.isSosActive ? 'distress' : ''}`;
    item.innerHTML = `
      <div class="roster-left">
        <span class="role-tag tag-${r.role}">${r.role}</span>
        <strong>${r.name}</strong>
        <span style="color:#94a3b8">(${r.callsign})</span>
      </div>
      <div>
        <span style="font-size:11px; color:#aaa; margin-right:8px;"><i class="fa-solid fa-battery-half"></i> ${r.battery}%</span>
        <span class="rider-dist">${distText}</span>
      </div>
    `;
    item.onclick = () => {
      if (r.lat) map.setView([r.lat, r.lng], 16);
    };
    rosterList.appendChild(item);
  });
}

// Push to Talk (PTT) Event Listeners
let isTalking = false;

function startTalking() {
  if (isTalking) return;
  isTalking = true;
  pttButton.classList.add('active');
  speakerIndicator.className = 'speaker-status transmitting';
  speakerText.innerText = 'TRANSMITTING (YOU ARE LIVE)';
  playPttChirp();

  socket.emit('ptt-start', {
    convoyCode: CONVOY_CODE,
    rider: myRider
  });
}

function stopTalking() {
  if (!isTalking) return;
  isTalking = false;
  pttButton.classList.remove('active');
  speakerIndicator.className = 'speaker-status';
  speakerText.innerText = 'Intercom Channel: Open';
  playRogerBeep();

  socket.emit('ptt-stop', {
    convoyCode: CONVOY_CODE,
    riderId: myRider.id
  });
}

pttButton.addEventListener('mousedown', startTalking);
window.addEventListener('mouseup', stopTalking);

pttButton.addEventListener('touchstart', (e) => {
  e.preventDefault();
  startTalking();
});
window.addEventListener('touchend', stopTalking);

// PTT Status from others
socket.on('ptt-status', ({ transmittingRider }) => {
  if (transmittingRider && transmittingRider.id !== myRider.id) {
    speakerIndicator.className = 'speaker-status locked';
    speakerText.innerText = `🎙️ ${transmittingRider.name} (${transmittingRider.callsign}) is speaking...`;
  } else if (!isTalking) {
    speakerIndicator.className = 'speaker-status';
    speakerText.innerText = 'Intercom Channel: Open';
  }
});

// SOS Distress
document.getElementById('btn-trigger-sos').addEventListener('click', () => {
  const reason = prompt('Select Emergency Type:\n1. Crash detected\n2. Mechanical breakdown\n3. Medical emergency\n4. Stranded/Lost', 'Mechanical breakdown');
  if (reason) {
    socket.emit('sos-trigger', {
      convoyCode: CONVOY_CODE,
      alert: {
        id: 'sos-' + Date.now(),
        riderId: myRider.id,
        riderName: myRider.name,
        callsign: myRider.callsign,
        lat: myRider.lat,
        lng: myRider.lng,
        reason: reason
      }
    });
  }
});

socket.on('sos-broadcast', (alert) => {
  playSosAlarm();
  sosRiderName.innerText = `🚨 SOS: ${alert.riderName} (${alert.callsign})`;
  sosReasonText.innerText = alert.reason;
  sosBanner.classList.remove('hidden');

  if (alert.lat) {
    map.setView([alert.lat, alert.lng], 16);
  }
});

document.getElementById('btn-resolve-sos').addEventListener('click', () => {
  sosBanner.classList.add('hidden');
});

// Add Waypoint
document.getElementById('btn-add-wp').addEventListener('click', () => {
  const name = prompt('Enter Waypoint Name (e.g. Fuel Stop, Viewpoint, Lunch):', 'Fuel Pump');
  if (name) {
    const center = map.getCenter();
    const wp = {
      id: 'wp-' + Date.now(),
      name: name,
      lat: center.lat,
      lng: center.lng,
      type: 'fuel'
    };
    socket.emit('add-waypoint', { convoyCode: CONVOY_CODE, waypoint: wp });
    addWaypointMarker(wp);
  }
});

socket.on('waypoint-broadcast', (wp) => {
  addWaypointMarker(wp);
});

function addWaypointMarker(wp) {
  if (waypointMarkers.has(wp.id)) return;
  const marker = L.marker([wp.lat, wp.lng], {
    title: wp.name
  }).addTo(map);
  marker.bindPopup(`<b>${wp.name}</b><br>Squad Waypoint`).openPopup();
  waypointMarkers.set(wp.id, marker);
}

// Recenter Map on Lead
document.getElementById('btn-recenter').addEventListener('click', () => {
  for (const [id, marker] of riderMarkers.entries()) {
    map.setView(marker.getLatLng(), 15);
    break;
  }
});

// Toggle Drawer
drawerToggle.addEventListener('click', () => {
  rosterList.classList.toggle('collapsed');
  document.getElementById('drawer-icon').classList.toggle('fa-chevron-down');
  document.getElementById('drawer-icon').classList.toggle('fa-chevron-up');
});
