const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' }
});

// Convoy store: convoyCode -> { riders: Map, waypoints: [], activeSos: null, activeSpeaker: null }
const convoys = new Map();

function getOrCreateConvoy(code) {
  if (!convoys.has(code)) {
    convoys.set(code, {
      code,
      riders: new Map(),
      waypoints: [],
      activeSos: null,
      activeSpeaker: null
    });
  }
  return convoys.get(code);
}

io.on('connection', (socket) => {
  let currentConvoyCode = null;
  let currentRiderId = null;

  console.log(`[Socket] Connected: ${socket.id}`);

  // Rider joins a convoy
  socket.on('join-convoy', ({ convoyCode, rider }) => {
    currentConvoyCode = convoyCode;
    currentRiderId = rider.id;
    socket.join(convoyCode);

    const convoy = getOrCreateConvoy(convoyCode);
    convoy.riders.set(rider.id, { ...rider, socketId: socket.id, lastSeen: new Date().toISOString() });

    console.log(`[Convoy ${convoyCode}] Rider joined: ${rider.name} (${rider.callsign}) [${rider.role}]`);

    // Broadcast updated convoy roster to all squad members
    io.to(convoyCode).emit('convoy-riders-update', Array.from(convoy.riders.values()));
  });

  // Telemetry Location update
  socket.on('location-update', (data) => {
    const { convoyCode, riderId, lat, lng, speed, heading, battery } = data;
    const convoy = convoys.get(convoyCode);
    if (!convoy) return;

    const rider = convoy.riders.get(riderId);
    if (rider) {
      rider.lat = lat;
      rider.lng = lng;
      rider.speed = speed;
      rider.heading = heading;
      rider.battery = battery;
      rider.lastSeen = new Date().toISOString();

      // Emit incremental or batch update
      socket.to(convoyCode).emit('convoy-riders-update', Array.from(convoy.riders.values()));
    }
  });

  // Push-to-Talk (PTT) Start
  socket.on('ptt-start', ({ convoyCode, rider }) => {
    const convoy = convoys.get(convoyCode);
    if (!convoy) return;
    convoy.activeSpeaker = rider;
    io.to(convoyCode).emit('ptt-status', { transmittingRider: rider });
  });

  // Push-to-Talk (PTT) Audio packet
  socket.on('ptt-audio-chunk', ({ convoyCode, chunk }) => {
    socket.to(convoyCode).emit('ptt-audio', { chunk });
  });

  // Push-to-Talk (PTT) Stop
  socket.on('ptt-stop', ({ convoyCode, riderId }) => {
    const convoy = convoys.get(convoyCode);
    if (!convoy) return;
    if (convoy.activeSpeaker && convoy.activeSpeaker.id === riderId) {
      convoy.activeSpeaker = null;
      io.to(convoyCode).emit('ptt-status', { transmittingRider: null });
    }
  });

  // Emergency SOS Trigger
  socket.on('sos-trigger', ({ convoyCode, alert }) => {
    const convoy = convoys.get(convoyCode);
    if (!convoy) return;
    convoy.activeSos = alert;
    const rider = convoy.riders.get(alert.riderId);
    if (rider) {
      rider.isSosActive = true;
      rider.sosReason = alert.reason;
    }
    console.log(`🚨 [SOS ALERT] Convoy ${convoyCode} by ${alert.riderName}: ${alert.reason}`);
    io.to(convoyCode).emit('sos-broadcast', alert);
    io.to(convoyCode).emit('convoy-riders-update', Array.from(convoy.riders.values()));
  });

  // Waypoint Drop
  socket.on('add-waypoint', ({ convoyCode, waypoint }) => {
    const convoy = convoys.get(convoyCode);
    if (!convoy) return;
    convoy.waypoints.push(waypoint);
    io.to(convoyCode).emit('waypoint-broadcast', waypoint);
  });

  // Convoy Message or Quick Instruction
  socket.on('send-convoy-message', ({ convoyCode, message }) => {
    console.log(`💬 [Message] [${convoyCode}] ${message.senderName}: ${message.text}`);
    io.to(convoyCode).emit('convoy-message-broadcast', message);
  });

  // Disconnect
  socket.on('disconnect', () => {
    if (currentConvoyCode && currentRiderId) {
      const convoy = convoys.get(currentConvoyCode);
      if (convoy) {
        // Mark as disconnected or remove after grace period
        const rider = convoy.riders.get(currentRiderId);
        if (rider) {
          rider.isOffline = true;
        }
        io.to(currentConvoyCode).emit('convoy-riders-update', Array.from(convoy.riders.values()));
      }
    }
    console.log(`[Socket] Disconnected: ${socket.id}`);
  });
});

