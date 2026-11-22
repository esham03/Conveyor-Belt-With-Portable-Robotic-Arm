/**
 * @file app.js
 * @brief Interactive Industrial Automation Simulation & Hardware Demonstration Console
 * @project Conveyor Belt with Portable Robotic Arm
 */

(function() {
  'use strict';

  // --- APPLICATION STATE ---
  const state = {
    isEStopped: false,
    base: {
      speed: 204,
      lastCmd: 'S',
      x: 100,
      y: 380,
      vx: 0,
      vy: 0,
      heading: 0,
      isBraking: false
    },
    arm: {
      waistAngle: 0,
      shoulderAngle: 30,
      elbowAngle: 45,
      gripperClosed: false,
      lastCmd: 'S'
    },
    sortConv: {
      isRunning: true,
      beltSpeed: 2.0,
      irTriggered: false,
      diverterAngle: 0, // 0 neutral, 45 red, 90 green, 135 blue
      activeColor: 'NONE',
      parcels: []
    },
    transferConv: {
      b1Running: false,
      b2Running: false,
      b3Running: false,
      t1: 0,
      t2: 0,
      t3: 0
    },
    cam: {
      isFlashOn: false,
      frameCounter: 0
    },
    packetCount: 5
  };

  // --- DOM ELEMENT REFERENCES ---
  const canvas = document.getElementById('simCanvas');
  const ctx = canvas.getContext('2d');
  const camCanvas = document.getElementById('camCanvas');
  const camCtx = camCanvas ? camCanvas.getContext('2d') : null;

  const btnMasterEStop = document.getElementById('btnMasterEStop');
  const termLog = document.getElementById('termLog');
  const termPacketCount = document.getElementById('termPacketCount');

  const txtBaseState = document.getElementById('txtBaseState');
  const txtArmState = document.getElementById('txtArmState');
  const txtSortState = document.getElementById('txtSortState');
  const txt3ConvState = document.getElementById('txt3ConvState');

  const lblIrStatus = document.getElementById('lblIrStatus');
  const lblColorStatus = document.getElementById('lblColorStatus');
  const lblServoAngle = document.getElementById('lblServoAngle');

  const badgeStage1 = document.getElementById('badgeStage1');
  const badgeStage2 = document.getElementById('badgeStage2');
  const badgeStage3 = document.getElementById('badgeStage3');

  // --- TERMINAL LOGGING HELPER ---
  function logSerial(source, msg, severity = 'info') {
    state.packetCount++;
    if (termPacketCount) termPacketCount.textContent = `Packets: ${state.packetCount}`;

    const d = new Date();
    const timeStr = d.toTimeString().split(' ')[0] + '.' + Math.floor(d.getMilliseconds() / 100);
    const line = document.createElement('div');
    line.className = `log-line ${severity}`;
    line.textContent = `[${timeStr}] <${source}> ${msg}`;
    if (termLog) {
      termLog.insertBefore(line, termLog.firstChild);
      if (termLog.children.length > 150) {
        termLog.removeChild(termLog.lastChild);
      }
    }
  }

  // --- TAB NAVIGATION ---
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      btn.classList.add('active');
      const targetId = btn.getAttribute('data-tab');
      const targetContent = document.getElementById(targetId);
      if (targetContent) targetContent.classList.add('active');
    });
  });

  // --- MASTER EMERGENCY STOP ---
  btnMasterEStop.addEventListener('click', () => {
    if (state.isEStopped) {
      state.isEStopped = false;
      btnMasterEStop.classList.remove('active');
      btnMasterEStop.innerHTML = '<span class="estop-icon">🛑</span> EMERGENCY STOP';
      logSerial('SAFETY', 'Master Emergency Stop Reset. System operational.', 'warning');
    } else {
      state.isEStopped = true;
      btnMasterEStop.classList.add('active');
      btnMasterEStop.innerHTML = '<span class="estop-icon">⚠️</span> RESET E-STOP';

      // Halt base
      state.base.vx = 0;
      state.base.vy = 0;
      state.base.lastCmd = 'S';

      // Halt conveyors
      state.sortConv.isRunning = false;
      state.transferConv.b1Running = false;
      state.transferConv.b2Running = false;
      state.transferConv.b3Running = false;

      logSerial('SAFETY', '!!! MASTER EMERGENCY STOP ENGAGED - ALL DRIVES HALTED !!!', 'error');
      logSerial('BASE', 'TX: S -> ACK: STOP, DYNAMIC_BRAKE_PULSE', 'warning');
      logSerial('ARM', 'TX: S -> ACK: ARM_HALTED', 'warning');
      logSerial('CONV', 'TX: S -> ACK: CONV_HALTED', 'warning');
      updateTelemetryUI();
    }
  });

  // --- ROBOTIC BASE CONTROLLER ---
  document.querySelectorAll('.dpad-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const cmd = btn.getAttribute('data-cmd');
      handleBaseCommand(cmd);
    });
  });

  const rngBaseSpeed = document.getElementById('rngBaseSpeed');
  const lblBaseSpeed = document.getElementById('lblBaseSpeed');
  if (rngBaseSpeed) {
    rngBaseSpeed.addEventListener('input', (e) => {
      state.base.speed = parseInt(e.target.value, 10);
      if (lblBaseSpeed) lblBaseSpeed.textContent = state.base.speed;
      logSerial('BASE', `Speed updated -> PWM ${state.base.speed}`, 'info');
      updateTelemetryUI();
    });
  }

  function handleBaseCommand(cmd) {
    if (state.isEStopped && cmd !== 'S') {
      logSerial('BASE', 'Command rejected: Emergency Stop active.', 'error');
      return;
    }

    state.base.lastCmd = cmd;
    const spd = (state.base.speed / 255) * 3.5;

    switch (cmd) {
      case 'F': state.base.vx = spd; state.base.vy = 0; logSerial('BASE', 'TX: F -> ACK: FORWARD', 'success'); break;
      case 'B': state.base.vx = -spd; state.base.vy = 0; logSerial('BASE', 'TX: B -> ACK: BACKWARD', 'success'); break;
      case 'L': state.base.vx = 0; state.base.vy = -spd; logSerial('BASE', 'TX: L -> ACK: PIVOT_LEFT', 'success'); break;
      case 'R': state.base.vx = 0; state.base.vy = spd; logSerial('BASE', 'TX: R -> ACK: PIVOT_RIGHT', 'success'); break;
      case 'G': state.base.vx = spd * 0.7; state.base.vy = -spd * 0.7; logSerial('BASE', 'TX: G -> ACK: FWD_LEFT', 'success'); break;
      case 'I': state.base.vx = spd * 0.7; state.base.vy = spd * 0.7; logSerial('BASE', 'TX: I -> ACK: FWD_RIGHT', 'success'); break;
      case 'H': state.base.vx = -spd * 0.7; state.base.vy = -spd * 0.7; logSerial('BASE', 'TX: H -> ACK: BACK_LEFT', 'success'); break;
      case 'J': state.base.vx = -spd * 0.7; state.base.vy = spd * 0.7; logSerial('BASE', 'TX: J -> ACK: BACK_RIGHT', 'success'); break;
      case 'S':
        state.base.vx = 0;
        state.base.vy = 0;
        state.base.isBraking = true;
        setTimeout(() => { state.base.isBraking = false; }, 200);
        logSerial('BASE', 'TX: S -> ACK: STOP, ELECTRONIC_BRAKE_ON', 'warning');
        break;
    }
    updateTelemetryUI();
  }

  // --- ROBOTIC ARM CONTROLS ---
  document.querySelectorAll('#tabArm .btn-cmd, #tabArm .btn-block').forEach(btn => {
    btn.addEventListener('click', () => {
      const cmd = btn.getAttribute('data-cmd');
      handleArmCommand(cmd);
    });
  });

  function handleArmCommand(cmd) {
    if (state.isEStopped && cmd !== 'S') {
      logSerial('ARM', 'Command rejected: Emergency Stop active.', 'error');
      return;
    }

    state.arm.lastCmd = cmd;
    switch (cmd) {
      case 'L': state.arm.waistAngle = Math.max(-60, state.arm.waistAngle - 15); logSerial('ARM', 'TX: L -> ACK: WAIST_LEFT', 'success'); break;
      case 'R': state.arm.waistAngle = Math.min(60, state.arm.waistAngle + 15); logSerial('ARM', 'TX: R -> ACK: WAIST_RIGHT', 'success'); break;
      case 'U': state.arm.shoulderAngle = Math.min(75, state.arm.shoulderAngle + 10); logSerial('ARM', 'TX: U -> ACK: SHOULDER_UP', 'success'); break;
      case 'D': state.arm.shoulderAngle = Math.max(10, state.arm.shoulderAngle - 10); logSerial('ARM', 'TX: D -> ACK: SHOULDER_DOWN', 'success'); break;
      case 'T': state.arm.elbowAngle = Math.min(90, state.arm.elbowAngle + 10); logSerial('ARM', 'TX: T -> ACK: ELBOW_TOP_UP', 'success'); break;
      case 't': state.arm.elbowAngle = Math.max(15, state.arm.elbowAngle - 10); logSerial('ARM', 'TX: t -> ACK: ELBOW_TOP_DOWN', 'success'); break;
      case 'O': state.arm.gripperClosed = false; logSerial('ARM', 'TX: O -> ACK: GRIPPER_OPEN', 'success'); break;
      case 'C': state.arm.gripperClosed = true; logSerial('ARM', 'TX: C -> ACK: GRIPPER_CLOSE', 'success'); break;
      case 'S': logSerial('ARM', 'TX: S -> ACK: ALL_JOINTS_RELEASED', 'warning'); break;
    }
    updateTelemetryUI();
  }

  // --- CONVEYOR CONTROLS & PARCEL SPAWNING ---
  document.getElementById('btnSpawnRed').addEventListener('click', () => spawnParcel('RED'));
  document.getElementById('btnSpawnGreen').addEventListener('click', () => spawnParcel('GREEN'));
  document.getElementById('btnSpawnBlue').addEventListener('click', () => spawnParcel('BLUE'));
  document.getElementById('btnSpawnRandom').addEventListener('click', () => {
    const colors = ['RED', 'GREEN', 'BLUE'];
    spawnParcel(colors[Math.floor(Math.random() * colors.length)]);
  });

  document.getElementById('btnConvResume').addEventListener('click', () => {
    state.sortConv.isRunning = true;
    logSerial('SORT_CONV', 'TX: R -> ACK: BELT_RESUMED', 'success');
    updateTelemetryUI();
  });

  document.getElementById('btnConvPause').addEventListener('click', () => {
    state.sortConv.isRunning = false;
    logSerial('SORT_CONV', 'TX: S -> ACK: BELT_PAUSED', 'warning');
    updateTelemetryUI();
  });

  document.getElementById('btnConvCal').addEventListener('click', () => {
    logSerial('SORT_CONV', 'TX: C -> ACK: OPTICAL_CALIBRATION_CYCLE (TCS3200)', 'info');
    logSerial('SORT_CONV', 'R_REF: 42us | G_REF: 56us | B_REF: 64us -> CALIBRATED', 'success');
  });

  document.getElementById('btnPulseConv1').addEventListener('click', () => trigger3Conv(1));
  document.getElementById('btnPulseConv2').addEventListener('click', () => trigger3Conv(2));
  document.getElementById('btnPulseConv3').addEventListener('click', () => trigger3Conv(3));

  function trigger3Conv(stage) {
    if (stage === 1) { state.transferConv.b1Running = true; state.transferConv.t1 = Date.now(); }
    if (stage === 2) { state.transferConv.b2Running = true; state.transferConv.t2 = Date.now(); }
    if (stage === 3) { state.transferConv.b3Running = true; state.transferConv.t3 = Date.now(); }
    logSerial('3_CONV', `EVT: IR_SENSOR_${stage}_TRIGGERED -> Motor ${stage} RUN (5.0s)`, 'success');
    updateTelemetryUI();
  }

  function spawnParcel(color) {
    state.sortConv.parcels.push({
      x: 40,
      y: 95,
      color: color,
      state: 'cruising',
      timer: 0
    });
    logSerial('SORT_CONV', `Infeed Gate: Spawned parcel [${color}]`, 'info');
  }

  document.getElementById('btnRunSortCycle').addEventListener('click', () => {
    spawnParcel('RED');
    setTimeout(() => spawnParcel('GREEN'), 2500);
    setTimeout(() => spawnParcel('BLUE'), 5000);
  });

  // --- TELEMETRY UI UPDATER ---
  function updateTelemetryUI() {
    if (txtBaseState) txtBaseState.textContent = `${state.base.lastCmd} (Spd: ${state.base.speed})`;
    if (txtArmState) txtArmState.textContent = `${state.arm.lastCmd} (Grip: ${state.arm.gripperClosed ? 'CLOSED' : 'OPEN'})`;
    if (txtSortState) txtSortState.textContent = `${state.sortConv.isRunning ? 'CRUISING' : 'HALTED'} (IR: ${state.sortConv.irTriggered ? 'TRIPPED' : 'CLEAR'})`;

    if (lblIrStatus) {
      lblIrStatus.textContent = state.sortConv.irTriggered ? 'OBJECT PRESENT' : 'CLEAR';
      lblIrStatus.style.color = state.sortConv.irTriggered ? 'var(--color-green)' : 'var(--color-cyan)';
    }
    if (lblColorStatus) {
      lblColorStatus.textContent = state.sortConv.activeColor;
      lblColorStatus.style.color = state.sortConv.activeColor === 'RED' ? '#ff3366'
        : (state.sortConv.activeColor === 'GREEN' ? '#00e676'
        : (state.sortConv.activeColor === 'BLUE' ? '#00e5ff' : 'var(--text-secondary)'));
    }
    if (lblServoAngle) {
      lblServoAngle.textContent = `${state.sortConv.diverterAngle}° (${_chuteName(state.sortConv.diverterAngle)})`;
    }

    if (badgeStage1) badgeStage1.classList.toggle('active', state.transferConv.b1Running);
    if (badgeStage2) badgeStage2.classList.toggle('active', state.transferConv.b2Running);
    if (badgeStage3) badgeStage3.classList.toggle('active', state.transferConv.b3Running);
  }

  function _chuteName(angle) {
    if (angle === 45) return 'Red Chute';
    if (angle === 90) return 'Green Chute';
    if (angle === 135) return 'Blue Chute';
    return 'Neutral Bypass';
  }

  // --- MAIN SIMULATION LOOP (60 FPS) ---
  let lastTime = performance.now();

  function simLoop(time) {
    const dt = (time - lastTime) / 1000;
    lastTime = time;

    // 1. Update 3-Stage Transfer Timers (5.0s run)
    const now = Date.now();
    if (state.transferConv.b1Running && (now - state.transferConv.t1 > 5000)) {
      state.transferConv.b1Running = false;
      logSerial('3_CONV', 'Stage 1 transit complete -> Motor 1 RELEASE', 'info');
      updateTelemetryUI();
    }
    if (state.transferConv.b2Running && (now - state.transferConv.t2 > 5000)) {
      state.transferConv.b2Running = false;
      logSerial('3_CONV', 'Stage 2 transit complete -> Motor 2 RELEASE', 'info');
      updateTelemetryUI();
    }
    if (state.transferConv.b3Running && (now - state.transferConv.t3 > 5000)) {
      state.transferConv.b3Running = false;
      logSerial('3_CONV', 'Stage 3 transit complete -> Motor 3 RELEASE', 'info');
      updateTelemetryUI();
    }

    // 2. Update Mobile Base Physics
    if (!state.isEStopped) {
      state.base.x += state.base.vx;
      state.base.y += state.base.vy;
      // Arena bounds
      if (state.base.x < 30) state.base.x = 30;
      if (state.base.x > 320) state.base.x = 320;
      if (state.base.y < 310) state.base.y = 310;
      if (state.base.y > 440) state.base.y = 440;
    }

    // 3. Update Colour Sorting Conveyor Parcels
    let irTripped = false;
    for (let i = 0; i < state.sortConv.parcels.length; i++) {
      const p = state.sortConv.parcels[i];
      if (state.sortConv.isRunning && p.state === 'cruising') {
        p.x += state.sortConv.beltSpeed;

        // IR Gate Sensor at x = 300
        if (p.x >= 290 && p.x <= 315) {
          irTripped = true;
          p.state = 'staging';
          p.timer = 0;
          state.sortConv.activeColor = p.color;
          logSerial('SORT_CONV', `EVT: IR_OBJECT_DETECTED at Optical Gate`, 'warning');
          logSerial('SORT_CONV', `EVT: TCS3200 Sampling -> Detected ${p.color}`, 'success');

          // Set diverter servo
          if (p.color === 'RED') state.sortConv.diverterAngle = 45;
          else if (p.color === 'GREEN') state.sortConv.diverterAngle = 90;
          else if (p.color === 'BLUE') state.sortConv.diverterAngle = 135;
          else state.sortConv.diverterAngle = 0;

          updateTelemetryUI();
        }
      } else if (p.state === 'staging') {
        irTripped = true;
        p.timer += dt;
        if (p.timer > 0.8) {
          p.state = 'diverting';
        }
      } else if (p.state === 'diverting') {
        p.x += state.sortConv.beltSpeed * 1.5;
        // Divert trajectory into assigned bin
        if (p.color === 'RED' && p.x > 370) p.y -= 1.2;
        if (p.color === 'BLUE' && p.x > 370) p.y += 1.2;

        if (p.x > 500) {
          p.state = 'binned';
          logSerial('SORT_CONV', `EVT: Parcel [${p.color}] diverted into Bin (${state.sortConv.diverterAngle}°)`, 'success');
          state.sortConv.diverterAngle = 0; // return to neutral
          state.sortConv.activeColor = 'NONE';
          updateTelemetryUI();
        }
      }
    }
    state.sortConv.irTriggered = irTripped;

    // Filter out binned parcels after leaving screen
    state.sortConv.parcels = state.sortConv.parcels.filter(p => p.x < 560);

    // 4. Render All Visual Subsystems on Canvas
    renderScene();

    // 5. Render Camera Viewfinder
    renderCamViewfinder();

    requestAnimationFrame(simLoop);
  }

  // --- RENDER SCENE ---
  function renderScene() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Background Grid
    ctx.strokeStyle = '#121a28';
    ctx.lineWidth = 1;
    for (let x = 0; x < canvas.width; x += 40) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke();
    }
    for (let y = 0; y < canvas.height; y += 40) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke();
    }

    // --- SECTION A: COLOUR-SORTING CONVEYOR BELT ---
    drawSortingConveyor();

    // --- SECTION B: 3-STAGE TRANSFER CONVEYORS ---
    draw3StageConveyors();

    // --- SECTION C: MOBILE ROBOTIC BASE ---
    drawRoboticBase();

    // --- SECTION D: ARTICULATED ROBOTIC ARM ---
    drawRoboticArm();
  }

  function drawSortingConveyor() {
    // Label
    ctx.fillStyle = '#00e5ff';
    ctx.font = 'bold 12px Inter';
    ctx.fillText('SUBSYSTEM 3: OPTICAL COLOUR-SORTING CONVEYOR', 30, 45);

    // Belt Bed
    ctx.fillStyle = '#1a2436';
    ctx.fillRect(30, 80, 360, 40);
    ctx.strokeStyle = '#334766';
    ctx.lineWidth = 2;
    ctx.strokeRect(30, 80, 360, 40);

    // Rollers
    ctx.fillStyle = '#0d131d';
    for (let rx = 40; rx <= 380; rx += 30) {
      ctx.beginPath();
      ctx.arc(rx, 100, 6, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }

    // IR Sensor Post & Beam at x = 300
    ctx.fillStyle = '#ffd600';
    ctx.fillRect(296, 60, 8, 20); // Top sensor head
    ctx.fillRect(296, 120, 8, 20); // Bottom emitter
    if (state.sortConv.irTriggered) {
      ctx.strokeStyle = 'rgba(255, 23, 68, 0.8)'; // Red beam blocked
    } else {
      ctx.strokeStyle = 'rgba(255, 214, 0, 0.5)'; // Yellow active beam
    }
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.moveTo(300, 80); ctx.lineTo(300, 120);
    ctx.stroke();
    ctx.setLineDash([]);

    // TCS3200 Optical Sensing Head at x = 330
    ctx.fillStyle = '#9c27b0';
    ctx.fillRect(322, 50, 16, 24);
    ctx.fillStyle = '#fff';
    ctx.font = '8px monospace';
    ctx.fillText('TCS', 324, 66);
    // Optical light cone
    ctx.fillStyle = 'rgba(0, 229, 255, 0.12)';
    ctx.beginPath();
    ctx.moveTo(330, 74);
    ctx.lineTo(315, 110);
    ctx.lineTo(345, 110);
    ctx.closePath();
    ctx.fill();

    // MG946R Diverter Servo at x = 400
    const servoX = 390;
    const servoY = 100;
    ctx.fillStyle = '#0288d1';
    ctx.beginPath();
    ctx.arc(servoX, servoY, 12, 0, Math.PI * 2);
    ctx.fill();

    // Diverter arm
    const rad = (state.sortConv.diverterAngle * Math.PI) / 180;
    const armLen = 38;
    const armEndX = servoX + Math.cos(rad) * armLen;
    const armEndY = servoY + Math.sin(rad) * armLen;
    ctx.strokeStyle = '#00e5ff';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(servoX, servoY);
    ctx.lineTo(armEndX, armEndY);
    ctx.stroke();

    // Sorting Collection Bins
    drawBin(460, 35, '#ff3366', 'RED BIN (45°)');
    drawBin(460, 85, '#00e676', 'GREEN BIN (90°)');
    drawBin(460, 135, '#00e5ff', 'BLUE BIN (135°)');

    // Draw Active Parcels
    state.sortConv.parcels.forEach(p => {
      ctx.fillStyle = p.color === 'RED' ? '#ff3366' : (p.color === 'GREEN' ? '#00e676' : '#00e5ff');
      ctx.fillRect(p.x - 12, p.y - 12, 24, 24);
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 1.5;
      ctx.strokeRect(p.x - 12, p.y - 12, 24, 24);
    });
  }

  function drawBin(x, y, color, label) {
    ctx.fillStyle = 'rgba(18, 24, 36, 0.9)';
    ctx.fillRect(x, y, 90, 32);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.strokeRect(x, y, 90, 32);
    ctx.fillStyle = color;
    ctx.font = 'bold 10px Inter';
    ctx.fillText(label, x + 6, y + 20);
  }

  function draw3StageConveyors() {
    ctx.fillStyle = '#00e676';
    ctx.font = 'bold 12px Inter';
    ctx.fillText('SUBSYSTEM 4: 3-STAGE TRANSFER ARRANGEMENT', 30, 195);

    drawTransferStage(30, 210, 120, 'Stage 1 (Infeed)', state.transferConv.b1Running);
    drawTransferStage(160, 210, 120, 'Stage 2 (Mid-Transfer)', state.transferConv.b2Running);
    drawTransferStage(290, 210, 120, 'Stage 3 (Outfeed)', state.transferConv.b3Running);
  }

  function drawTransferStage(x, y, w, title, isRunning) {
    ctx.fillStyle = isRunning ? '#182f25' : '#141c26';
    ctx.fillRect(x, y, w, 28);
    ctx.strokeStyle = isRunning ? '#00e676' : '#2b394f';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(x, y, w, 28);

    ctx.fillStyle = isRunning ? '#00e676' : '#94a3b8';
    ctx.font = '10px Inter';
    ctx.fillText(title, x + 8, y + 18);

    // Status beacon
    ctx.fillStyle = isRunning ? '#00e676' : '#475569';
    ctx.beginPath();
    ctx.arc(x + w - 12, y + 14, 5, 0, Math.PI * 2);
    ctx.fill();
  }

  function drawRoboticBase() {
    ctx.fillStyle = '#ffd600';
    ctx.font = 'bold 12px Inter';
    ctx.fillText('SUBSYSTEM 1: PORTABLE ROBOTIC BASE (4WD)', 30, 285);

    const bx = state.base.x;
    const by = state.base.y;

    // Chassis
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(bx - 30, by - 20, 60, 40);
    ctx.strokeStyle = state.base.isBraking ? '#ff1744' : '#00e5ff';
    ctx.lineWidth = 2;
    ctx.strokeRect(bx - 30, by - 20, 60, 40);

    // 4 Wheels
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(bx - 36, by - 26, 16, 10); // FL
    ctx.fillRect(bx + 20, by - 26, 16, 10); // FR
    ctx.fillRect(bx - 36, by + 16, 16, 10); // BL
    ctx.fillRect(bx + 20, by + 16, 16, 10); // BR

    // Direction arrow
    if (state.base.lastCmd !== 'S') {
      ctx.strokeStyle = '#00e5ff';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(bx, by);
      ctx.lineTo(bx + state.base.vx * 8, by + state.base.vy * 8);
      ctx.stroke();
    }

    // Brake indicator
    if (state.base.isBraking) {
      ctx.fillStyle = '#ff1744';
      ctx.font = 'bold 10px monospace';
      ctx.fillText('BRAKING', bx - 22, by + 4);
    } else {
      ctx.fillStyle = '#94a3b8';
      ctx.font = '9px monospace';
      ctx.fillText('BASE #1', bx - 20, by + 4);
    }
  }

  function drawRoboticArm() {
    ctx.fillStyle = '#b388ff';
    ctx.font = 'bold 12px Inter';
    ctx.fillText('SUBSYSTEM 2: 4-DOF ROBOTIC ARM', 580, 240);

    const baseArmX = 700;
    const baseArmY = 420;

    // Turret Base
    ctx.fillStyle = '#1f293d';
    ctx.beginPath();
    ctx.arc(baseArmX, baseArmY, 32, Math.PI, 0, false);
    ctx.fill();
    ctx.strokeStyle = '#b388ff';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Arm Kinematics
    const sRad = (state.arm.shoulderAngle * Math.PI) / 180;
    const eRad = (state.arm.elbowAngle * Math.PI) / 180;

    const shoulderLen = 70;
    const elbowLen = 60;

    const j1X = baseArmX;
    const j1Y = baseArmY - 12;

    const j2X = j1X - Math.cos(sRad) * shoulderLen;
    const j2Y = j1Y - Math.sin(sRad) * shoulderLen;

    const j3X = j2X + Math.cos(eRad) * elbowLen;
    const j3Y = j2Y - Math.sin(eRad) * elbowLen;

    // Link 1 (Shoulder)
    ctx.strokeStyle = '#818cf8';
    ctx.lineWidth = 10;
    ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(j1X, j1Y); ctx.lineTo(j2X, j2Y); ctx.stroke();

    // Joint 2 circle
    ctx.fillStyle = '#312e81';
    ctx.beginPath(); ctx.arc(j2X, j2Y, 7, 0, Math.PI * 2); ctx.fill();

    // Link 2 (Elbow/Forearm)
    ctx.strokeStyle = '#c084fc';
    ctx.lineWidth = 7;
    ctx.beginPath(); ctx.moveTo(j2X, j2Y); ctx.lineTo(j3X, j3Y); ctx.stroke();

    // Gripper Claws
    const clawSpan = state.arm.gripperClosed ? 5 : 14;
    ctx.strokeStyle = '#00e5ff';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(j3X - 8, j3Y - clawSpan);
    ctx.lineTo(j3X + 8, j3Y);
    ctx.lineTo(j3X - 8, j3Y + clawSpan);
    ctx.stroke();
  }

  function renderCamViewfinder() {
    if (!camCtx) return;
    state.cam.frameCounter++;

    camCtx.fillStyle = '#060a12';
    camCtx.fillRect(0, 0, camCanvas.width, camCanvas.height);

    // Crosshairs
    camCtx.strokeStyle = 'rgba(0, 229, 255, 0.4)';
    camCtx.lineWidth = 1;
    camCtx.beginPath();
    camCtx.moveTo(camCanvas.width / 2, 20); camCtx.lineTo(camCanvas.width / 2, camCanvas.height - 20);
    camCtx.moveTo(20, camCanvas.height / 2); camCtx.lineTo(camCanvas.width - 20, camCanvas.height / 2);
    camCtx.stroke();

    // Conveyor View Target
    camCtx.fillStyle = '#1e293b';
    camCtx.fillRect(60, 80, 200, 80);

    // Inspection Box
    if (state.sortConv.activeColor !== 'NONE') {
      const col = state.sortConv.activeColor === 'RED' ? '#ff3366'
        : (state.sortConv.activeColor === 'GREEN' ? '#00e676' : '#00e5ff');
      camCtx.fillStyle = col;
      camCtx.fillRect(140, 100, 40, 40);

      // Detection Bounding Box
      camCtx.strokeStyle = '#00e676';
      camCtx.lineWidth = 2;
      camCtx.strokeRect(135, 95, 50, 50);
      camCtx.fillStyle = '#00e676';
      camCtx.font = '10px monospace';
      camCtx.fillText(`CONF: 98% [${state.sortConv.activeColor}]`, 120, 90);
    }

    // Scanlines
    camCtx.fillStyle = 'rgba(255, 255, 255, 0.03)';
    for (let y = 0; y < camCanvas.height; y += 4) {
      camCtx.fillRect(0, y, camCanvas.width, 1);
    }
  }

  // --- START SIMULATION LOOP ---
  requestAnimationFrame(simLoop);

  // Initialize UI status
  updateTelemetryUI();
})();