// Built-in Mock Simulation for quick testing
let simTimer = null;
let simStep = 0;
const SIM_CONVOY = 'RIDERS101';

// Base coordinates: Mountain highway route
const baseCoords = [
  { lat: 32.2396, lng: 77.1887 }, // Manali start
  { lat: 32.2450, lng: 77.1920 },
  { lat: 32.2510, lng: 77.1970 },
  { lat: 32.2580, lng: 77.2030 },
  { lat: 32.2660, lng: 77.2100 },
  { lat: 32.2750, lng: 77.2180 },
  { lat: 32.2850, lng: 77.2270 },
  { lat: 32.2960, lng: 77.2370 },
  { lat: 32.3080, lng: 77.2480 },
  { lat: 32.3200, lng: 77.2600 },
];

function initSimulator() {
  const convoy = getOrCreateConvoy(SIM_CONVOY);

  const mockRiders = [
    { id: 'sim-lead', name: 'Vikram Singh', callsign: 'Apex-1', role: 'leader', battery: 88, speed: 65, lat: baseCoords[0].lat, lng: baseCoords[0].lng },
    { id: 'sim-pack1', name: 'Rohan Sharma', callsign: 'Blaze', role: 'pack', battery: 74, speed: 62, lat: baseCoords[0].lat - 0.001, lng: baseCoords[0].lng - 0.001 },
    { id: 'sim-sweep', name: 'Kabir Khan', callsign: 'Tail-Shield', role: 'sweeper', battery: 92, speed: 58, lat: baseCoords[0].lat - 0.003, lng: baseCoords[0].lng - 0.002 },
    { id: 'sim-lost', name: 'Dev Patel', callsign: 'Phantom', role: 'pack', battery: 18, speed: 20, lat: baseCoords[0].lat - 0.015, lng: baseCoords[0].lng - 0.012 }, // Deliberately separated to test gap alert
  ];

  for (const r of mockRiders) {
    convoy.riders.set(r.id, { ...r, heading: 45, lastSeen: new Date().toISOString() });
  }

  // Pre-seed a fuel waypoint
  convoy.waypoints.push({
    id: 'wp-1',
    name: 'Indian Oil Petrol Station',
    type: 'fuel',
    lat: baseCoords[5].lat,
    lng: baseCoords[5].lng
  });

  if (simTimer) clearInterval(simTimer);

  simTimer = setInterval(() => {
    simStep = (simStep + 1) % baseCoords.length;
    const nextIdx = (simStep + 1) % baseCoords.length;

    const lead = convoy.riders.get('sim-lead');
    if (lead) {
      lead.lat = baseCoords[simStep].lat;
      lead.lng = baseCoords[simStep].lng;
      lead.lastSeen = new Date().toISOString();
    }

    const pack = convoy.riders.get('sim-pack1');
    if (pack) {
      const prevStep = (simStep - 1 + baseCoords.length) % baseCoords.length;
      pack.lat = baseCoords[prevStep].lat;
      pack.lng = baseCoords[prevStep].lng;
      pack.lastSeen = new Date().toISOString();
    }

    const sweep = convoy.riders.get('sim-sweep');
    if (sweep) {
      const sweepStep = (simStep - 2 + baseCoords.length) % baseCoords.length;
      sweep.lat = baseCoords[sweepStep].lat;
      sweep.lng = baseCoords[sweepStep].lng;
      sweep.lastSeen = new Date().toISOString();
    }

    io.to(SIM_CONVOY).emit('convoy-riders-update', Array.from(convoy.riders.values()));
  }, 3000);
}

initSimulator();

const PORT = process.env.PORT || 4040;
server.listen(PORT, () => {
  console.log(`\n======================================================`);
  console.log(`🏍️  MotoSquad Convoy Server Running on http://localhost:${PORT}`);
  console.log(`📡 WebSocket endpoint ready for Flutter mobile apps`);
  console.log(`💻 Interactive Convoy Simulator available at http://localhost:${PORT}`);
  console.log(`======================================================\n`);
});
